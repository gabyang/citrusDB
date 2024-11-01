#!/bin/bash

# SQL to drop the existing function if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS find_related_customers(INT, INT, INT);"

# SQL to create the new function
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE find_related_customers(
    inputC_W_ID INT, 
    inputC_D_ID INT, 
    inputC_ID INT
)
LANGUAGE plpgsql
AS
\$\$
DECLARE
    lastOrderID INT;
    custRecord RECORD;
    lastOrderID_C INT;
    itemCount INT;
    inputStateID CHAR(2);  -- Declare variable to hold the state of the input customer
BEGIN
    -- Step 1: Get the state of the input customer
    SELECT C_STATE INTO inputStateID
    FROM "customer_2-8"
    WHERE C_W_ID = inputC_W_ID
      AND C_D_ID = inputC_D_ID
      AND C_ID = inputC_ID;

    -- Step 2: Get the last order for the given customer C
    SELECT O_ID INTO lastOrderID
    FROM "order"
    WHERE O_W_ID = inputC_W_ID
      AND O_D_ID = inputC_D_ID
      AND O_C_ID = inputC_ID
    ORDER BY O_ENTRY_D DESC
    LIMIT 1;

    -- Step 3: Find all customers C' in the same state as input customer and loop over them
    FOR custRecord IN
        SELECT C_ID AS customerID, C_W_ID AS warehouseID, C_D_ID AS districtID
        FROM "customer_2-8"
        WHERE C_STATE = inputStateID
          AND (C_W_ID != inputC_W_ID OR C_D_ID != inputC_D_ID OR C_ID != inputC_ID)  -- Exclude the original customer
    LOOP
        -- Step 4: Get the last order for customer C'
        SELECT O_ID INTO lastOrderID_C
        FROM "order"
        WHERE O_W_ID = custRecord.warehouseID
          AND O_D_ID = custRecord.districtID
          AND O_C_ID = custRecord.customerID
        ORDER BY O_ENTRY_D DESC
        LIMIT 1;


        -- Step 5: Check for matching items (at least two distinct matching items)
        SELECT COUNT(*) INTO itemCount
        FROM "order-line" OL1
        JOIN "order-line" OL2 ON OL1.OL_I_ID = OL2.OL_I_ID
        WHERE OL1.OL_W_ID = inputC_W_ID
          AND OL1.OL_D_ID = inputC_D_ID
          AND OL1.OL_O_ID = lastOrderID
          AND OL2.OL_W_ID = custRecord.warehouseID
          AND OL2.OL_D_ID = custRecord.districtID
          AND OL2.OL_O_ID = lastOrderID_C;

        -- Step 6: If two distinct items match, display the similar customer
        IF itemCount >= 2 THEN
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
