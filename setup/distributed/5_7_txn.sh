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
    -- Loop through the top 10 customers and raise notice for each result
    FOR r IN
        SELECT
            C.C_FIRST,
            C.C_MIDDLE,
            C.C_LAST,
            C.C_BALANCE,
            W.W_NAME,
            D.D_NAME
        FROM
            Customer C
            JOIN Warehouse W ON C.C_W_ID = W.W_ID
            JOIN District D ON C.C_W_ID = D.D_W_ID AND C.C_D_ID = D.D_ID
        ORDER BY
            C.C_BALANCE DESC
        LIMIT 10
    LOOP
        -- Raise notice to display each row in the results
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