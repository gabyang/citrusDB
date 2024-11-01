#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS new_order(INT, INT, INT, INT, INT[], INT[], INT[]);"
# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE new_order(
    IN input_W_ID INT,
    IN input_D_ID INT,
    IN input_C_ID INT,
    IN input_NUM_ITEMS INT,
    IN input_ITEM_NUMBER INT[],
    IN input_SUPPLIER_WAREHOUSE INT[],
    IN input_QUANTITY INT[]
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    N INT;                      -- Next available order number (D_NEXT_O_ID)
    ORDER_ENTRY_DATE TIMESTAMP := NOW();
    TOTAL_AMOUNT NUMERIC := 0;   -- Total amount of the order
    DISTRICT_TAX NUMERIC;               -- Tax rate for the district
    WAREHOUSE_TAX NUMERIC;               -- Tax rate for the warehouse
    CUSTOMER_DISCOUNT NUMERIC;          -- Discount for the customer
    CUSTOMER_LAST TEXT;
    CUSTOMER_CREDIT TEXT;
    ADJUSTED_QTY INT;      -- Adjusted stock quantity
    STOCK_QUANTITY INT;              -- Stock quantity of an item
    ITEM_AMOUNT NUMERIC;         -- Amount for each item
    O_ALL_LOCAL INT := 1;        -- Set to 0 if any item is from a remote warehouse
    ITEM_PRICE NUMERIC;             -- Price of the item
    STOCK_YTD NUMERIC;               -- Year-to-date sales for the stock item
    STOCK_ORDER_CNT INT;             -- Order count for the stock item
    STOCK_REMOTE_CNT INT;            -- Remote order count
    i INT;                       -- Loop counter
    dist_info VARCHAR(24);
    items_loop RECORD;           -- to output items
    item_name TEXT;

    -- Declare arrays to store item details
    item_numbers INT[];
    item_names TEXT[];
    supplier_warehouses INT[];
    quantities INT[];
    ol_amounts NUMERIC[];
    stock_quantities INT[];

