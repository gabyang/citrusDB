#!/bin/bash

# SQL to drop the existing function if it exists
DROP_PROCEDURE_SQL="DROP PROCEDURE IF EXISTS find_related_customers_no_join(INT, INT, INT);"

# SQL to create the new function
CREATE_PROCEDURE_SQL=$(cat <<EOF
CREATE OR REPLACE PROCEDURE find_related_customers_no_join(
    IN input_c_w_id INT,           -- Warehouse ID of the given customer
    IN input_c_d_id INT,           -- District ID of the given customer
    IN input_c_id INT              -- Customer ID of the given customer
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    customer_state TEXT;
    customer_last_order_id INT;
    customer_item_ids INT[];
    related_customers RECORD;
    output TEXT := '';  -- To accumulate output
BEGIN
    -- Step 1: Get the state of the given customer
    SELECT c_state 
    INTO customer_state 
    FROM "customer_2-8" 
    WHERE c_w_id = input_c_w_id AND c_d_id = input_c_d_id AND c_id = input_c_id;

    -- Step 2: Get the last order ID for the given customer
    SELECT o_id 
    INTO customer_last_order_id 
    FROM "order" 
    WHERE o_w_id = input_c_w_id AND o_d_id = input_c_d_id AND o_c_id = input_c_id 
    ORDER BY o_entry_d DESC LIMIT 1;

    -- Step 2.1: Get item IDs for the last order
    SELECT ARRAY_AGG(DISTINCT ol_i_id)
    INTO customer_item_ids
    FROM "order-line"
    WHERE ol_w_id = input_c_w_id AND ol_d_id = input_c_d_id AND ol_o_id = customer_last_order_id;

    -- Check if the customer has items in the last order
    IF customer_item_ids IS NULL OR array_length(customer_item_ids, 1) = 0 THEN
        RAISE NOTICE 'No items in the customer''s last order.';
        RETURN;
    END IF;
    RAISE NOTICE 'Customer: (%, %, %)', input_c_w_id, input_c_d_id, input_c_id;

    -- Step 3: Find related customers
    FOR related_customers IN
        WITH c2_customers AS (
            SELECT c_w_id, c_d_id, c_id
            FROM "customer_2-8"
            WHERE c_state = customer_state
            AND NOT (c_w_id = input_c_w_id AND c_d_id = input_c_d_id AND c_id = input_c_id)
        ),
        c2_last_orders AS (
            SELECT o.o_w_id AS c_w_id, o.o_d_id AS c_d_id, o.o_c_id AS c_id, MAX(o.o_id) AS o_id
            FROM "order" o
            JOIN c2_customers c2 ON o.o_w_id = c2.c_w_id AND o.o_d_id = c2.c_d_id AND o.o_c_id = c2.c_id
            GROUP BY o.o_w_id, o.o_d_id, o.o_c_id
        ),
        c2_items AS (
            SELECT c2.c_w_id, c2.c_d_id, c2.c_id, ol.ol_i_id
            FROM c2_last_orders c2
            JOIN "order-line" ol 
            ON ol.ol_w_id = c2.c_w_id AND ol.ol_d_id = c2.c_d_id AND ol.ol_o_id = c2.o_id
            WHERE ol.ol_i_id = ANY(customer_item_ids)
        )
        SELECT c_w_id, c_d_id, c_id
        FROM (
            SELECT c2_items.c_w_id, c2_items.c_d_id, c2_items.c_id, COUNT(DISTINCT c2_items.ol_i_id) AS common_items
            FROM c2_items
            GROUP BY c2_items.c_w_id, c2_items.c_d_id, c2_items.c_id
        ) sub
        WHERE sub.common_items >= 2
        ORDER BY c_w_id, c_d_id, c_id
    LOOP
        -- Append to output for each related customer
       RAISE NOTICE 'Related Customer: (C_W_ID: %, C_D_ID: %, C_ID: %)', related_customers.c_w_id, related_customers.c_d_id, related_customers.c_id;
    END LOOP;


END;
\$\$;

EOF
)

# Execute the SQL commands via psql
INSTALLDIR=$HOME/pgsql
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "$DROP_PROCEDURE_SQL"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "$CREATE_PROCEDURE_SQL"
