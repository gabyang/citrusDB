#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS gettop10customers();"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE gettop10customers()
LANGUAGE plpgsql
AS \$\$
DECLARE
    customer_record RECORD;
    warehouse_name TEXT;
    dist_name TEXT;
BEGIN
    FOR customer_record IN
        SELECT 
            C_FIRST, C_MIDDLE, C_LAST, C_BALANCE, 
            C_W_ID, C_D_ID
        FROM "customer_2-7"
        ORDER BY C_BALANCE DESC 
        LIMIT 10
    LOOP
        -- Fetch the warehouse name for the current customer
        SELECT W_NAME INTO warehouse_name
        FROM warehouse
        WHERE W_ID = customer_record.C_W_ID;

        -- Fetch the district name for the current customer
        SELECT D_NAME INTO dist_name
        FROM district
        WHERE D_ID = customer_record.C_D_ID AND D_W_ID = customer_record.C_W_ID;

        -- Output customer and associated warehouse and district names
        RAISE NOTICE 'Customer: First=%, Middle=%, Last=%, Balance=%',
                     customer_record.C_FIRST, 
                     customer_record.C_MIDDLE, 
                     customer_record.C_LAST, 
                     customer_record.C_BALANCE;
        RAISE NOTICE 'Warehouse: %', warehouse_name;
        RAISE NOTICE 'District: %', dist_name;
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