BEGIN
    dist_info := 'S_DIST_' || input_D_ID;

    -- RAISE NOTICE 'Item Numbers: %', input_ITEM_NUMBER;
    -- RAISE NOTICE 'SUPPLIER_WAREHOUSE: %', input_SUPPLIER_WAREHOUSE;
    -- RAISE NOTICE 'QUANTITY: %', input_QUANTITY;
    -- RAISE NOTICE 'dist_info: %', dist_info;

    SELECT D_NEXT_O_ID INTO N
    FROM "district_2-5"
    WHERE D_W_ID = input_W_ID AND D_ID = input_D_ID;
    -- RAISE NOTICE 'N %', N;

    UPDATE "district_2-5"
    SET D_NEXT_O_ID = D_NEXT_O_ID + 1
    WHERE D_W_ID = input_W_ID AND D_ID = input_D_ID;

    -- RAISE NOTICE '% % % % % % % %', input_W_ID, input_D_ID, N, input_D_ID, ORDER_ENTRY_DATE, NULL, input_NUM_ITEMS, O_ALL_LOCAL;
    
    INSERT INTO "order" (O_W_ID, O_D_ID, O_ID, O_C_ID, O_ENTRY_D, O_CARRIER_ID, O_OL_CNT, O_ALL_LOCAL) 
    VALUES (input_W_ID, input_D_ID, N, input_C_ID, ORDER_ENTRY_DATE, NULL, input_NUM_ITEMS, O_ALL_LOCAL);

    O_ALL_LOCAL := 1;  -- Assume all items are local initially
    FOR i IN 1..input_NUM_ITEMS LOOP
        IF input_SUPPLIER_WAREHOUSE[i] != input_W_ID THEN
            O_ALL_LOCAL := 0;  -- Set to 0 if any supplier is not from the same warehouse
            EXIT;  -- Exit loop as we only need one non-local supplier to set this to 0
        END IF;

        -- Fetch the item price and stock details
        SELECT I_PRICE, I_NAME INTO ITEM_PRICE, item_name
        FROM item
        WHERE I_ID = input_ITEM_NUMBER[i];

        -- a. Get the stock quantity for the item and supplier warehouse
        SELECT S_ORDER_CNT, S_REMOTE_CNT, S_YTD 
        INTO STOCK_ORDER_CNT, STOCK_REMOTE_CNT, STOCK_YTD
        FROM Stock
        WHERE S_I_ID = input_ITEM_NUMBER[i] AND S_W_ID = input_SUPPLIER_WAREHOUSE[i];

        SELECT S_QUANTITY 
        INTO STOCK_QUANTITY
        FROM "stock_2-5"
        WHERE S_I_ID = input_ITEM_NUMBER[i] AND S_W_ID = input_SUPPLIER_WAREHOUSE[i];

        SELECT I_PRICE 
        INTO ITEM_PRICE
        FROM item
        where I_ID = input_ITEM_NUMBER[i];

        -- b. Calculate the adjusted quantity
        ADJUSTED_QTY := STOCK_QUANTITY - input_QUANTITY[i];

        -- c. Adjust quantity if less than 10
        IF ADJUSTED_QTY < 10 THEN
            ADJUSTED_QTY := ADJUSTED_QTY + 100;
        END IF;

        -- d. Update the stock
        UPDATE "stock"
            SET S_YTD = STOCK_YTD + input_QUANTITY[i],
            S_ORDER_CNT = STOCK_ORDER_CNT + 1,
            S_REMOTE_CNT = STOCK_REMOTE_CNT + CASE WHEN input_SUPPLIER_WAREHOUSE[i] != input_W_ID THEN 1 ELSE 0 END
        WHERE S_I_ID = input_ITEM_NUMBER[i] AND S_W_ID = input_SUPPLIER_WAREHOUSE[i];

        UPDATE "stock_2-5"
            SET S_QUANTITY = ADJUSTED_QTY
        WHERE S_I_ID = input_ITEM_NUMBER[i] AND S_W_ID = input_SUPPLIER_WAREHOUSE[i];

        -- e. Calculate the item amount
        ITEM_AMOUNT := input_QUANTITY[i] * ITEM_PRICE;

        -- f. Update the total amount
        TOTAL_AMOUNT := TOTAL_AMOUNT + ITEM_AMOUNT;

        -- g. Create a new order-line
        INSERT INTO "order-line" (OL_W_ID, OL_D_ID, OL_O_ID, OL_NUMBER, OL_I_ID, OL_SUPPLY_W_ID, OL_QUANTITY, OL_AMOUNT, OL_DELIVERY_D, OL_DIST_INFO)
        VALUES (input_W_ID, input_D_ID, N, i, input_ITEM_NUMBER[i], input_SUPPLIER_WAREHOUSE[i], input_QUANTITY[i], ITEM_AMOUNT, NULL, dist_info);

        INSERT INTO "order-line-item-constraint" (OL_W_ID, OL_D_ID, OL_O_ID, OL_NUMBER, OL_I_ID)
        VALUES (input_W_ID, input_D_ID, N, i, input_ITEM_NUMBER[i]);

        -- Collect item details in arrays
        item_numbers := array_append(item_numbers, input_ITEM_NUMBER[i]);
        item_names := array_append(item_names, item_name);
        supplier_warehouses := array_append(supplier_warehouses, input_SUPPLIER_WAREHOUSE[i]);
        quantities := array_append(quantities, input_QUANTITY[i]);
        ol_amounts := array_append(ol_amounts, ITEM_AMOUNT);
        stock_quantities := array_append(stock_quantities, ADJUSTED_QTY);

    END LOOP;
    SELECT D_TAX INTO DISTRICT_TAX from "district" WHERE D_W_ID = input_W_ID AND D_ID = input_D_ID;

    SELECT W_TAX INTO WAREHOUSE_TAX from "warehouse" WHERE W_ID = input_W_ID;

    SELECT C_CREDIT, C_DISCOUNT 
    INTO CUSTOMER_CREDIT, CUSTOMER_DISCOUNT 
    from "customer" 
    WHERE 
    C_W_ID = input_W_ID 
    AND C_D_ID = input_D_ID 
    AND C_ID = input_C_ID;

    SELECT C_LAST 
    INTO CUSTOMER_LAST 
    from "customer_2-7" 
    WHERE 
    C_W_ID = input_W_ID 
    AND C_D_ID = input_D_ID 
    AND C_ID = input_C_ID;

    TOTAL_AMOUNT = TOTAL_AMOUNT * (1+DISTRICT_TAX + WAREHOUSE_TAX) * (1-CUSTOMER_DISCOUNT);
    
    RAISE NOTICE 'Customer Identifier: % % % % % %', input_W_ID, input_D_ID, input_C_ID, CUSTOMER_LAST, CUSTOMER_CREDIT, CUSTOMER_DISCOUNT;

    RAISE NOTICE 'W_TAX: %, D_TAX: %', WAREHOUSE_TAX, DISTRICT_TAX;
    RAISE NOTICE 'O_ID : %, O_ENTRY_D : %', N, ORDER_ENTRY_DATE;
    RAISE NOTICE 'NUM_ITEMS : %, TOTAL_AMOUNT: %', input_NUM_ITEMS, TOTAL_AMOUNT;

    FOR i IN 1..array_length(item_numbers, 1) LOOP
        RAISE NOTICE 'Item Number: %, Name: %, Supplier Warehouse: %, Quantity: %, Amount: %, Stock Quantity: %',
            item_numbers[i], item_names[i], supplier_warehouses[i], quantities[i], ol_amounts[i], stock_quantities[i];
    END LOOP;

END;
\$\$;
EOF
)

# Execute the SQL commands via psql
DB_NAME='postgres'
USER_NAME='postgres'
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$DROP_PROCEDURE_SQL"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$CREATE_PROCEDURE_SQL"