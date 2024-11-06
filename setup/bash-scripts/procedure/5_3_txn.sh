#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS delivery_txn(INT, INT);"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE delivery_txn(W_ID INT, CARRIER_ID INT)
LANGUAGE plpgsql
AS \$\$
DECLARE
    DISTRICT_NO INT;
    N INT; -- Order ID
    cust_ID INT; -- Customer ID
    OL_AMOUNT_SUM DECIMAL(12, 2); -- Sum of OL_AMOUNT
    curr_time TIMESTAMP;
    BEFORE_C_BALANCE DECIMAL(12,2);
    AFTER_C_BALANCE DECIMAL(12,2);
BEGIN
    curr_time := CURRENT_TIMESTAMP;
    -- Loop through each district (1 to 10)
    FOR DISTRICT_NO IN 1..10 LOOP
        -- Step a: Find the smallest O_ID (N) for the district where O_CARRIER_ID is NULL
        SELECT O_ID, O_C_ID INTO N, cust_ID
        FROM "order"
        WHERE O_W_ID = W_ID 
          AND O_D_ID = DISTRICT_NO 
          AND O_CARRIER_ID IS NULL
        ORDER BY O_ID ASC
        LIMIT 1;

        -- If no such order exists, skip to the next district
        IF NOT FOUND THEN
            CONTINUE;
        END IF;

        -- Step b: Update the order X by setting O_CARRIER_ID to CARRIER_ID
        UPDATE "order"
        SET O_CARRIER_ID = CARRIER_ID
        WHERE O_W_ID = W_ID 
          AND O_D_ID = DISTRICT_NO
          AND O_ID = N;

        -- Step c: Update the order-lines for order N by setting OL_DELIVERY_D to the current date and time
        UPDATE "order-line"
        SET OL_DELIVERY_D = curr_time
        WHERE OL_W_ID = W_ID
          AND OL_D_ID = DISTRICT_NO
          AND OL_O_ID = N;

        -- Step d: Calculate the sum of OL_AMOUNT for the order lines in order N
        SELECT SUM(OL_AMOUNT) INTO OL_AMOUNT_SUM
        FROM "order-line"
        WHERE OL_W_ID = W_ID
          AND OL_D_ID = DISTRICT_NO
          AND OL_O_ID = N;
        SELECT C_BALANCE into BEFORE_C_BALANCE FROM "customer_2-7" WHERE C_W_ID = W_ID
          AND C_D_ID = DISTRICT_NO
          AND C_ID = cust_ID;

        
        -- Increment the customer's balance by the total OL_AMOUNT (B) and delivery count
        UPDATE customer
        SET C_DELIVERY_CNT = C_DELIVERY_CNT + 1
        WHERE C_W_ID = W_ID
          AND C_D_ID = DISTRICT_NO
          AND C_ID = cust_ID;

        UPDATE "customer_2-7"
        SET C_BALANCE = C_BALANCE + OL_AMOUNT_SUM
        WHERE C_W_ID = W_ID
          AND C_D_ID = DISTRICT_NO
          AND C_ID = cust_ID;

        SELECT C_BALANCE into AFTER_C_BALANCE FROM "customer_2-7" WHERE C_W_ID = W_ID
          AND C_D_ID = DISTRICT_NO
          AND C_ID = cust_ID;

    END LOOP;
END;
\$\$;
EOF
)

# Execute the SQL commands via psql
INSTALLDIR=$HOME/pgsql
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "$DROP_PROCEDURE_SQL"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "$CREATE_PROCEDURE_SQL"