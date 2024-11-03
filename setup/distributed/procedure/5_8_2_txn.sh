#!/bin/bash

# SQL to drop the existing function if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS find_related_customers_no_join(INT, INT, INT);"

# SQL to create the new function
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE find_related_customers_no_join(
    inputC_W_ID INT, 
    inputC_D_ID INT, 
    inputC_ID INT
)
LANGUAGE plpgsql
AS
\$\$
DECLARE
    state_x TEXT;
    last_order_x_id INT;
    items_x TEXT[] := '{}';  -- Array to hold items for customer X
    related_customers TEXT := '';  -- To store related customer IDs
    custRecord RECORD;

    current_customer_id INT;
    current_last_order_id INT;
    items_y TEXT[] := '{}';  -- Array to hold items for the current customer
    common_items_count INT;
    item TEXT;
BEGIN
    RAISE NOTICE 'Customer Identifier: (%, %, %)', inputC_W_ID, inputC_D_ID, inputC_ID;

    -- Step 1: Get the state of the given customer
    SELECT C_STATE INTO state_x 
    FROM "customer_2-8"     
    WHERE C_W_ID = inputC_W_ID
      AND C_D_ID = inputC_D_ID
      AND C_ID = inputC_ID;

    RAISE NOTICE 'INPUT CUSTOMER STATE: %', state_x;

    -- Step 2: Get the last order ID for the given customer
    SELECT O_ID INTO last_order_x_id
    FROM "order"
    WHERE O_W_ID = inputC_W_ID
      AND O_D_ID = inputC_D_ID
      AND O_C_ID = inputC_ID
      ORDER BY O_ENTRY_D DESC
    LIMIT 1;
    RAISE NOTICE 'last_order_x_id: %', last_order_x_id;

    -- Step 3: Retrieve items for the last order of the given customer
    FOR item IN
        SELECT OL_I_ID
        FROM "order-line"
        WHERE OL_O_ID = last_order_x_id
            AND OL_W_ID = inputC_W_ID
            AND OL_D_ID = inputC_D_ID
    LOOP
        items_x := array_append(items_x, item);
        RAISE NOTICE 'item %', item;
    END LOOP;
    
    -- Step 4: Loop over other customers in the same state
    FOR custRecord IN
        SELECT C_ID AS customerID, C_W_ID AS warehouseID, C_D_ID AS districtID
        FROM "customer_2-8"
        WHERE C_STATE = state_x
          AND (C_W_ID != inputC_W_ID OR C_D_ID != inputC_D_ID OR C_ID != inputC_ID)  -- Exclude the original customer
    LOOP
        IF custRecord.customerID = 316 THEN
            RAISE NOTICE 'Checking customer: %', custRecord.customerID;
        END IF;
        -- Step 5: Get the last order ID for the current customer
        SELECT O_ID INTO current_last_order_id
        FROM "order"
        WHERE O_W_ID = custRecord.warehouseID
          AND O_D_ID = custRecord.districtID
          AND O_C_ID = custRecord.customerID
        ORDER BY O_ENTRY_D DESC
        LIMIT 1;

        IF custRecord.customerID = 316 THEN
            RAISE NOTICE 'current_last_order_id %', current_last_order_id;
        END IF;

        -- Step 6: Retrieve items for the last order of the current customer
        items_y := '{}';  -- Reset the items array
        FOR item IN
            SELECT OL_I_ID
            FROM "order-line"
            WHERE OL_O_ID = current_last_order_id
        LOOP
            items_y := array_append(items_y, item);
            IF custRecord.customerID = 316 THEN
                RAISE NOTICE 'item %', item;
            END IF;
        END LOOP;
        -- Step 7: Count the number of common items
        common_items_count := 0;

        FOR i IN 0..array_length(items_y,1) LOOP
            IF items_x[i] = ANY (items_y) THEN
                common_items_count := common_items_count + 1;
            END IF;
        END LOOP;

        -- Step 8: Check if there are at least two common items
        IF common_items_count >= 2 THEN
            RAISE NOTICE 'Similar Customer ID: %, Warehouse ID: %, District ID: %', custRecord.customerID, custRecord.warehouseID, custRecord.districtID;
        END IF;
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
