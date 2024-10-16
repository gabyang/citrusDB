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
            # self.cursor.execute("BEGIN")

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

            # retrieve item prices
            # TODO: Possible bug in ANY(%s)
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

            # Step 1: Update the warehouse by incrementing W_YTD by PAYMENT
            self.cursor.execute("""
                UPDATE warehouse 
                SET w_ytd = w_ytd + %s 
                WHERE w_id = %s
            """, (payment, c_w_id))

            # Step 2: Update the district by incrementing D_YTD by PAYMENT
            self.cursor.execute("""
                UPDATE district 
                SET d_ytd = d_ytd + %s 
                WHERE d_w_id = %s AND d_id = %s
            """, (payment, c_w_id, c_d_id))

            # Step 3: Update the customer as follows:
            # Decrement C_BALANCE, Increment C_YTD_PAYMENT, Increment C_PAYMENT_CNT
            self.cursor.execute("""
                UPDATE customer 
                SET c_balance = c_balance - %s, 
                    c_ytd_payment = c_ytd_payment + %s, 
                    c_payment_cnt = c_payment_cnt + 1
                WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
            """, (payment, payment, c_w_id, c_d_id, c_id))

            # Retrieve the updated customer information
            self.cursor.execute("""
                SELECT c_w_id, c_d_id, c_id, c_first, c_middle, c_last, 
                    c_street_1, c_street_2, c_city, c_state, c_zip, 
                    c_phone, c_since, c_credit, c_credit_lim, 
                    c_discount, c_balance
                FROM customer
                WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
            """, (c_w_id, c_d_id, c_id))
            customer_info = self.cursor.fetchone()

            # Retrieve the warehouse address
            self.cursor.execute("""
                SELECT w_street_1, w_street_2, w_city, w_state, w_zip
                FROM warehouse
                WHERE w_id = %s
            """, (c_w_id,))
            warehouse_info = self.cursor.fetchone()

            # Retrieve the district address
            self.cursor.execute("""
                SELECT d_street_1, d_street_2, d_city, d_state, d_zip
                FROM district
                WHERE d_w_id = %s AND d_id = %s
            """, (c_w_id, c_d_id))
            district_info = self.cursor.fetchone()

            self.cursor.execute("COMMIT")

            # Output the payment transaction details
            print("Customer Information:")
            print(f"ID: ({customer_info[0]}, {customer_info[1]}, {customer_info[2]})")
            print(f"Name: {customer_info[3]} {customer_info[4]} {customer_info[5]}")
            print(f"Address: {customer_info[6]}, {customer_info[7]}, {customer_info[8]}, {customer_info[9]}, {customer_info[10]}")
            print(f"Phone: {customer_info[11]}")
            print(f"Since: {customer_info[12]}")
            print(f"Credit: {customer_info[13]}")
            print(f"Credit Limit: {customer_info[14]}")
            print(f"Discount: {customer_info[15]}")
            print(f"Balance: {customer_info[16]}")

            print("Warehouse Address:")
            print(f"{warehouse_info[0]}, {warehouse_info[1]}, {warehouse_info[2]}, {warehouse_info[3]}, {warehouse_info[4]}")

            print("District Address:")
            print(f"{district_info[0]}, {district_info[1]}, {district_info[2]}, {district_info[3]}, {district_info[4]}")

            print(f"Payment Amount: {payment}")

            return {
                "customer_info": customer_info,
                "warehouse_info": warehouse_info,
                "district_info": district_info,
                "payment_amount": payment
            }

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
            # self.cursor.execute("BEGIN")

            # Process steps for district numbers 1 through 10
            for district_no in range(1, 11):

                # Step 1a: Find the smallest order number O_ID for the district with O_CARRIER_ID = null
                self.cursor.execute("""
                    SELECT MIN(o_id) 
                    FROM "order" 
                    WHERE o_w_id = %s AND o_d_id = %s AND o_carrier_id IS NULL
                    """, (w_id, district_no))
                next_order_id = self.cursor.fetchone()

                if next_order_id is None or next_order_id[0] is None:
                    # If no valid order is found, continue to the next district
                    continue

                next_order_id = next_order_id[0]
                
                # Step 1b: Find the customer who placed the order
                self.cursor.execute("""
                    SELECT o_c_id 
                    FROM "order" 
                    WHERE o_w_id = %s AND o_d_id = %s AND o_id = %s
                    """, (w_id, district_no, next_order_id))
                customer_id = self.cursor.fetchone()[0]

                # Step 1b: Update the order by setting O_CARRIER_ID
                self.cursor.execute("""
                    UPDATE "order" 
                    SET o_carrier_id = %s 
                    WHERE o_w_id = %s AND o_d_id = %s AND o_id = %s
                    """, (carrier_id, w_id, district_no, next_order_id))
                
                # Step 1c: Update all the order lines for this order by setting OL_DELIVERY_D to the current date and time
                delivery_time = datetime.now(timezone.utc)
                self.cursor.execute("""
                    UPDATE "order-line" 
                    SET ol_delivery_d = %s 
                    WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = %s
                    """, (delivery_time, w_id, district_no, next_order_id))

                # Step 1d: Calculate the total amount from all order lines for this order
                self.cursor.execute("""
                    SELECT SUM(ol_amount) 
                    FROM "order-line" 
                    WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = %s
                    """, (w_id, district_no, next_order_id))
                total_amount = self.cursor.fetchone()[0]
                
                
                # Step 1d: Update the customer balance and increment the delivery count
                self.cursor.execute("""
                    UPDATE customer_param 
                    SET c_balance = c_balance + %s, c_delivery_cnt = c_delivery_cnt + 1 
                    WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
                    """, (total_amount, w_id, district_no, customer_id))

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
                SELECT c_first, c_middle, c_last, c_balance
                FROM customer
                WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
            """, (c_w_id, c_d_id, c_id))
            customer_info = self.cursor.fetchone()

            if not customer_info:
                print(f"Customer with ID ({c_w_id}, {c_d_id}, {c_id}) not found.")
                self.cursor.execute("ROLLBACK")
                return None

            print(f"Customer: {customer_info[0]} {customer_info[1]} {customer_info[2]}, Balance: {customer_info[3]}")

            # Step 2: Get the last order of the customer
            self.cursor.execute("""
                SELECT o_id, o_entry_d, o_carrier_id
                FROM "order"
                WHERE o_w_id = %s AND o_d_id = %s AND o_c_id = %s
                ORDER BY o_entry_d DESC LIMIT 1
            """, (c_w_id, c_d_id, c_id))
            last_order = self.cursor.fetchone()

            if not last_order:
                print("No orders found for this customer.")
                self.cursor.execute("ROLLBACK")
                return None

            print(f"Last Order ID: {last_order[0]}, Entry Date: {last_order[1]}, Carrier ID: {last_order[2]}")

            # Step 3: Get the items in the customer's last order
            self.cursor.execute("""
                SELECT ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_delivery_d
                FROM order_lines
                WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = %s
            """, (c_w_id, c_d_id, last_order[0]))
            order_items = self.cursor.fetchall()

            # Output each item in the last order
            for item in order_items:
                print(f"Item ID: {item[0]}, Supply Warehouse ID: {item[1]}, Quantity: {item[2]}, Amount: {item[3]}, Delivery Date: {item[4]}")

            self.cursor.execute("COMMIT")

            return {
                "customer_info": customer_info,
                "last_order": last_order,
                "order_items": order_items
            }

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
            # self.cursor.execute("BEGIN")

            # Step 1: Get the next available order number for the district
            self.cursor.execute("SELECT d_next_o_id FROM district WHERE d_w_id = %s AND d_id = %s", (w_id, d_id))
            next_order_id = self.cursor.fetchone()[0]

            # Step 2: Get the set of items from the last L orders
            self.cursor.execute("""
                SELECT DISTINCT ol_i_id
                FROM "order-line"
                WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id >= %s AND ol_o_id < %s
                """, (w_id, d_id, next_order_id - num_last_orders, next_order_id))
            item_ids = [row[0] for row in self.cursor.fetchall()]

            if not item_ids:
                print("No items found in the last orders.")
                return 0

            # Step 3: Check stock levels for the items and count how many are below the threshold
            query = 'SELECT COUNT(*) FROM "stock_2-5" WHERE s_w_id = %s AND s_i_id = ANY(%s) AND s_quantity < %s'
            self.cursor.execute(query, (w_id, item_ids, threshold))
            low_stock_count = self.cursor.fetchone()[0]

            # Output the total number of items in S where the stock quantity is below the threshold
            print(f"Number of items below threshold: {low_stock_count}")

            # self.cursor.execute("COMMIT")

            return low_stock_count

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return 0

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
                SELECT d_next_o_id 
                FROM "district_2-5"
                WHERE d_w_id = %s AND d_id = %s
            """, (w_id, d_id))
            next_order_id = self.cursor.fetchone()[0]

            # Step 2: Get the set of last L orders
            self.cursor.execute("""
                SELECT o_id
                FROM "order"
                WHERE o_w_id = %s AND o_d_id = %s
                AND o_id >= %s AND o_id < %s
            """, (w_id, d_id, next_order_id - l, next_order_id))
            last_order_ids = [row[0] for row in self.cursor.fetchall()]

            if not last_order_ids:
                print("No orders found.")
                self.cursor.execute("ROLLBACK")
                return None

            # Step 3: Get the set of all items contained in the last L orders
            self.cursor.execute("""
                SELECT ol_i_id, SUM(ol_quantity) as total_qty, COUNT(DISTINCT ol_o_id) as num_orders
                FROM order_lines
                WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = ANY(%s)
                GROUP BY ol_i_id
            """, (w_id, d_id, last_order_ids))
            item_data = self.cursor.fetchall()

            if not item_data:
                print("No items found in the last orders.")
                self.cursor.execute("ROLLBACK")
                return None

            # Step 4: Get the top 5 most popular items based on total quantity and number of orders
            # Sorting by total_qty, then num_orders, and finally by item ID in case of ties
            item_data_sorted = sorted(item_data, key=lambda x: (-x[1], -x[2], x[0]))[:5]

            # Fetch item details (name and price)
            item_details = []
            for item in item_data_sorted:
                self.cursor.execute("""
                    SELECT i_name, i_price
                    FROM item
                    WHERE i_id = %s
                """, (item[0],))
                item_info = self.cursor.fetchone()
                item_details.append({
                    'i_id': item[0],
                    'i_name': item_info[0],
                    'i_price': item_info[1],
                    'total_qty': item[1],
                    'num_orders': item[2]
                })

            self.cursor.execute("COMMIT")

            # Output the popular items
            print(f"District: (W_ID: {w_id}, D_ID: {d_id}), Last {l} Orders")
            for idx, item in enumerate(item_details):
                print(f"{idx + 1}. Item ID: {item['i_id']}, Name: {item['i_name']}, Price: {item['i_price']}")
                print(f"   Total Quantity: {item['total_qty']}, Number of Orders: {item['num_orders']}")
                print("------------------------------------------------------")

            return item_details

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
            # self.cursor.execute("BEGIN")

            # Step 1: Get the top 10 customers by balance in non-ascending order
            # NOTE: This query is SLOW AF - to be optimized later
            self.cursor.execute("""
                SELECT 
                    C_FIRST, C_MIDDLE, C_LAST, C_BALANCE, 
                    C_W_ID, C_D_ID
                FROM "customer_2-7" AS cust
                JOIN warehouse ON cust.c_w_id = warehouse.w_id 
                JOIN district ON cust.c_d_id = district.d_id 
                ORDER BY C_BALANCE DESC 
                LIMIT 10
            """)
            
            top_customers = self.cursor.fetchall()
            c_w_ids = [row[4] for row in top_customers]
            c_d_ids = [row[5] for row in top_customers]

            warehouse_query = """
                WITH warehouse_ids AS (
                    SELECT unnest(%s::int[]) AS w_id, generate_subscripts(%s::int[], 1) AS ord
                )
                SELECT w.w_name
                FROM warehouse w
                JOIN warehouse_ids wi ON w.w_id = wi.w_id
                ORDER BY wi.ord;
            """
            self.cursor.execute(warehouse_query, (c_w_ids, c_w_ids))
            warehouse_names = [row[0] for row in self.cursor.fetchall()]

            # Step 3: Query for district names similarly
            district_query = """
                WITH district_ids AS (
                    SELECT unnest(%s::int[]) AS d_id, unnest(%s::int[]) AS w_id, generate_subscripts(%s::int[], 1) AS ord
                )
                SELECT d.d_name
                FROM district d
                JOIN district_ids di ON d.d_id = di.d_id AND d.d_w_id = di.w_id
                ORDER BY di.ord;
            """
            self.cursor.execute(district_query, (c_d_ids, c_w_ids, c_w_ids))
            district_names = [row[0] for row in self.cursor.fetchall()]

            # Output the details of each customer
            # for customer in top_customers:
            #     c_first = customer[0]
            #     c_middle = customer[1]
            #     c_last = customer[2]
            #     c_balance = customer[3]
            #     w_name = customer[]
            #     d_name = customer[5]
                
                # print(f"Customer: {c_first} {c_middle} {c_last}")
                # print(f"Outstanding Balance: {c_balance}")
                # print(f"Warehouse Name: {w_name}")
                # print(f"District Name: {d_name}")
                # print("----------------------------------")

            # self.cursor.execute("COMMIT")

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

            # Step 1: Get the state of the given customer
            self.cursor.execute("SELECT c_state_id FROM customer WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s", 
                                (c_w_id, c_d_id, c_id))
            customer_state_id = self.cursor.fetchone()[0]

            # Step 2: Get the last order for the given customer
            self.cursor.execute("""
                SELECT o_id 
                FROM "order" 
                WHERE o_w_id = %s AND o_d_id = %s AND o_c_id = %s 
                ORDER BY o_entry_d DESC LIMIT 1
                """, (c_w_id, c_d_id, c_id))
            customer_last_order_id = self.cursor.fetchone()[0]

            # Step 3: Get the item IDs from the last order of the given customer
            self.cursor.execute("""
                SELECT ol_i_id 
                FROM "order-line"
                WHERE ol_w_id = 1 AND ol_d_id = 1 AND ol_o_id = 1
                """, (c_w_id, c_d_id, customer_last_order_id))
            customer_item_ids = [row[0] for row in self.cursor.fetchall()]

            # Step 4: Find related customers in the same state who have at least two items in common in their last order
            # c_state_id should be c_state as per the schema
            self.cursor.execute("""
                SELECT DISTINCT c2.c_w_id, c2.c_d_id, c2.c_id 
                FROM "customer_2-8" c1
                JOIN "customer_2-8" c2 ON c1.c_state = c2.c_state
                JOIN "order" o1 ON o1.o_w_id = c1.c_w_id AND o1.o_d_id = c1.c_d_id AND o1.o_c_id = c1.c_id
                JOIN "order" o2 ON o2.o_w_id = c2.c_w_id AND o2.o_d_id = c2.c_d_id AND o2.o_c_id = c2.c_id
                JOIN "order-line" ol1 ON ol1.ol_w_id = o1.o_w_id AND ol1.ol_d_id = o1.o_d_id AND ol1.ol_o_id = o1.o_id
                JOIN "order-line" ol2 ON ol2.ol_w_id = o2.o_w_id AND ol2.ol_d_id = o2.o_d_id AND ol2.ol_o_id = o2.o_id
                WHERE c1.c_state = %s AND c1.c_w_id = %s AND c1.c_d_id = %s AND c1.c_id = %s
                AND ol1.ol_i_id = ol2.ol_i_id
                GROUP BY c2.c_w_id, c2.c_d_id, c2.c_id
                HAVING COUNT(ol1.ol_i_id) >= 2
            """, (customer_state_id, c_w_id, c_d_id, c_id))

            related_customers = self.cursor.fetchall()

            # Output the related customers
            for related_customer in related_customers:
                print(f"Related Customer: Warehouse ID: {related_customer[0]}, District ID: {related_customer[1]}, Customer ID: {related_customer[2]}")

            self.cursor.execute("COMMIT")

            return related_customers

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None
