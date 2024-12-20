-- Inserting sample data into the warehouse table with shorter names
INSERT INTO warehouse (W_ID, W_NAME, W_STREET_1, W_STREET_2, W_CITY, W_STATE, W_ZIP, W_TAX, W_YTD) VALUES
    (1, 'W-A', '100 Warehouse Rd', 'Suite 1', 'New York', 'NY', '10001', 0.07, 15000.00),
    (2, 'W-B', '200 Industrial Blvd', NULL, 'Los Angeles', 'CA', '90001', 0.06, 12000.00),
    (3, 'W-C', '300 Logistics Ave', 'Unit 5', 'Chicago', 'IL', '60601', 0.05, 10000.00),
    (4, 'W-D', '400 Supply St', NULL, 'San Francisco', 'CA', '94101', 0.04, 8000.00);
-- Inserting sample data into the district table
INSERT INTO district (D_W_ID, D_ID, D_NAME, D_STREET_1, D_STREET_2, D_CITY, D_STATE, D_ZIP, D_TAX, D_YTD, D_NEXT_O_ID) VALUES
    (1, 1, 'Downtown', '100 Main St', 'Suite 100', 'New York', 'NY', '10001', 0.07, 2000.00, 3),
    (1, 2, 'Uptown', '200 Elm St', NULL, 'Los Angeles', 'CA', '90001', 0.06, 1500.00, 1),
    (2, 1, 'West Side', '300 Oak St', 'Apt 1A', 'Chicago', 'IL', '60601', 0.05, 1000.00, 2),
    (2, 2, 'East Side', '400 Pine St', NULL, 'San Francisco', 'CA', '94101', 0.04, 1200.00, 2);
INSERT INTO "district_2-5" (D_W_ID, D_ID, D_NEXT_O_ID) VALUES
    (1, 1, 3),
    (1, 2, 1),
    (2, 1, 2),
    (2, 2, 2);

INSERT INTO customer (C_W_ID, C_D_ID, C_ID, C_FIRST, C_MIDDLE, C_LAST, C_STREET_1, C_STREET_2, C_CITY, C_STATE, C_ZIP, C_PHONE, C_SINCE, C_CREDIT, C_CREDIT_LIM, C_DISCOUNT, C_BALANCE, C_YTD_PAYMENT, C_PAYMENT_CNT, C_DELIVERY_CNT, C_DATA)
VALUES 
    (1, 1, 1, 'John', 'A', 'Doe', '123 Main St', 'Apt 4', 'New York', 'NY', '10001', '1234567890', '2022-01-01 10:00:00', 'BC', 5000.00, 0.10, 100.00, 50.00, 5, 1, 'Regular customer'),
    (1, 1, 2, 'Jane', 'B', 'Smith', '456 Elm St', NULL, 'Los Angeles', 'CA', '90001', '0987654321', '2022-01-02 11:00:00', 'CC', 3000.00, 0.05, 200.00, 75.00, 10, 2, 'VIP customer'),
    (1, 2, 1, 'Alice', 'C', 'Johnson', '789 Maple St', NULL, 'Chicago', 'IL', '60601', '1231231234', '2022-01-03 12:00:00', 'GC', 2000.00, 0.15, 150.00, 20.00, 3, 1, 'First-time customer'),
    (1, 2, 3, 'BoB', 'C', 'Builder', '123 Dude St', NULL, 'Chicago', 'IL', '22334', '1231231234', '2022-01-03 12:00:00', 'GC', 2000.00, 0.15, 150.00, 20.00, 3, 1, 'second-time customer');

-- Inserting sample data into the customer_2-7 table
INSERT INTO "customer_2-7" (C_W_ID, C_D_ID, C_ID, C_FIRST, C_MIDDLE, C_LAST, C_BALANCE)
VALUES 
    (1, 1, 1, 'John', 'A', 'Doe', 100.00),
    (1, 1, 2, 'Jane', 'B', 'Smith', 200.00),
    (1, 2, 1, 'Alice', 'C', 'Johnson', 150.00),
    (1, 2,3 , 'BoB', 'C', 'Builder', 150.00);

-- Inserting sample data into the customer_2-8 table
INSERT INTO "customer_2-8" (C_W_ID, C_D_ID, C_ID, C_STATE)
VALUES 
    (1, 1, 1, 'BC'),
    (1, 1, 2, 'CC'),
    (1, 2, 1, 'GC'),
    (1, 2, 3, 'GC');

-- Inserting sample data into the order table
INSERT INTO "order" (O_W_ID, O_D_ID, O_ID, O_C_ID, O_CARRIER_ID, O_OL_CNT, O_ALL_LOCAL, O_ENTRY_D)
VALUES 
    (1, 1, 1, 1, 1, 2, 1, '2024-10-20 14:00:00'),  -- Order 1
    (1, 1, 2, 2, 5, 1, 0, '2024-10-21 09:30:00'),  -- Order 2
    (1, 2, 3, 1, NULL, 3, 1, '2024-10-22 11:15:00'), -- Order 3
    (1, 2, 4, 3, NULL, 3, 1, '2024-10-22 11:15:00'); -- Order 4
