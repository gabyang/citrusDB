#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS process_payment(INT, INT, INT, NUMERIC);"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE process_payment(
    IN p_c_w_id INT, 
    IN p_c_d_id INT, 
    IN p_c_id INT, 
    IN p_payment NUMERIC
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    UPDATE warehouse
    SET w_ytd = w_ytd + p_payment
    WHERE w_id = p_c_w_id;

    UPDATE district
    SET d_ytd = d_ytd + p_payment
    WHERE d_w_id = p_c_w_id AND d_id = p_c_d_id;

    UPDATE customer
    SET c_balance = c_balance - p_payment,
        c_ytd_payment = c_ytd_payment + p_payment,
        c_payment_cnt = c_payment_cnt + 1
    WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id;

    RAISE NOTICE 'Customer Identifier: (C_W_ID: %, C_D_ID: %, C_ID: %)', p_c_w_id, p_c_d_id, p_c_id;
    RAISE NOTICE 'Customer Name: %, %, %',
        (SELECT c_first FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT c_middle FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT c_last FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id);
    RAISE NOTICE 'Customer Address: %, %, %, %, %',
        (SELECT C_STREET_1 FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_STREET_2 FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_CITY FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_STATE FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_ZIP FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id);
    RAISE NOTICE 'Customer Info: %, %, %, %, %, %',
        (SELECT C_PHONE FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_SINCE FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_CREDIT FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_CREDIT_LIM FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_DISCOUNT FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id),
        (SELECT C_BALANCE FROM customer WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id);

    -- Output warehouse address
    RAISE NOTICE 'Warehouse Address: %, %, %, %, %',
        (SELECT w_street_1 FROM warehouse WHERE w_id = p_c_w_id),
        (SELECT w_street_2 FROM warehouse WHERE w_id = p_c_w_id),
        (SELECT w_city FROM warehouse WHERE w_id = p_c_w_id),
        (SELECT w_state FROM warehouse WHERE w_id = p_c_w_id),
        (SELECT w_zip FROM warehouse WHERE w_id = p_c_w_id);

    -- Output district address
    RAISE NOTICE 'District Address: %, %, %, %, %',
        (SELECT d_street_1 FROM district WHERE d_w_id = p_c_w_id AND d_id = p_c_d_id),
        (SELECT d_street_2 FROM district WHERE d_w_id = p_c_w_id AND d_id = p_c_d_id),
        (SELECT d_city FROM district WHERE d_w_id = p_c_w_id AND d_id = p_c_d_id),
        (SELECT d_state FROM district WHERE d_w_id = p_c_w_id AND d_id = p_c_d_id),
        (SELECT d_zip FROM district WHERE d_w_id = p_c_w_id AND d_id = p_c_d_id);

    RAISE NOTICE 'Payment Amount: %', p_payment;

END;
\$\$;
EOF
)

# Execute the SQL commands via psql
DB_NAME='postgres'
USER_NAME='postgres'
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$DROP_PROCEDURE_SQL"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$CREATE_PROCEDURE_SQL"
