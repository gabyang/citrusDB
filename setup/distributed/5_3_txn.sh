#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS delivery_txn(INT, INT);"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE delivery_txn(
    IN p_w_id INT,
    IN p_carrier_id INT
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    district_no INT;
    next_order_id INT;
    customer_id INT;
    total_amount NUMERIC;
    delivery_time TIMESTAMP;
BEGIN
    delivery_time := CURRENT_TIMESTAMP;

    -- Process steps for district numbers 1 through 10
    FOR district_no IN 1..10 LOOP

        -- Step 1a: Find the smallest order number O_ID for the district with O_CARRIER_ID IS NULL
        SELECT MIN(o_id) INTO next_order_id
        FROM "order"
        WHERE o_w_id = p_w_id AND o_d_id = district_no AND o_carrier_id IS NULL;

        IF next_order_id IS NULL THEN
            -- No valid order is found, continue to the next district
            CONTINUE;
        END IF;

        -- Step 1b: Find the customer who placed the order
        SELECT o_c_id INTO customer_id
        FROM "order"
        WHERE o_w_id = p_w_id AND o_d_id = district_no AND o_id = next_order_id;

        -- Update the order by setting O_CARRIER_ID
        UPDATE "order"
        SET o_carrier_id = p_carrier_id
        WHERE o_w_id = p_w_id AND o_d_id = district_no AND o_id = next_order_id;

        -- Step 1c: Update all the order lines for this order by setting OL_DELIVERY_D to the current date and time
        UPDATE "order-line"
        SET ol_delivery_d = delivery_time
        WHERE ol_w_id = p_w_id AND ol_d_id = district_no AND ol_o_id = next_order_id;

        -- Step 1d: Calculate the total amount from all order lines for this order
        SELECT SUM(ol_amount) INTO total_amount
        FROM "order-line"
        WHERE ol_w_id = p_w_id AND ol_d_id = district_no AND ol_o_id = next_order_id;

        -- Update the customer balance and increment the delivery count
        UPDATE "customer_2-7"
        SET c_balance = c_balance + total_amount
        WHERE c_w_id = p_w_id AND c_d_id = district_no AND c_id = customer_id;

        UPDATE customer
        SET c_delivery_cnt = c_delivery_cnt + 1
        WHERE c_w_id = p_w_id AND c_d_id = district_no AND c_id = customer_id;


    END LOOP;
END;
\$\$;
EOF
)

# Execute the SQL commands via psql
DB_NAME='gabriel.yang'
USER_NAME='gabriel.yang'
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$DROP_PROCEDURE_SQL"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$CREATE_PROCEDURE_SQL"