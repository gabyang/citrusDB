#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS report_low_stock_items(INT, INT, INT, INT);"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE report_low_stock_items(
    W_ID INT,           -- Warehouse ID
    DIST_ID INT,        -- District ID
    T INT,              -- Stock threshold
    L INT               -- Number of last orders to examine
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    N INT;                           -- Next available order ID
    item_id INT;                     -- Item ID in the OrderLine
    low_stock_count INT := 0;       -- Counter for items with stock below threshold
    stock_quantity INT := 0;              -- Stock quantity for the item
BEGIN
    -- Step 1: Get the next available order ID (D_NEXT_O_ID) for the given district
    SELECT D_NEXT_O_ID INTO N
    FROM "district_2-5"
    WHERE D_ID = DIST_ID AND D_W_ID = W_ID;

    -- Step 2: Examine items from the last L orders (N-L to N-1)
    FOR item_id IN
        SELECT OL_I_ID
        FROM "order-line"
        WHERE OL_W_ID = W_ID
          AND OL_D_ID = DIST_ID
          AND OL_O_ID BETWEEN N - L AND N - 1
    LOOP
        -- Step 3: Check if the item's stock quantity is below the threshold T
        SELECT S_QUANTITY INTO stock_quantity
        FROM "stock_2-5"
        WHERE S_W_ID = W_ID AND S_I_ID = item_id and s_quantity < T;

        -- If stock quantity is below the threshold, increment the counter
        IF stock_quantity < T THEN
            low_stock_count := low_stock_count + 1;
        END IF;
    END LOOP;

    -- Step 4: Output the total number of items with stock below the threshold
    RAISE NOTICE 'Number of items with stock below %: %', T, low_stock_count;
END;
\$\$;
EOF
)

# Execute the SQL commands via psql
INSTALLDIR=$HOME/pgsql
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "$DROP_PROCEDURE_SQL"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "$CREATE_PROCEDURE_SQL"