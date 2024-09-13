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

            # # Test for the connection to postgresql database
            # query = "SELECT * FROM customer LIMIT 10"
            # self.cursor.execute(query)
            # rows = self.cursor.fetchall()
            # print("Query executed successfully")
            # print("Number of rows:", len(rows))
            # print("First row:", rows[0])
            # print("Successfully connected to the PostgreSQL database")
            # print(self.cursor )
            

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
        try:
            self.cursor.execute("BEGIN")

            orderline_inputs = []
            for i in range(num_items):
                orderline_inputs.append((
                    item_ids[i],
                    supplier_warehouses[i],
                    quantities[i]
                ))

            # Check if all items are from the same warehouse
            is_all_local = int(all(warehouse_id == w_id for warehouse_id in supplier_warehouses))

            # step 1 and step 2
            next_order_id = None
            self.cursor.execute("SELECT D_NEXT_O_ID FROM district WHERE D_ID = %s AND D_W_ID = %s", (d_id, w_id))
            next_order_id = self.cursor.fetchone()[0] + 1
            self.cursor.execute("UPDATE district SET D_NEXT_O_ID = D_NEXT_O_ID + 1 WHERE D_ID = %s AND D_W_ID = %s", (d_id, w_id))

            # step 3
            entry_time = datetime.now(timezone.utc)
            self.cursor.execute("INSERT INTO \"order\"(O_ID, O_D_ID, O_W_ID, O_C_ID, O_ENTRY_D, O_CARRIER_ID, O_OL_CNT, O_ALL_LOCAL) VALUES (%s, %s, %s, %s, %s, NULL, %s, %s)", 
                                (next_order_id, d_id, w_id, c_id, entry_time, num_items, is_all_local))
            
            # Update stock and calculate total amount
            total_amount = 0
            orderline_outputs = []
            stock_deltas = []

            # retrieve item prices
            self.cursor.execute("SELECT I_PRICE, I_NAME FROM item WHERE I_ID = ANY(%s)", (item_ids,))
            result = self.cursor.fetchall()
            item_prices = [round(float(x[0]), 2) for x in result]
            item_names = [x[1] for x in result]

            # retrieve distance information
            stock_dist_id = f'S_DIST_0{d_id}' if d_id < 10 else f'S_DIST_{d_id}'
            query = f"SELECT {stock_dist_id} FROM stock WHERE S_I_ID = ANY(%s) AND S_W_ID = {w_id}"
            self.cursor.execute(query, (item_ids,))
            result = self.cursor.fetchall()
            ol_dist = [x[0] for x in result]
            # TODO: check if the ol_dist needs to be stripped of its blank spaces - note that the distances already have blank spaces.

            # TODO: Optimize the for loop below to update ALL if that is possible.
            for idx, ol in enumerate(orderline_inputs):
                ol_item_id = ol[0]
                ol_warehouse = ol[1]
                ol_quantity = ol[2]
                self.cursor.execute("SELECT S_QUANTITY, S_YTD, S_ORDER_CNT, S_REMOTE_CNT FROM stock WHERE S_I_ID = %s AND S_W_ID = %s", 
                    (ol_item_id, ol_warehouse))

                quantity, ytd, order_count, remote_count = self.cursor.fetchone()

                next_quantity = quantity + ol_quantity
                next_quantity = next_quantity + 100 if next_quantity < 10 else next_quantity
                next_ytd = ytd + ol_quantity
                next_order_count = order_count + 1
                next_remote_count = remote_count + (1 if ol_warehouse != w_id else 0)

                self.cursor.execute("UPDATE stock SET S_QUANTITY = %s, S_YTD = %s, S_ORDER_CNT = %s, S_REMOTE_CNT = %s WHERE s_w_id = %s AND s_i_id = %s", 
                    (next_quantity, next_ytd, next_order_count, next_remote_count, ol_warehouse, ol_item_id)
                )

                item_amount = item_prices[idx] * ol_quantity
                total_amount += item_amount

                orderline_outputs.append([
                    ol_item_id, item_names[idx], ol_warehouse, ol_quantity, item_amount, next_quantity
                ])

                # step 5
                self.cursor.execute(
                    "INSERT INTO \"order-line\"(ol_w_id, ol_d_id, ol_o_id, ol_number, ol_i_id, ol_amount, ol_supply_w_id, ol_quantity, ol_dist_info, ol_delivery_d) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, NULL)",
                    (w_id, d_id, next_order_id, idx + 1, ol_item_id, item_prices[idx], ol_warehouse, ol_quantity, ol_dist[idx])
                )
            
            self.cursor.execute("SELECT d_tax FROM district WHERE D_ID = %s AND D_W_ID = %s", (d_id, w_id))
            d_tax = round(float(self.cursor.fetchone()[0]), 2)
            print(d_tax)

            self.cursor.execute("SELECT w_tax FROM warehouse WHERE W_ID = %s", (w_id,))
            w_tax = round(float(self.cursor.fetchone()[0]), 4)
            print(w_tax)

            self.cursor.execute("SELECT c_discount, c_last, c_credit FROM customer WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s", (w_id, d_id, c_id))
            c_discount, c_last, c_credit = self.cursor.fetchone()
            print(c_discount, c_last, c_credit)

            print(next_order_id, entry_time)

            # step 6 
            total_amount = total_amount * (1 + d_tax + w_tax) * (1 - float(c_discount))
            print(num_items, total_amount)

            print(orderline_outputs)
            # self.cursor.execute("COMMIT")

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
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
