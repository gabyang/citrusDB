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
    def new_order_txn(self, c_id, w_id, d_id, num_items, item_numbers, supplier_warehouses, quantities):
        """
        Handles a new order transaction based on parsed inputs.

        Args:
            c_id (int): Customer ID
            w_id (int): Warehouse ID
            d_id (int): District ID
            num_items (int): Number of items in the order
            item_numbers (List[int]): List of item IDs
            supplier_warehouses (List[int]): List of supplier warehouse IDs
            quantities (List[int]): List of quantities for each item
        """

        orderline_inputs = []
        for i in range(num_items):
            orderline_inputs.append((
                item_numbers[i],
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
        print(is_all_local)
        self.cursor.execute("INSERT INTO \"order\"(O_ID, O_D_ID, O_W_ID, O_C_ID, O_ENTRY_D, O_CARRIER_ID, O_OL_CNT, O_ALL_LOCAL) VALUES (%s, %s, %s, %s, %s, NULL, %s, %s)", 
                            (next_order_id, d_id, w_id, c_id, entry_time, num_items, is_all_local))
        
        # Update stock and calculate total amount
        total_amount = 0
        orderline_outputs = []
        stock_deltas = []

        for ol in orderline_inputs:
            self.cursor.execute("SELECT S_QUANTITY, S_YTD, S_ORDER_CNT, S_REMOTE_CNT FROM stock WHERE S_I_ID = %s AND S_W_ID = %s", 
                (ol[0], ol[1]))

            quantity, ytd, order_count, remote_count = self.cursor.fetchone()

            next_quantity = quantity + ol[3]
            next_quantity = next_quantity + 100 if next_quantity < 10 else next_quantity
            next_ytd = ytd + ol[3]
            next_order_count = order_count + 1
            next_remote_count = remote_count + (1 if ol[1] != w_id else 0)

            self.cursor.execute("UPDATE stocks SET S_QUANTITY = ?, S_YTD = ?, S_ORDER_CNT = ?, S_REMOTE_CNT = ? WHERE s_w_id = ? AND s_i_id = ?", 
                (next_quantity, next_ytd, next_order_count, next_remote_count, ol[1], ol[0])
            )

            item_info = item_id_to_item_info[ol.ItemId]
            item_amount = item_info.Price * ol.Quantity
            total_amount += item_amount

        
        # def update_stock_txn():
        #     nonlocal total_amount
        #     for ol in orderline_inputs:
        #         quantity, ytd, order_count, remote_count = db.execute(
        #             "SELECT s_qty, s_ytd, s_order_cnt, s_remote_cnt FROM stocks WHERE s_w_id = ? AND s_i_id = ?", 
        #             (ol.SupplyWid, ol.ItemId)
        #         ).fetchone()
                
        #         next_quantity = quantity + ol.Quantity
        #         next_quantity = next_quantity + 100 if next_quantity < 10 else next_quantity
        #         next_ytd = ytd + ol.Quantity
        #         next_order_count = order_count + 1
        #         next_remote_count = remote_count + (1 if ol.SupplyWid != w_id else 0)
                
        #         db.execute(
        #             "UPDATE stocks SET s_qty = ?, s_ytd = ?, s_order_cnt = ?, s_remote_cnt = ? WHERE s_w_id = ? AND s_i_id = ?", 
        #             (next_quantity, next_ytd, next_order_count, next_remote_count, ol.SupplyWid, ol.ItemId)
        #         )

        #         item_info = item_id_to_item_info[ol.ItemId]
        #         item_amount = item_info.Price * ol.Quantity
        #         total_amount += item_amount
                
        #         orderline_outputs.append(OrderlineOutput(
        #             ol.ItemId, item_info.Name, ol.SupplyWid, ol.Quantity, item_amount, next_quantity, item_info.DistInfo
        #         ))

        #         stock_deltas.append(StockDelta(
        #             next_quantity - quantity, next_ytd - ytd, 1, next_remote_count - remote_count, ol.SupplyWid, ol.ItemId
        #         ))

        # retry(update_stock_txn)
        
        # self.cursor.execute("SELECT * FROM \"order\" WHERE O_ID = %s AND O_D_ID = %s AND O_W_ID = %s", (next_order_id, d_id, w_id))
        # print(self.cursor.fetchone())

        
        # step 4 & 5


        # def insert_order_txn():
        #     # Insert order in orders table
        #     db.execute(
        #         "INSERT INTO orders(o_w_id, o_d_id, o_id, o_c_id, o_carrier_id, o_ol_cnt, o_all_local, o_entry_d) VALUES (?, ?, ?, ?, NULL, ?, ?, ?)", 
        #         (w_id, d_id, next_order_id, c_id, num_items, is_all_local, entry_time)
        #     )

        #     # Insert each order line in order_lines table
        #     for i, ol in enumerate(orderline_outputs):
        #         db.execute(
        #             "INSERT INTO order_lines(ol_w_id, ol_d_id, ol_o_id, ol_number, ol_i_id, ol_i_name, ol_delivery_d, ol_amount, ol_supply_w_id, ol_quantity, ol_dist_info) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?)",
        #             (w_id, d_id, next_order_id, i + 1, ol.ItemId, ol.Name, ol.ItemAmount, ol.SupplyWid, ol.Quantity, ol.DistInfo)
        #         )

        # retry(insert_order_txn)


        # step 6 
        # self.cursor.execute("SELECT d_tax, w_tax FROM district WHERE D_ID = %s AND D_W_ID = %s", (d_id, w_id))
        # d_tax, w_tax = self.cursor.fetchone()
        # print(d_tax, w_tax)
                
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



# 2.1 new-order transaction
def new_order_txn(c_id, w_id, d_id, num_items, item_numbers, supplier_warehouses, quantities):
    
    # Initial order line processing
    
    # 

    return None

    

    # # Fetch customer information
    # c_discount, c_last, c_credit = db.execute(
    #     "SELECT c_discount, c_last, c_credit FROM customer_info WHERE c_w_id = ? AND c_d_id = ? AND c_id = ?", 
    #     (w_id, d_id, c_id)
    # ).fetchone()

    # # Prepare item information lookup
    # item_id_to_item_info = {}
    # for ol in orderline_inputs:
    #     price, name = db.execute("SELECT i_price, i_name FROM items WHERE i_id = ?", (ol.ItemId,)).fetchone()
    #     dist_info = db.execute(f"SELECT s_dist_{d_id:02d} FROM stock_info_by_district WHERE s_w_id = ? AND s_i_id = ?", (w_id, ol.ItemId)).fetchone()[0]
    #     item_id_to_item_info[ol.ItemId] = ItemInfo(price, name, dist_info)

    

    

    # # Log the final result
    # sb = []
    # sb.append(f"c_w_id: {w_id}, c_d_id: {d_id}, c_id: {c_id}, c_last: {c_last}, c_credit: {c_credit}, c_discount: {c_discount}")
    # sb.append(f"o_id: {next_order_id}, o_entry_d: {entry_time}")
    # sb.append(f"num_items: {num_items}, total_amount: {total_amount}")
    # for ol in orderline_outputs:
    #     sb.append(f"item_number: {ol.ItemId}, i_name: {ol.Name}, supplier_warehouse: {ol.SupplyWid}, quantity: {ol.OrderlineQuantity}, ol_amount: {ol.ItemAmount}, s_quantity: {ol.Quantity}")
    
    # logs.info("\n".join(sb))


# def retry(transaction_function):
#     """
#     Dummy retry logic. This should be replaced with actual retry logic.
#     """
#     try:
#         transaction_function()
#     except Exception as e:
#         print(f"Retry failed: {e}")
#         # Implement actual retry logic or handling
#     return
