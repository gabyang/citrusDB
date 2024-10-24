#!/bin/bash

# SQL command to drop the procedure if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS find_most_popular_items(INT, INT, INT);"

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
    next_available_order_number INT;
    v_next_o_id INT;  -- Variable to store the next order number (D_NEXT_O_ID)
    v_order_id INT;   -- Variable to store each order id in the set of last L orders
    item_row RECORD;  -- Record to store each item's information
    line_item RECORD;  -- Record to store each item's information
    itemname TEXT;
    itemprice TEXT;
BEGIN
    -- Step 1: Fetch the next available order number (D_NEXT_O_ID) for the district
    SELECT d_next_o_id INTO next_available_order_number
                FROM "district_2-5"
                WHERE d_w_id = p_w_id AND d_id = p_d_id;
    RAISE NOTICE 'next_available_order_number: %', next_available_order_number;
    RAISE NOTICE 'N%s', next_available_order_number;
    RAISE NOTICE 'L %s', p_l;
    RAISE NOTICE 'N-L %s', next_available_order_number - p_l;
    -- Step 2: Find the total quantity (I.total_qty) and number of orders (I.num_orders)
    -- for each item in the last L orders at the specified warehouse and district
    FOR item_row IN
        SELECT o_id
                FROM "order"
                WHERE o_w_id = p_w_id AND o_d_id = p_d_id
                AND o_id >= next_available_order_number - p_l AND o_id < p_l
    LOOP
        -- Step 3: For each o_id, query the "order-line" table to get the list of items
        FOR line_item IN
            SELECT ol_i_id, SUM(ol_quantity) AS total_qty, COUNT(*) AS num_orders
            FROM "order-line"
            WHERE ol_w_id = p_w_id
              AND ol_d_id = p_d_id
              AND ol_o_id = item_row.o_id
            GROUP BY ol_i_id
        LOOP
            -- Fetch item details from the "item" table for each unique ol_i_id
            SELECT i_name, i_price into itemname, itemprice
            FROM item
            WHERE i_id = line_item.ol_i_id;
            -- Output the item information (Item ID, Name, Price, Total Quantity, Number of Orders)
            RAISE NOTICE 'Item name: %, price: %',
                itemname, itemprice;
        END LOOP;
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

