import os
import psycopg2
from datetime import datetime, timezone

from dotenv import load_dotenv
class Transactions:
    cursor = None
    conn = None

    def __init__(self):
        load_dotenv()
        host = os.getenv("DATABASE_HOST")
        database = os.getenv("DATABASE_NAME")
        username = os.getenv("DATABASE_USERNAME")
        port = int(os.getenv("DATABASE_PORT", "5432"))
        password = os.getenv("DATABASE_PASSWORD")

        try:
            self.conn = psycopg2.connect(
                host=host,
                database=database,
                user=username,
                password=password,
                port=port
            )
            # self.conn.autocommit = True

            self.cursor = self.conn.cursor()
            print("Cursor created successfully")


        except (Exception, psycopg2.DatabaseError) as error:
            print(f"Error while connecting to PostgreSQL: {error}")

    def __close_connection__(self):
        self.cursor.close()
        self.conn.close()
        print("Connection closed")

    # define the datatypes for each transaction
    def cast_new_order_type(self, params):
        return [int(params[0]), int(params[1]), int(params[2]), int(params[3])]

    def cast_order_status_type(self, params):
        return [int(params[0]), int(params[1]), int(params[2])]

    def cast_stock_level_type(self, params):
        return [int(params[0]), int(params[1]), int(params[2]), int(params[3])]

    def cast_payment_type(self, params):
        return [int(params[0]), int(params[1]), int(params[2]), float(params[3])]

    def cast_delivery_type(self, params):
        return [int(params[0]), int(params[1])]

    def cast_top_balance_type():
        return []

    def cast_related_customer_type(self, params):
        return [int(params[0]), int(params[1]), int(params[2])]

    def cast_popular_item_type(self, params):
        return [int(params[0]), int(params[1]), int(params[2])]


    # 2.1 new-order transaction
    def new_order_txn(self, c_id, w_id, d_id, num_items, item_ids, supplier_warehouses, quantities):
        """
        Handles a new order transaction based on parsed inputs.

        Args:
            c_id (int): Customer ID
            w_id (int): Warehouse ID
            d_id (int): District ID
            num_items (int): Number of items in the order
            item_ids (List[int]): List of item IDs
            supplier_warehouses (List[int]): List of supplier warehouse IDs
            quantities (List[int]): List of quantities for each item
        """
        print(c_id, w_id, d_id, num_items, item_ids, supplier_warehouses, quantities)
        try:
            self.cursor.execute("BEGIN")
            # Finish this code, call the stored procedure
            self.cursor.execute("""
                call new_order(%s, %s, %s, %s, %s, %s, %s)
            """, (w_id,d_id ,c_id, num_items, item_ids, supplier_warehouses, quantities))
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")


        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None

    # 2.2 payment transaction
    def payment_txn(self, c_w_id, c_d_id, c_id, payment):
        """
        Processes a payment made by a customer and updates the warehouse, district, and customer information accordingly.

        Args:
            c_w_id (int): Warehouse ID of the customer
            c_d_id (int): District ID of the customer
            c_id (int): Customer ID
            payment (float): Payment amount

        Output:
            - Updated customer, warehouse, and district information
            - Customer details (ID, name, address, phone, credit info, balance)
            - Warehouse address
            - District address
            - Payment amount
        """
        try:
            self.cursor.execute("BEGIN")
            print(c_w_id, c_d_id, c_id, payment)
            self.cursor.execute("""
                call process_payment(%s, %s, %s, %s);
            """, (c_w_id, c_d_id, c_id, payment))
            # Capture any notices that were raised
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")


        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None

    # 2.3 delivery transaction
    def delivery_txn(self, w_id, carrier_id):
        """
        Handles a delivery transaction.

        Args:
            w_id (int): Warehouse ID
            carrier_id (int): Carrier ID
        """
        try:
            self.cursor.execute("BEGIN")
            # Step 1: Get customer name and balance
            self.cursor.execute("""
                call delivery_txn(%s,%s);
            """, (w_id, carrier_id))
            # Capture any notices that were raised
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None

    # 2.4 order-status transaction
    def order_status_txn(self, c_w_id, c_d_id, c_id):
        """
        Queries the status of the last order of a customer.

        Args:
            c_w_id (int): Customer's warehouse ID
            c_d_id (int): Customer's district ID
            c_id (int): Customer's ID

        Output:
            - Customer's name (C_FIRST, C_MIDDLE, C_LAST), balance (C_BALANCE)
            - Last order details (O_ID, O_ENTRY_D, O_CARRIER_ID)
            - Item details in the last order (OL_I_ID, OL_SUPPLY_W_ID, OL_QUANTITY, OL_AMOUNT, OL_DELIVERY_D)
        """
        try:
            self.cursor.execute("BEGIN")
            # Step 1: Get customer name and balance
            self.cursor.execute("""
                call query_last_order_status(%s,%s,%s);
            """, (c_w_id, c_d_id, c_id))
            # Capture any notices that were raised
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None

    # 2.5 stock-level transaction
    def stock_level_txn(self, w_id, d_id, threshold, num_last_orders):
        """
        Handles a stock level transaction that examines the items from the last L orders at a specified warehouse district 
        and reports the number of items that have a stock level below a specified threshold.

        Args:
            w_id (int): Warehouse ID
            d_id (int): District ID
            threshold (int): Stock level threshold T
            num_last_orders (int): Number of last orders to be examined L
        """
        try:
            self.cursor.execute("BEGIN")
            # Step 1: Get customer name and balance
            self.cursor.execute("""
                call report_low_stock_items(%s,%s,%s,%s);
            """, (w_id, d_id, threshold, num_last_orders))
            # Capture any notices that were raised
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None

    # 2.6 popular-item transaction
    def popular_item_txn(self, w_id, d_id, l):
        """
        Finds the 5 most popular items in the last L orders at a specified warehouse district.

        Args:
            w_id (int): Warehouse ID
            d_id (int): District ID
            l (int): Number of last orders to be examined

        Output:
            - District identifier (W_ID, D_ID)
            - Number of last orders to be examined (L)
            - For each item in P (most to least popular):
                a. Item number I_ID
                b. Name I_NAME
                c. Price I_PRICE
                d. Total quantity x.total_qty
                e. Number of orders x.num_orders
        """
        try:
            self.cursor.execute("BEGIN")

            # Step 1: Get the next available order number for the district
            # Can make use of the vertically partitioned District table (district_2-5)
            self.cursor.execute("""
                call find_most_popular_items(%s, %s, %s)
            """, (w_id, d_id, l))
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")
        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None

    # 2.7 top-balance transcations
    def top_balance_txn(self):
        """
        Handles the top balance transaction that finds the top-10 customers ranked in non-ascending order of their outstanding balance.

        Output:
            For each of the top 10 customers ranked in non-ascending order of C_BALANCE:
            a. Name of customer (C_FIRST, C_MIDDLE, C_LAST)
            b. Balance of customer's outstanding payment (C_BALANCE)
            c. Warehouse name (W_NAME)
            d. District name (D_NAME)
        """
        try:
            self.cursor.execute("BEGIN")
            # Finish this code, call the stored procedure
            self.cursor.execute("""
                call gettop10customers();
            """, ())
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")
            return None

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None

    # 2.8 related-customer transactions
    def related_customer_txn(self, c_w_id, c_d_id, c_id):
        """
        Finds all the customers who are related to a specific customer based on the following criteria:
        1. Both customers are located in the same state.
        2. There are at least two items in common between the given customer's last order and the other customer's last order.
        
        Args:
            c_w_id (int): Warehouse ID of the given customer
            c_d_id (int): District ID of the given customer
            c_id (int): Customer ID of the given customer

        Output:
            For each related customer, return customer identifiers (C_W_ID, C_D_ID, C_ID)
            and for each customer, return the identifiers (C_W_ID, C_D_ID, C_ID) of each related customer.
        """
        try:
            self.cursor.execute("BEGIN")
            # Step 1: Get customer name and balance
            self.cursor.execute("""
                call find_related_customers(%s,%s,%s);
            """, (c_w_id, c_d_id, c_id))
            # Capture any notices that were raised
            for notice in self.cursor.connection.notices:
                print(notice.strip())
            self.cursor.execute("COMMIT")

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None