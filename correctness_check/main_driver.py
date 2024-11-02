import sys
import time

from transactions_ideal import *
xact = Transactions()

# mapping for transaction functions
txn_funcs_dict = {
    "N": (xact.new_order_txn, xact.cast_new_order_dtypes),
    "P": (xact.payment_txn, xact.cast_payment_dtypes),
    "D": (xact.delivery_txn, xact.cast_delivery_dtypes),
    "O": (xact.order_status_txn, xact.cast_order_status_dtypes),
    "S": (xact.stock_level_txn, xact.cast_stock_level_dtypes),
    "I": (xact.popular_item_txn, xact.cast_popular_item_dtypes),
    "T": (xact.top_balance_txn, xact.cast_top_balance_dtypes),
    "R": (xact.related_customer_txn, xact.cast_related_customer_dtypes)
}

total_num_exec_xacts = 0
total_exec_time = 0
latencies = []

with open("test1.txt", "r") as file:
    for line in file:
        # split csv line params
        params = line.strip().split(",")

        # get correct transaction function and parameter data type conversion function from dict
        txn_type = params[0]
        txn_func, txn_dtypes_func = txn_funcs_dict[txn_type]

        # convert parameters to correct data types
        converted_params = txn_dtypes_func(params[1:])

        # handle new order Xact N
        if txn_type == "N":
            item_number, supplier_warehouse, quantity = [], [], []
            num_items = converted_params[-1]

            for _ in range(num_items):
                # read the next item line from the file
                item = next(file)
                item_params = item.strip().split(",")
                item_number.append(int(item_params[0]))
                supplier_warehouse.append(int(item_params[1]))
                quantity.append(int(item_params[2]))

            converted_params.extend([item_number, supplier_warehouse, quantity])

        # execute transaction function with converted params
        txn_start_time = time.time()
        if converted_params:
            txn_func(*converted_params)
        else:
            txn_func()
        txn_end_time = time.time()

        # record statistics
        latency = txn_end_time - txn_start_time
        latencies.append(latency)
        total_num_exec_xacts += 1
        total_exec_time += latency

print(f"Total Transactions Executed: {total_num_exec_xacts}")
print(f"Total Execution Time: {total_exec_time:.2f} seconds")


# close CITUS cluster connections
xact.close()