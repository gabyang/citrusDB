#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS process_new_order_proc(INT, INT, INT, INT, INT[], INT[], INT[]);"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE process_new_order_proc(
    IN W_ID INT,
    IN D_ID INT,
    IN C_ID INT,
    IN NUM_ITEMS INT,
    IN ITEM_NUMBER INT[],
    IN SUPPLIER_WAREHOUSE INT[],
    IN QUANTITY INT[]
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    N INT;                      -- Next available order number (D_NEXT_O_ID)
    TOTAL_AMOUNT NUMERIC := 0;   -- Total amount of the order
    D_TAX NUMERIC;               -- Tax rate for the district
    W_TAX NUMERIC;               -- Tax rate for the warehouse
    C_DISCOUNT NUMERIC;          -- Discount for the customer
    ADJUSTED_QUANTITY INT;       -- Adjusted stock quantity
    S_QUANTITY INT;              -- Stock quantity of an item
    ITEM_AMOUNT NUMERIC;         -- Amount for each item
    O_ALL_LOCAL INT := 1;        -- Set to 0 if any item is from a remote warehouse
    I_PRICE NUMERIC;             -- Price of the item
    S_YTD NUMERIC;               -- Year-to-date sales for the stock item
    S_ORDER_CNT INT;             -- Order count for the stock item
    S_REMOTE_CNT INT;            -- Remote order count
    i INT;                       -- Loop counter
BEGIN
    -- 1. Retrieve next order ID (D_NEXT_O_ID) for the district (W_ID, D_ID)
    SELECT D_NEXT_O_ID, D_TAX INTO N, D_TAX
    FROM district
    WHERE D_W_ID = W_ID AND D_ID = D_ID
    FOR UPDATE;

    -- 2. Increment D_NEXT_O_ID by 1
    UPDATE district
    SET D_NEXT_O_ID = D_NEXT_O_ID + 1
    WHERE D_W_ID = W_ID AND D_ID = D_ID;

    -- 3. Insert new order into the orders table
    INSERT INTO orders (O_ID, O_D_ID, O_W_ID, O_C_ID, O_ENTRY_D, O_CARRIER_ID, O_OL_CNT, O_ALL_LOCAL)
    VALUES (N, D_ID, W_ID, C_ID, CURRENT_TIMESTAMP, NULL, NUM_ITEMS, O_ALL_LOCAL);

    -- 4. Retrieve warehouse tax rate and customer discount
    SELECT W_TAX INTO W_TAX
    FROM warehouse
    WHERE W_ID = W_ID;

    SELECT C_DISCOUNT INTO C_DISCOUNT
    FROM customer
    WHERE C_W_ID = W_ID AND C_D_ID = D_ID AND C_ID = C_ID;

    -- 5. Process each item in the order
    FOR i IN 1..NUM_ITEMS LOOP
        -- 5a. Retrieve stock quantity for the item and supplier warehouse
        SELECT S_QUANTITY, I_PRICE, S_YTD, S_ORDER_CNT, S_REMOTE_CNT
        INTO S_QUANTITY, I_PRICE, S_YTD, S_ORDER_CNT, S_REMOTE_CNT
        FROM stock, item
        WHERE S_W_ID = SUPPLIER_WAREHOUSE[i]
          AND S_I_ID = ITEM_NUMBER[i]
          AND I_ID = ITEM_NUMBER[i];

        -- 5b. Adjust the stock quantity
        ADJUSTED_QUANTITY := S_QUANTITY - QUANTITY[i];
        IF ADJUSTED_QUANTITY < 10 THEN
            ADJUSTED_QUANTITY := ADJUSTED_QUANTITY + 100;
        END IF;

        -- 5c. Update the stock information
        UPDATE stock
        SET S_QUANTITY = ADJUSTED_QUANTITY,
            S_YTD = S_YTD + QUANTITY[i],
            S_ORDER_CNT = S_ORDER_CNT + 1,
            S_REMOTE_CNT = CASE WHEN SUPPLIER_WAREHOUSE[i] != W_ID THEN S_REMOTE_CNT + 1 ELSE S_REMOTE_CNT END
        WHERE S_W_ID = SUPPLIER_WAREHOUSE[i]
          AND S_I_ID = ITEM_NUMBER[i];

        -- 5d. Calculate the amount for the item
        ITEM_AMOUNT := QUANTITY[i] * I_PRICE;

        -- 5e. Add to the total order amount
        TOTAL_AMOUNT := TOTAL_AMOUNT + ITEM_AMOUNT;

        -- 5f. Insert the order line
        INSERT INTO order_line (OL_O_ID, OL_D_ID, OL_W_ID, OL_NUMBER, OL_I_ID, OL_SUPPLY_W_ID, OL_QUANTITY, OL_AMOUNT, OL_DELIVERY_D, OL_DIST_INFO)
        VALUES (N, D_ID, W_ID, i, ITEM_NUMBER[i], SUPPLIER_WAREHOUSE[i], QUANTITY[i], ITEM_AMOUNT, NULL, 
                (SELECT CASE D_ID 
            WHEN 1 THEN S_DIST_01 
            WHEN 2 THEN S_DIST_02 
            WHEN 3 THEN S_DIST_03 
            WHEN 4 THEN S_DIST_04 
            WHEN 5 THEN S_DIST_05 
            WHEN 6 THEN S_DIST_06 
            WHEN 7 THEN S_DIST_07 
            WHEN 8 THEN S_DIST_08 
            WHEN 9 THEN S_DIST_09 
            WHEN 10 THEN S_DIST_10 
       END
FROM stock 
WHERE S_W_ID = SUPPLIER_WAREHOUSE[i] 
  AND S_I_ID = ITEM_NUMBER[i]
));

        -- 5g. Check if any item is from a remote warehouse
        IF SUPPLIER_WAREHOUSE[i] != W_ID THEN
            O_ALL_LOCAL := 0;
        END IF;
    END LOOP;

    -- 6. Finalize the total amount with taxes and discounts
    TOTAL_AMOUNT := TOTAL_AMOUNT * (1 + D_TAX + W_TAX) * (1 - C_DISCOUNT);

    -- 7. Update the order with the final TOTAL_AMOUNT and O_ALL_LOCAL
    UPDATE orders
    SET O_ALL_LOCAL = O_ALL_LOCAL
    WHERE O_ID = N AND O_D_ID = D_ID AND O_W_ID = W_ID;

    -- The procedure ends here
END;
\$\$;
EOF
)

# Execute the SQL commands via psql
DB_NAME='postgres'
USER_NAME='postgres'
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$DROP_PROCEDURE_SQL"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$CREATE_PROCEDURE_SQL"