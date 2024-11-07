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
    next_order_id INT;
    last_order_ids INT[];
    item_data RECORD;
    item_details RECORD;
BEGIN
    -- Step 1: Get the next available order number for the district
    SELECT d_next_o_id INTO next_order_id
    FROM "district_2-5"
    WHERE d_w_id = p_w_id AND d_id = p_d_id;

    -- Step 2: Get the set of last L orders
    SELECT array_agg(o_id) INTO last_order_ids
    FROM "order"
    WHERE o_w_id = p_w_id AND o_d_id = p_d_id
    AND o_id >= next_order_id - p_l AND o_id < next_order_id;

    IF last_order_ids IS NULL THEN
        RAISE NOTICE 'No orders found.';
        RETURN;
    END IF;

    -- Step 3: Get the set of all items contained in the last L orders
    CREATE TEMP TABLE temp_item_data AS
    SELECT ol_i_id, SUM(ol_quantity) AS total_qty, COUNT(DISTINCT ol_o_id) AS num_orders
    FROM "order-line"
    WHERE ol_w_id = p_w_id AND ol_d_id = p_d_id AND ol_o_id = ANY(last_order_ids)
    GROUP BY ol_i_id;

    IF NOT EXISTS (SELECT 1 FROM temp_item_data) THEN
        RAISE NOTICE 'No items found in the last orders.';
        RETURN;
    END IF;

    -- Output district identifier and L
    RAISE NOTICE 'District Identifier: (W_ID: %, D_ID: %)', p_w_id, p_d_id;
    RAISE NOTICE 'Number of last orders examined: %', p_l;

    -- Step 4: Get the top 5 most popular items based on total quantity and number of orders
    -- Sorting by total_qty DESC, num_orders DESC, ol_i_id ASC
    FOR item_data IN
        SELECT ol_i_id, total_qty, num_orders
        FROM temp_item_data
        ORDER BY total_qty DESC, num_orders DESC, ol_i_id ASC
        LIMIT 5
    LOOP
        -- Fetch item details (name and price)
        SELECT i_name, i_price INTO item_details
        FROM item
        WHERE i_id = item_data.ol_i_id;

        -- Output the item details
        RAISE NOTICE 'Item Number: %', item_data.ol_i_id;
        RAISE NOTICE 'Item Name: %', item_details.i_name;
        RAISE NOTICE 'Item Price: %', item_details.i_price;
        RAISE NOTICE 'Total Quantity: %', item_data.total_qty;
        RAISE NOTICE 'Number of Orders: %', item_data.num_orders;
    END LOOP;

    -- Clean up temp table
    DROP TABLE temp_item_data;

END;
\$\$;
EOF
)

# Execute the SQL commands via psql
DB_NAME='postgres'
USER_NAME='postgres'
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$DROP_PROCEDURE_SQL"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "$CREATE_PROCEDURE_SQL"

