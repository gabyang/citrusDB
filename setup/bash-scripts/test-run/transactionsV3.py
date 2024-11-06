import os
from datetime import datetime, timezone

import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values

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
                host="localhost", database=database, user=username, port=port, password=password
            )
            self.conn.autocommit = True
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
        try:
            self.cursor.execute("BEGIN")
            orderline_inputs = []
            for i in range(num_items):
                orderline_inputs.append((item_ids[i], supplier_warehouses[i], quantities[i]))

            # Check if all items are from the same warehouse
            is_all_local = int(all(warehouse_id == w_id for warehouse_id in supplier_warehouses))

            # step 1 and step 2
            next_order_id = None
            self.cursor.execute(
                """
                UPDATE "district_2-5"
                SET D_NEXT_O_ID = D_NEXT_O_ID + 1
                WHERE D_ID = %s AND D_W_ID = %s
                RETURNING D_NEXT_O_ID
            """,
                (d_id, w_id),
            )
            next_order_id = self.cursor.fetchone()[0]

            # step 3
            entry_time = datetime.now(timezone.utc)
            self.cursor.execute(
                'INSERT INTO "order"(O_ID, O_D_ID, O_W_ID, O_C_ID, O_ENTRY_D, O_CARRIER_ID, O_OL_CNT, O_ALL_LOCAL) VALUES (%s, %s, %s, %s, %s, NULL, %s, %s)',
                (next_order_id, d_id, w_id, c_id, entry_time, num_items, is_all_local),
            )

            # retrieve item prices
            item_query = """
                WITH item_ids AS (
                    SELECT unnest(%s::int[]) AS I_ID, generate_subscripts(%s::int[], 1) AS ord
                )
                SELECT i.I_PRICE, i.I_NAME
                FROM item i
                JOIN item_ids ii ON i.I_ID = ii.I_ID
                ORDER BY ii.ord;
            """
            self.cursor.execute(item_query, (item_ids, item_ids))
            result = self.cursor.fetchall()
            item_prices = [round(float(x[0]), 2) for x in result]
            item_names = [x[1] for x in result]

            # retrieve distance information
            stock_dist_id = f"S_DIST_0{d_id}" if d_id < 10 else f"S_DIST_{d_id}"
            stock_query = f"""
                WITH item_ids AS (
                    SELECT unnest(%s::int[]) AS S_I_ID, generate_subscripts(%s::int[], 1) AS ord
                )
                SELECT s.{stock_dist_id}
                FROM stock s
                JOIN item_ids ii ON s.S_I_ID = ii.S_I_ID
                WHERE s.S_W_ID = {w_id}
                ORDER BY ii.ord;
            """

            self.cursor.execute(stock_query, (item_ids, item_ids))
            result = self.cursor.fetchall()
            ol_dist = [x[0] for x in result]

            # intialise variables
            stock_items = [
                (item_id, supplier_warehouses[idx]) for idx, item_id in enumerate(item_ids)
            ]

            stock_data_query = """
                SELECT s.S_YTD, s.S_ORDER_CNT, s.S_REMOTE_CNT
                FROM unnest(%s::int[], %s::int[]) AS input(S_I_ID, S_W_ID)
                JOIN stock s ON s.S_I_ID = input.S_I_ID AND s.S_W_ID = input.S_W_ID
                ORDER BY array_position(%s::int[], input.S_I_ID)
            """
            self.cursor.execute(stock_data_query, (item_ids, supplier_warehouses, item_ids))
            stock_data = self.cursor.fetchall()

            stock_quantity_query = """
                SELECT s.S_QUANTITY
                FROM unnest(%s::int[], %s::int[]) AS input(S_I_ID, S_W_ID)
                JOIN "stock_2-5" s ON s.S_I_ID = input.S_I_ID AND s.S_W_ID = input.S_W_ID
                ORDER BY array_position(%s::int[], input.S_I_ID)
            """
            self.cursor.execute(stock_quantity_query, (item_ids, supplier_warehouses, item_ids))
            stock_quantities = self.cursor.fetchall()

            total_amount = 0
            orderline_outputs = []
            batch_stock_update_data = []
            batch_stock_2_5_update_data = []
            batch_ol_update_data = []

            for idx, ol in enumerate(orderline_inputs):
                ol_item_id = ol[0]
                ol_warehouse = ol[1]
                ol_quantity = ol[2]

                item_price = item_prices[idx]
                item_name = item_names[idx]
                ytd, order_count, remote_count = stock_data[idx]
                stock_quantity = stock_quantities[idx][0]

                next_quantity = stock_quantity + ol_quantity
                next_quantity = next_quantity + 100 if next_quantity < 10 else next_quantity
                next_ytd = ytd + ol_quantity
                next_order_count = order_count + 1
                next_remote_count = remote_count + (1 if ol_warehouse != w_id else 0)

                batch_stock_update_data.append(
                    (next_ytd, next_order_count, next_remote_count, ol_warehouse, ol_item_id)
                )
                batch_stock_2_5_update_data.append((next_quantity, ol_warehouse, ol_item_id))

                item_amount = item_prices[idx] * ol_quantity
                total_amount += item_amount
                orderline_outputs.append(
                    [
                        ol_item_id,
                        item_names[idx],
                        ol_warehouse,
                        ol_quantity,
                        item_amount,
                        next_quantity,
                    ]
                )

                batch_ol_update_data.append(
                    (
                        w_id,
                        d_id,
                        next_order_id,
                        idx + 1,
                        ol_item_id,
                        item_prices[idx],
                        ol_warehouse,
                        ol_quantity,
                        ol_dist[idx],
                        None,
                    )
                )

            execute_values(
                self.cursor,
                """
                UPDATE stock
                SET 
                    S_YTD = data.S_YTD,
                    S_ORDER_CNT = data.S_ORDER_CNT,
                    S_REMOTE_CNT = data.S_REMOTE_CNT
                FROM (VALUES %s) AS data(S_YTD, S_ORDER_CNT, S_REMOTE_CNT, S_W_ID, S_I_ID)
                WHERE stock.S_W_ID = data.S_W_ID AND stock.S_I_ID = data.S_I_ID;
            """,
                batch_stock_update_data,
            )

            execute_values(
                self.cursor,
                """
                UPDATE "stock_2-5"
                SET S_QUANTITY = data.S_QUANTITY
                FROM (VALUES %s) AS data(S_QUANTITY, S_W_ID, S_I_ID)
                WHERE "stock_2-5".S_W_ID = data.S_W_ID AND "stock_2-5".S_I_ID = data.S_I_ID;
            """,
                batch_stock_2_5_update_data,
            )

            execute_values(
                self.cursor,
                """
                INSERT INTO "order-line" (
                    ol_w_id, ol_d_id, ol_o_id, ol_number, ol_i_id,
                    ol_amount, ol_supply_w_id, ol_quantity, ol_dist_info, ol_delivery_d
                )
                VALUES %s
            """,
                batch_ol_update_data,
            )

            self.cursor.execute(
                "SELECT d_tax FROM district WHERE D_ID = %s AND D_W_ID = %s", (d_id, w_id)
            )
            d_tax = round(float(self.cursor.fetchone()[0]), 2)

            self.cursor.execute("SELECT w_tax FROM warehouse WHERE W_ID = %s", (w_id,))
            w_tax = round(float(self.cursor.fetchone()[0]), 4)

            self.cursor.execute(
                "SELECT c_discount, c_credit FROM customer WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s",
                (w_id, d_id, c_id),
            )
            c_discount, c_credit = self.cursor.fetchone()
            self.cursor.execute(
                'SELECT c_last FROM "customer_2-7" WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s',
                (w_id, d_id, c_id),
            )
            c_last = self.cursor.fetchone()[0]

            # step 6
            total_amount = total_amount * (1 + d_tax + w_tax) * (1 - float(c_discount))

            output = []
            # Append the customer, tax rate, and order information
            output.extend([w_id, d_id, c_id, c_last, c_credit, c_discount])
            output.extend([w_tax, d_tax])
            output.extend([next_order_id, entry_time])
            output.extend([num_items, f"{total_amount:.2f}"])

            # Append the order line details for each item
            for idx, ol in enumerate(orderline_outputs):
                output.extend([ol[0], ol[1], ol[2], ol[3], f"{ol[4]:.2f}", ol[5]])

            # Join the array and output to the file
            self.cursor.execute("COMMIT")
            output = str(output)
            print(output)

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

            self.cursor.execute(
                "UPDATE warehouse SET W_YTD = W_YTD + %s WHERE W_ID = %s", (payment, c_w_id)
            )

            # Step 2: Update the district by incrementing D_YTD by PAYMENT
            self.cursor.execute(
                "UPDATE district SET D_YTD = D_YTD + %s WHERE D_W_ID = %s AND D_ID = %s",
                (payment, c_w_id, c_d_id),
            )

            # Step 3
            self.cursor.execute(
                """
                UPDATE "customer_2-7"
                SET C_BALANCE = C_BALANCE - %s
                WHERE C_W_ID = %s
                AND C_D_ID = %s
                AND C_ID = %s;
                """,
                (payment, c_w_id, c_d_id, c_id),
            )

            self.cursor.execute(
                """
                UPDATE customer
                SET 
                    C_YTD_PAYMENT = C_YTD_PAYMENT + %s,
                    C_PAYMENT_CNT = C_PAYMENT_CNT + 1
                WHERE C_W_ID = %s
                AND C_D_ID = %s
                AND C_ID = %s;
                """,
                (payment, c_w_id, c_d_id, c_id),
            )

            # Step 4: Fetch the customer details including name, address, phone, credit info, balance, etc.
            self.cursor.execute(
                """
                SELECT C_W_ID, C_D_ID, C_ID, 
                    C_STREET_1, C_STREET_2, C_CITY, C_ZIP,
                    C_PHONE, C_SINCE, C_CREDIT, C_CREDIT_LIM, 
                    C_DISCOUNT
                FROM customer
                WHERE C_W_ID = %s AND C_D_ID = %s AND C_ID = %s;
                """,
                (c_w_id, c_d_id, c_id),
            )
            customer_info = self.cursor.fetchone()

            self.cursor.execute(
                """
                SELECT C_STATE
                FROM "customer_2-8"
                WHERE C_W_ID = %s AND C_D_ID = %s AND C_ID = %s;
                """,
                (c_w_id, c_d_id, c_id),
            )
            customer_state = self.cursor.fetchone()

            self.cursor.execute(
                """
                SELECT C_FIRST, C_MIDDLE, C_LAST, C_BALANCE
                FROM "customer_2-7"
                WHERE C_W_ID = %s AND C_D_ID = %s AND C_ID = %s;
                """,
                (c_w_id, c_d_id, c_id),
            )
            customer_name_bal = self.cursor.fetchone()

            # Step 5: Fetch the warehouse address
            self.cursor.execute(
                """
                SELECT W_STREET_1, W_STREET_2, W_CITY, W_STATE, W_ZIP
                FROM warehouse
                WHERE W_ID = %s;
                """,
                (c_w_id,),
            )
            warehouse_addr = self.cursor.fetchone()

            # Step 6: Fetch the district address
            self.cursor.execute(
                """
                SELECT D_STREET_1, D_STREET_2, D_CITY, D_STATE, D_ZIP
                FROM district
                WHERE D_W_ID = %s AND D_ID = %s;
                """,
                (c_w_id, c_d_id),
            )
            district_addr = self.cursor.fetchone()

            output = [
                customer_info[0],
                customer_info[1],
                customer_info[2],
                customer_name_bal[0],
                customer_name_bal[1],
                customer_name_bal[2],
                customer_info[3],
                customer_info[4],
                customer_info[5],
                customer_state[0],
                customer_info[6],
                customer_info[7],
                customer_info[8],
                customer_info[9],
                customer_info[10],
                customer_info[11],
                f"{customer_name_bal[3]:.2f}",
            ]
            output.extend(
                [
                    warehouse_addr[0],
                    warehouse_addr[1],
                    warehouse_addr[2],
                    warehouse_addr[3],
                    warehouse_addr[4],
                    district_addr[0],
                    district_addr[1],
                    district_addr[2],
                    district_addr[3],
                    district_addr[4],
                ]
            )
            output.extend([f"{payment:.2f}"])

            self.cursor.execute("COMMIT")
            output = str(output)
            print(output)
            return None

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

            # Process steps for district numbers 1 through 10
            for district_no in range(1, 11):

                # Step 1a: Find the smallest order number O_ID for the district with O_CARRIER_ID = null
                self.cursor.execute(
                    """
                    SELECT MIN(o_id) 
                    FROM "order" 
                    WHERE o_w_id = %s AND o_d_id = %s AND o_carrier_id IS NULL
                    """,
                    (w_id, district_no),
                )
                next_order_id = self.cursor.fetchone()

                if next_order_id is None or next_order_id[0] is None:
                    # If no valid order is found, continue to the next district
                    continue

                next_order_id = next_order_id[0]

                # Step 1b: Find the customer who placed the order
                self.cursor.execute(
                    """
                    SELECT o_c_id 
                    FROM "order" 
                    WHERE o_w_id = %s AND o_d_id = %s AND o_id = %s
                    """,
                    (w_id, district_no, next_order_id),
                )
                customer_id = self.cursor.fetchone()[0]

                # Step 1b: Update the order by setting O_CARRIER_ID
                self.cursor.execute(
                    """
                    UPDATE "order" 
                    SET o_carrier_id = %s 
                    WHERE o_w_id = %s AND o_d_id = %s AND o_id = %s
                    """,
                    (carrier_id, w_id, district_no, next_order_id),
                )

                # Step 1c: Update all the order lines for this order by setting OL_DELIVERY_D to the current date and time
                delivery_time = datetime.now(timezone.utc)
                self.cursor.execute(
                    """
                    UPDATE "order-line" 
                    SET ol_delivery_d = %s 
                    WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = %s
                    """,
                    (delivery_time, w_id, district_no, next_order_id),
                )

                # Step 1d: Calculate the total amount from all order lines for this order
                self.cursor.execute(
                    """
                    SELECT SUM(ol_amount) 
                    FROM "order-line" 
                    WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = %s
                    """,
                    (w_id, district_no, next_order_id),
                )
                total_amount = self.cursor.fetchone()[0]

                # Step 1d: Update the customer balance and increment the delivery count
                self.cursor.execute(
                    """
                    UPDATE "customer_2-7"
                    SET c_balance = c_balance + %s
                    WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
                    """,
                    (total_amount, w_id, district_no, customer_id),
                )

                self.cursor.execute(
                    """
                    UPDATE customer
                    SET c_delivery_cnt = c_delivery_cnt + 1 
                    WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
                    """,
                    (w_id, district_no, customer_id),
                )

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

            self.cursor.execute(
                """
                SELECT c_first, c_middle, c_last, c_balance
                FROM "customer_2-7"
                WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
            """,
                (c_w_id, c_d_id, c_id),
            )
            customer_info = self.cursor.fetchone()

            if not customer_info:
                print(f"Customer with ID ({c_w_id}, {c_d_id}, {c_id}) not found.")
                self.cursor.execute("ROLLBACK")
                return None

            # Step 2: Get the last order of the customer
            self.cursor.execute(
                """
                SELECT o_id, o_entry_d, o_carrier_id
                FROM "order"
                WHERE o_w_id = %s AND o_d_id = %s AND o_c_id = %s
                ORDER BY o_entry_d DESC LIMIT 1
            """,
                (c_w_id, c_d_id, c_id),
            )
            last_order = self.cursor.fetchone()

            if not last_order:
                print("No orders found for this customer.")
                self.cursor.execute("ROLLBACK")
                return None

            # Step 3: Get the items in the customer's last order
            self.cursor.execute(
                """
                SELECT ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_delivery_d
                FROM "order-line"
                WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = %s
            """,
                (c_w_id, c_d_id, last_order[0]),
            )
            order_items = self.cursor.fetchall()

            output = [
                customer_info[0],
                customer_info[1],
                customer_info[2],
                f"{customer_info[3]:.2f}",
                last_order[0],
                last_order[1],
                last_order[2],
            ]

            for item in order_items:
                output.extend([item[0], item[1], item[2], f"{item[3]:.2f}", item[4]])

            self.cursor.execute("COMMIT")
            output = str(output)
            print(output)
            return None

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

            # Step 1: Get the next available order number for the district
            self.cursor.execute(
                'SELECT d_next_o_id FROM "district_2-5" WHERE d_w_id = %s AND d_id = %s',
                (w_id, d_id),
            )
            next_order_id = self.cursor.fetchone()[0]

            # Step 2: Get the set of items from the last L orders
            self.cursor.execute(
                """
                SELECT DISTINCT ol_i_id
                FROM "order-line"
                WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id >= %s AND ol_o_id < %s
                """,
                (w_id, d_id, next_order_id - num_last_orders, next_order_id),
            )
            item_ids = [row[0] for row in self.cursor.fetchall()]

            if not item_ids:
                print("No items found in the last orders.")
                return None

            # Step 3: Check stock levels for the items and count how many are below the threshold
            query = 'SELECT COUNT(*) FROM "stock_2-5" WHERE s_w_id = %s AND s_i_id = ANY(%s) AND s_quantity < %s'
            self.cursor.execute(query, (w_id, item_ids, threshold))
            low_stock_count = self.cursor.fetchone()[0]

            self.cursor.execute("COMMIT")
            output = [low_stock_count]
            output = str(output)
            print(output)

            return None

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
            self.cursor.execute(
                """
                SELECT d_next_o_id 
                FROM "district_2-5" 
                WHERE d_w_id = %s AND d_id = %s
            """,
                (w_id, d_id),
            )
            next_order_id = self.cursor.fetchone()[0]

            # Step 2: Get the set of last L orders
            self.cursor.execute(
                """
                SELECT o_id
                FROM "order"
                WHERE o_w_id = %s AND o_d_id = %s
                AND o_id >= %s AND o_id < %s
            """,
                (w_id, d_id, next_order_id - l, next_order_id),
            )
            last_order_ids = [row[0] for row in self.cursor.fetchall()]

            if not last_order_ids:
                print("No orders found.")
                self.cursor.execute("ROLLBACK")
                return None

            # Step 3: Get the set of all items contained in the last L orders
            self.cursor.execute(
                """
                SELECT ol_i_id, SUM(ol_quantity) as total_qty, COUNT(DISTINCT ol_o_id) as num_orders
                FROM "order-line"
                WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = ANY(%s::int[])
                GROUP BY ol_i_id
            """,
                (w_id, d_id, last_order_ids),
            )
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
                self.cursor.execute(
                    """
                    SELECT i_name, i_price
                    FROM item
                    WHERE i_id = %s
                """,
                    (item[0],),
                )
                item_info = self.cursor.fetchone()
                item_details.append(
                    {
                        "i_id": item[0],
                        "i_name": item_info[0],
                        "i_price": item_info[1],
                        "total_qty": item[1],
                        "num_orders": item[2],
                    }
                )

            # Output the popular items
            output = [w_id, d_id, l]

            for item in item_details:
                output.extend(
                    [
                        item["i_id"],
                        item["i_name"],
                        f"{item['i_price']:.2f}",
                        item["total_qty"],
                        item["num_orders"],
                    ]
                )

            self.cursor.execute("COMMIT")
            output = str(output)
            print(output)
            return None

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

            # Step 1: Get the top 10 customers by balance in non-ascending order
            self.cursor.execute(
                """
                SELECT 
                    C_FIRST, C_MIDDLE, C_LAST, C_BALANCE, 
                    C_W_ID, C_D_ID
                FROM "customer_2-7"
                ORDER BY C_BALANCE DESC 
                LIMIT 10
            """
            )

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

            # Step 4: Output the details of each top customer
            output = []
            for i, customer in enumerate(top_customers):
                output.extend(
                    [
                        customer[0],  # c_first
                        customer[1],  # c_middle
                        customer[2],  # c_last
                        f"{customer[3]:.2f}",  # c_balance
                        warehouse_names[i],
                        district_names[i],
                    ]
                )

            self.cursor.execute("COMMIT")
            output = str(output)
            print(output)

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
            self.cursor.execute(
                """
                SELECT c_state 
                FROM "customer_2-8" 
                WHERE c_w_id = %s AND c_d_id = %s AND c_id = %s
            """,
                (c_w_id, c_d_id, c_id),
            )
            customer_state = self.cursor.fetchone()[0]

            # Step 2: Get the last order ID and item IDs for the given customer
            self.cursor.execute(
                """
                SELECT o_id 
                FROM "order" 
                WHERE o_w_id = %s AND o_d_id = %s AND o_c_id = %s 
                ORDER BY o_entry_d DESC LIMIT 1
            """,
                (c_w_id, c_d_id, c_id),
            )
            customer_last_order_id = self.cursor.fetchone()[0]

            self.cursor.execute(
                """
                SELECT DISTINCT ol_i_id 
                FROM "order-line"
                WHERE ol_w_id = %s AND ol_d_id = %s AND ol_o_id = %s
            """,
                (c_w_id, c_d_id, customer_last_order_id),
            )
            customer_item_ids = [row[0] for row in self.cursor.fetchall()]

            item_ids_tuple = tuple(customer_item_ids)
            if not item_ids_tuple:
                # No items in the last order, so no related customers
                print("No items in the customer's last order.")
                return None

            # Step 3: Find related customers
            self.cursor.execute(
                """
            WITH c2_customers AS (
                SELECT c_w_id, c_d_id, c_id
                FROM "customer_2-8"
                WHERE c_state = %s
                AND NOT (c_w_id = %s AND c_d_id = %s AND c_id = %s)
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
                WHERE ol.ol_i_id = ANY(%s)
            )
            SELECT c_w_id, c_d_id, c_id
            FROM (
                SELECT c2_items.c_w_id, c2_items.c_d_id, c2_items.c_id, COUNT(DISTINCT c2_items.ol_i_id) AS common_items
                FROM c2_items
                GROUP BY c2_items.c_w_id, c2_items.c_d_id, c2_items.c_id
            ) sub
            WHERE sub.common_items >= 2
            ORDER BY c_w_id, c_d_id, c_id
        """,
                (customer_state, c_w_id, c_d_id, c_id, customer_item_ids),
            )

            related_customers = self.cursor.fetchall()

            # Output the related customers
            output = [
                c_w_id,
                c_d_id,
                c_id,
            ]

            for related_customer in related_customers:
                output.extend(
                    [
                        related_customer[0],  # Related Customer C_W_ID
                        related_customer[1],  # Related Customer C_D_ID
                        related_customer[2],  # Related Customer C_ID
                    ]
                )

            self.cursor.execute("COMMIT")
            output = str(output)
            print(output)
            return None

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"An error occurred: {error}")
            self.cursor.execute("ROLLBACK")
            return None
