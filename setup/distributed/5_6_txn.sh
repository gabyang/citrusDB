#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS process_payment(INT, INT, INT, NUMERIC);"

# SQL command to create the procedure
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE find_most_popular_items(
    IN p_w_id INT,
    IN p_d_id INT,
    IN p_l INT
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_next_o_id INT;  -- Variable to store the next order number (D_NEXT_O_ID)
    v_order_id INT;   -- Variable to store each order id in the set of last L orders
    item_row RECORD;  -- Record to store each item's information
BEGIN
    -- Step 1: Fetch the next available order number (D_NEXT_O_ID) for the district
    SELECT d_next_o_id
    INTO v_next_o_id
    FROM district
    WHERE d_w_id = p_w_id AND d_id = p_d_id;

    -- Step 2: Find the total quantity (I.total_qty) and number of orders (I.num_orders)
    -- for each item in the last L orders at the specified warehouse and district
    FOR item_row IN
        SELECT ol.ol_i_id, i.i_name, i.i_price,
               SUM(ol.ol_quantity) AS total_qty,
               COUNT(DISTINCT ol.ol_o_id) AS num_orders
        FROM "order-line" ol
        JOIN item i ON ol.ol_i_id = i.i_id
        WHERE ol.ol_w_id = p_w_id
          AND ol.ol_d_id = p_d_id
          AND ol.ol_o_id >= v_next_o_id - p_l
          AND ol.ol_o_id < v_next_o_id
        GROUP BY ol.ol_i_id, i.i_name, i.i_price
        ORDER BY total_qty DESC, num_orders DESC, ol.ol_i_id ASC
        LIMIT 5  -- Fetch only the top 5 items
    LOOP
        -- Step 3: Output the item information (Item ID, Name, Price, Total Quantity, Number of Orders)
        RAISE NOTICE 'Item ID: %, Name: %, Price: %, Total Quantity: %, Number of Orders: %',
            item_row.ol_i_id, item_row.i_name, item_row.i_price, item_row.total_qty, item_row.num_orders;
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

