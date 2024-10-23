-- Disable foreign key checks if necessary (this is DBMS specific)
-- This part might not be needed depending on the database system you're using.
-- For example, in PostgreSQL you would need to use "SET session_replication_role = 'replica';"
-- and for MySQL you can use "SET FOREIGN_KEY_CHECKS=0;"

-- Deleting from child tables first
DELETE FROM "order-line-item-constraint";
DELETE FROM "order-line";
DELETE FROM "customer_2-8";
DELETE FROM "customer_2-7";
DELETE FROM "customer_2-5";
DELETE FROM "customer";  -- This has dependencies on district
DELETE FROM "order";      -- This has dependencies on customer
DELETE FROM "stock_2-5";
DELETE FROM Stock;        -- This has dependencies on warehouse
DELETE FROM district;     -- This has dependencies on warehouse
DELETE FROM warehouse;    -- Last to delete

-- Enable foreign key checks if they were disabled
-- For example, in PostgreSQL you would need to use "SET session_replication_role = 'origin';"
-- and for MySQL you can use "SET FOREIGN_KEY_CHECKS=1;"
