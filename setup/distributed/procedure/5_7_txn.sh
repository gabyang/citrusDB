#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS gettop10customers();"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE gettop10customers()
LANGUAGE plpgsql
AS \$\$
DECLARE
    r RECORD;
BEGIN
    -- Create temporary tables to hold intermediate data
    CREATE TEMP TABLE temp_customer_data AS
    SELECT
        C_FIRST,
        C_MIDDLE,
        C_LAST,
        C_BALANCE,
        C_W_ID,
        C_D_ID
    FROM
        "customer_2-7";

    CREATE TEMP TABLE temp_warehouse_data AS
    SELECT
        W_ID,
        W_NAME
    FROM
        Warehouse;

    CREATE TEMP TABLE temp_district_data AS
    SELECT
        D_W_ID,
        D_ID,
        D_NAME
    FROM
        District;

    -- Loop through the top 10 customers ranked by outstanding balance
    FOR r IN
        SELECT
            cd.C_FIRST,
            cd.C_MIDDLE,
            cd.C_LAST,
            cd.C_BALANCE,
            wd.W_NAME,
            dd.D_NAME
        FROM
            temp_customer_data cd,
            temp_warehouse_data wd,
            temp_district_data dd
        WHERE
            cd.C_W_ID = wd.W_ID
            AND cd.C_W_ID = dd.D_W_ID
            AND cd.C_D_ID = dd.D_ID
        ORDER BY
            cd.C_BALANCE DESC
        LIMIT 10
    LOOP
        -- Raise notice to display each result
        RAISE NOTICE 'Customer: % % %, Balance: %, Warehouse: %, District: %',
            r.C_FIRST,
            r.C_MIDDLE,
            r.C_LAST,
            r.C_BALANCE,
            r.W_NAME,
            r.D_NAME;
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