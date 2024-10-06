-- Split table and enforce contrainsts in separate tables

CREATE TABLE warehouse (
	W_ID INT PRIMARY KEY,
	W_NAME VARCHAR(10),
	W_STREET_1 VARCHAR(20),
	W_STREET_2 VARCHAR(20),
	W_CITY VARCHAR(20),
	W_STATE CHAR(2),
	W_ZIP CHAR(9),
	W_TAX DECIMAL(4, 4),
	W_YTD DECIMAL(12, 2)
);
SELECT create_distributed_table('warehouse', 'w_id');

CREATE TABLE district (
	D_W_ID INT,
	D_ID INT,
	D_NAME VARCHAR(10),
	D_STREET_1 VARCHAR(20),
	D_STREET_2 VARCHAR(20),
	D_CITY VARCHAR(20),
	D_STATE CHAR(2),
	D_ZIP CHAR(9),
	D_TAX DECIMAL(4, 4),
	D_YTD DECIMAL(12, 2),
	D_NEXT_O_ID INT,
	PRIMARY KEY (D_W_ID, D_ID),
	FOREIGN KEY (D_W_ID) REFERENCES Warehouse(W_ID)
);
SELECT create_distributed_table('district', 'd_w_id', colocate_with => 'warehouse');

CREATE TABLE customer (
	C_W_ID INT,
	C_D_ID INT,
	C_ID INT,
	C_FIRST VARCHAR(16),
	C_MIDDLE CHAR(2),
	C_LAST VARCHAR(16),
	C_STREET_1 VARCHAR(20),
	C_STREET_2 VARCHAR(20),
	C_CITY VARCHAR(20),
	C_STATE CHAR(2),
	C_ZIP CHAR(9),
	C_PHONE CHAR(16),
	C_SINCE TIMESTAMP,
	C_CREDIT CHAR(2),
	C_CREDIT_LIM DECIMAL(12, 2),
	C_DISCOUNT DECIMAL(5, 4),
	C_BALANCE DECIMAL(12, 2),
	C_YTD_PAYMENT FLOAT,
	C_PAYMENT_CNT INT,
	C_DELIVERY_CNT INT,
	C_DATA VARCHAR(500),
	PRIMARY KEY (C_W_ID, C_D_ID, C_ID),
	FOREIGN KEY (C_W_ID, C_D_ID) REFERENCES District(D_W_ID, D_ID)
);
SELECT create_distributed_table('customer', 'c_w_id', colocate_with => 'warehouse');

CREATE TABLE "order" (
    O_W_ID INT,
    O_D_ID INT,
    O_ID INT,
    O_C_ID INT,
    O_CARRIER_ID INT,
    O_OL_CNT DECIMAL(2, 0),
    O_ALL_LOCAL DECIMAL(1, 0),
    O_ENTRY_D TIMESTAMP,
    PRIMARY KEY (O_W_ID, O_D_ID, O_ID),
    FOREIGN KEY (O_W_ID, O_D_ID, O_C_ID) REFERENCES Customer(C_W_ID, C_D_ID, C_ID),
    CHECK (O_CARRIER_ID IS NULL OR (O_CARRIER_ID BETWEEN 1 AND 10))
);
SELECT create_distributed_table('order', 'o_w_id', colocate_with => 'warehouse');

CREATE TABLE item (
    I_ID INT PRIMARY KEY,
    I_NAME VARCHAR(24),
    I_PRICE DECIMAL(5, 2),
    I_IM_ID INT,
    I_DATA VARCHAR(50)
);
SELECT create_distributed_table('item', 'i_id');

CREATE TABLE "order-line" (
    OL_W_ID INT,
    OL_D_ID INT,
    OL_O_ID INT,
    OL_NUMBER INT,
    OL_I_ID INT,
    OL_DELIVERY_D TIMESTAMP,
    OL_AMOUNT DECIMAL(7, 2),
    OL_SUPPLY_W_ID INT,
    OL_QUANTITY DECIMAL(2, 0),
    OL_DIST_INFO CHAR(24),
    PRIMARY KEY (OL_W_ID, OL_D_ID, OL_O_ID, OL_NUMBER),
    FOREIGN KEY (OL_W_ID, OL_D_ID, OL_O_ID) REFERENCES "order"(O_W_ID, O_D_ID, O_ID)
);
SELECT create_distributed_table('order-line', 'ol_w_id', colocate_with => 'warehouse');

CREATE TABLE "order-line-item" (
    OL_W_ID INT,
    OL_D_ID INT,
    OL_O_ID INT,
    OL_NUMBER INT,
    OL_I_ID INT,
    FOREIGN KEY (OL_I_ID) REFERENCES Item(I_ID)
);
SELECT create_distributed_table('order-line-item', 'ol_i_id', colocate_with => 'item');

CREATE TABLE Stock (
    S_W_ID INT,
    S_I_ID INT,
    S_QUANTITY DECIMAL(4, 0),
    S_YTD DECIMAL(8, 2),
    S_ORDER_CNT INT,
    S_REMOTE_CNT INT,
    S_DIST_01 CHAR(24),
    S_DIST_02 CHAR(24),
    S_DIST_03 CHAR(24),
    S_DIST_04 CHAR(24),
    S_DIST_05 CHAR(24),
    S_DIST_06 CHAR(24),
    S_DIST_07 CHAR(24),
    S_DIST_08 CHAR(24),
    S_DIST_09 CHAR(24),
    S_DIST_10 CHAR(24),
    S_DATA VARCHAR(50),
    PRIMARY KEY (S_W_ID, S_I_ID),
    FOREIGN KEY (S_W_ID) REFERENCES Warehouse(W_ID)
);
SELECT create_distributed_table('stock', 's_w_id', colocate_with => 'warehouse');

CREATE TABLE "stock-item" (
    S_W_ID INT,
    S_I_ID INT,
    FOREIGN KEY (S_I_ID) REFERENCES Item(I_ID)
);
SELECT create_distributed_table('stock-item', 's_i_id', colocate_with => 'item');