-- Inserting sample data into the order-line table
INSERT INTO "order-line" (OL_W_ID, OL_D_ID, OL_O_ID, OL_NUMBER, OL_I_ID, OL_DELIVERY_D, OL_AMOUNT, OL_SUPPLY_W_ID, OL_QUANTITY, OL_DIST_INFO)
VALUES 
    (1, 1, 1, 1, 1, '2024-10-22 15:00:00', 19.99, 1, 2, 'S_DIST_1'),  -- Order Line 1 for Order 1
    (1, 1, 1, 2, 2, '2024-10-22 15:00:00', 29.99, 1, 1, 'S_DIST_1'),  -- Order Line 2 for Order 1
    (1, 1, 2, 1, 3, '2024-10-22 16:00:00', 39.99, 2, 3, 'S_DIST_1'),  -- Order Line 1 for Order 2
    (1, 2, 3, 1, 4, '2024-10-22 17:00:00', 49.99, 1, 1, 'S_DIST_2'),  -- Order Line 1 for Order 3
    (1, 2, 3, 2, 5, '2024-10-22 17:00:00', 59.99, 2, 2, 'S_DIST_2'),  -- Order Line 2 for Order 3
    (1, 2, 4, 1, 4, '2024-10-22 17:00:00', 49.99, 1, 1, 'S_DIST_2'),  -- Order Line 1 for Order 3
    (1, 2, 4, 2, 5, '2024-10-22 17:00:00', 59.99, 2, 2, 'S_DIST_2');  -- Order Line 2 for Order 3

-- Inserting sample data into the item table
INSERT INTO item (I_ID, I_NAME, I_PRICE, I_IM_ID, I_DATA)
VALUES 
    (1, 'Widget A', 1, 101, 'High-quality widget for general use'),
    (2, 'Widget B', 1, 102, 'Versatile widget suitable for various applications'),
    (3, 'Gadget C', 1, 103, 'Advanced gadget with multiple features'),
    (4, 'Gadget D', 1, 104, 'Premium gadget designed for professionals'),
    (5, 'Accessory E', 1, 105, 'Useful accessory for everyday tasks'),
    (6, 'Tool F', 1, 106, 'Durable tool for construction and repairs'),
    (7, 'Device G', 1, 107, 'High-tech device for modern solutions'),
    (8, 'Instrument H', 1, 108, 'Precision instrument for specific tasks'),
    (9, 'Appliance I', 1, 109, 'Essential appliance for home use'),
    (10, 'Equipment J', 1, 110, 'Heavy-duty equipment for industrial applications');

INSERT INTO "order-line-item-constraint" (OL_W_ID, OL_D_ID, OL_O_ID, OL_NUMBER, OL_I_ID)
VALUES 
    (1, 1, 1, 1, 1),  -- Order Line 1 for Order 1
    (1, 1, 1, 2, 2),  -- Order Line 2 for Order 1
    (1, 1, 2, 1, 3),  -- Order Line 1 for Order 2
    (1, 2, 3, 1, 4),  -- Order Line 1 for Order 3
    (1, 2, 3, 2, 5);  -- Order Line 2 for Order 3

INSERT INTO Stock (S_W_ID, S_I_ID, S_QUANTITY, S_YTD, S_ORDER_CNT, S_REMOTE_CNT, S_DIST_01, S_DIST_02, S_DIST_03, S_DIST_04, S_DIST_05, S_DIST_06, S_DIST_07, S_DIST_08, S_DIST_09, S_DIST_10, S_DATA) 
VALUES 
(1, 1, 50, 1000.00, 1, 2, 'Dist info 1', 'Dist info 2', 'Dist info 3', 'Dist info 4', 'Dist info 5', 'Dist info 6', 'Dist info 7', 'Dist info 8', 'Dist info 9', 'Dist info 10', 'Sample data for item 101'),
(1, 2, 20, 500.00, 2, 1, 'Dist info 1', 'Dist info 2', 'Dist info 3', 'Dist info 4', 'Dist info 5', 'Dist info 6', 'Dist info 7', 'Dist info 8', 'Dist info 9', 'Dist info 10', 'Sample data for item 102'),
(1, 3, 75, 750.00, 3, 3, 'Dist info 1', 'Dist info 2', 'Dist info 3', 'Dist info 4', 'Dist info 5', 'Dist info 6', 'Dist info 7', 'Dist info 8', 'Dist info 9', 'Dist info 10', 'Sample data for item 103'),
(1, 4, 10, 300.00, 4, 0, 'Dist info 1', 'Dist info 2', 'Dist info 3', 'Dist info 4', 'Dist info 5', 'Dist info 6', 'Dist info 7', 'Dist info 8', 'Dist info 9', 'Dist info 10', 'Sample data for item 104'),
(1, 5, 35, 400.00, 5, 2, 'Dist info 1', 'Dist info 2', 'Dist info 3', 'Dist info 4', 'Dist info 5', 'Dist info 6', 'Dist info 7', 'Dist info 8', 'Dist info 9', 'Dist info 10', 'Sample data for item 105'),
(1, 6, 35, 300.00, 5, 2, 'Dist info 1', 'Dist info 2', 'Dist info 3', 'Dist info 4', 'Dist info 5', 'Dist info 6', 'Dist info 7', 'Dist info 8', 'Dist info 9', 'Dist info 10', 'Sample data for item 105'),
(1, 7, 35, 200.00, 5, 2, 'Dist info 1', 'Dist info 2', 'Dist info 3', 'Dist info 4', 'Dist info 5', 'Dist info 6', 'Dist info 7', 'Dist info 8', 'Dist info 9', 'Dist info 10', 'Sample data for item 105');

INSERT INTO "stock_2-5" (S_W_ID, S_I_ID, S_QUANTITY) 
VALUES 
(1, 1, 50),
(1, 2, 20),
(1, 3, 75),
(1, 4, 10),
(1, 5, 35),
(1, 6, 35),
(1, 7, 35);


