#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS query_last_order_status(INT, INT, INT);"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
 CREATE OR REPLACE PROCEDURE query_last_order_status(
    IN p_c_w_id INT,
    IN p_c_d_id INT,
    IN p_c_id INT
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_o_id INT;                -- Variable to store the last order ID
    v_o_entry_d TIMESTAMP;     -- Variable to store the entry date of the last order
    v_o_carrier_id INT;        -- Variable to store the carrier ID of the last order
    v_c_first TEXT;            -- Variable to store the customer's first name
    v_c_middle TEXT;           -- Variable to store the customer's middle name
    v_c_last TEXT;             -- Variable to store the customer's last name
    v_c_balance NUMERIC;       -- Variable to store the customer's balance
    item_row RECORD;           -- Declare a record variable for the order line items
BEGIN
    -- Fetch customer information: Name and balance
    SELECT c_first, c_middle, c_last, c_balance
    INTO v_c_first, v_c_middle, v_c_last, v_c_balance
    FROM "customer_2-7"
    WHERE c_w_id = p_c_w_id AND c_d_id = p_c_d_id AND c_id = p_c_id;

    -- Output customer information
    --RAISE NOTICE 'Customer Name: % % %', v_c_first, v_c_middle, v_c_last;
    --RAISE NOTICE 'Customer Balance: %', v_c_balance;

    -- Fetch the customer's last order
    SELECT o_id, o_entry_d, o_carrier_id
    INTO v_o_id, v_o_entry_d, v_o_carrier_id
    FROM "order"
    WHERE o_w_id = p_c_w_id AND o_d_id = p_c_d_id AND o_c_id = p_c_id
    ORDER BY o_entry_d DESC
    LIMIT 1;

    -- Output last order information
    --RAISE NOTICE 'Last Order ID: %', v_o_id;
    --RAISE NOTICE 'Order Entry Date: %', v_o_entry_d;
    --RAISE NOTICE 'Order Carrier ID: %', v_o_carrier_id;

    -- Fetch and output each item in the customer's last order
    FOR item_row IN
        SELECT ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_delivery_d
        FROM "order-line"
        WHERE ol_w_id = p_c_w_id AND ol_d_id = p_c_d_id AND ol_o_id = v_o_id
    LOOP
        --RAISE NOTICE 'Item Number: %, Supply Warehouse: %, Quantity: %, Total Price: %, Delivery Date: %',
        --    item_row.ol_i_id, item_row.ol_supply_w_id, item_row.ol_quantity, item_row.ol_amount, item_row.ol_delivery_d;
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