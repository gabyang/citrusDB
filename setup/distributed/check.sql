-- Count of rows in each table
SELECT 'warehouse' AS table_name, COUNT(*) AS row_count FROM warehouse
UNION ALL
SELECT 'district' AS table_name, COUNT(*) AS row_count FROM district
UNION ALL
SELECT 'customer' AS table_name, COUNT(*) AS row_count FROM customer
UNION ALL
SELECT 'customer_2-7' AS table_name, COUNT(*) AS row_count FROM "customer_2-7"
UNION ALL
SELECT 'customer_2-8' AS table_name, COUNT(*) AS row_count FROM "customer_2-8"
UNION ALL
SELECT 'order' AS table_name, COUNT(*) AS row_count FROM "order"
UNION ALL
SELECT 'item' AS table_name, COUNT(*) AS row_count FROM item
UNION ALL
SELECT 'order-line' AS table_name, COUNT(*) AS row_count FROM "order-line"
UNION ALL
SELECT 'order-line-item-constraint' AS table_name, COUNT(*) AS row_count FROM "order-line-item-constraint"
UNION ALL
SELECT 'stock' AS table_name, COUNT(*) AS row_count FROM Stock
UNION ALL
SELECT 'stock_2-5' AS table_name, COUNT(*) AS row_count FROM "stock_2-5";
