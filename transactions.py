import os
from dotenv import load_dotenv
import psycopg2

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

        # host="localhost"
        # database = "postgres"
        # username = "postgres"
        # port = 5432
        # password = None

        try:
            self.conn = psycopg2.connect(
                host=host,
                database=database,
                user=username,
                password=password,
                port=port
            )

            # Test for the connection to postgresql database
            # query = "SELECT * FROM customer LIMIT 10"
            # cur.execute(query)
            # rows = cur.fetchall()
            # print("Query executed successfully")
            # print("Number of rows:", len(rows))
            # print("First row:", rows[0])
            print("Successfully connected to the PostgreSQL database")
            
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
    def new_order_txn(self, c_id, w_id, d_id, num_items, item_number, supplier_warehouse, quantity):
        return

    # 2.2 payment transaction
    def payment_txn(self, c_w_id, c_d_id, c_id, payment):
        return

    # 2.3 delivery transaction
    def delivery_txn(self, w_id, CARRIER_ID):
        return

    # 2.4 order-status transaction
    def order_status_txn(self, c_w_id, c_d_id, c_id):
        return

    # 2.5 stock-level transaction
    def stock_level_txn(self, w_id, d_id, t, l):
        return

    # 2.6 popular-item transaction
    def popular_item_txn(self, w_id, d_id, l):
        return

    # 2.7 top-balance transcations
    def top_balance_txn(self):
        return

    # 2.8 related-customer transactions
    def related_customer_txn(self, c_w_id, c_d_id, c_id):
        return

