import sys
import time

from transactionsV3_procedure_ideal import Transactions
from metrics import metrics, query_statistics

client_number = sys.argv[1]  # Get client number from command line

# txn = Transactions("project", "cs4224b", 5098)
txn = Transactions()

txn_funcs_dict = {
    "N": (txn.new_order_txn, txn.cast_new_order_type),
    "P": (txn.payment_txn, txn.cast_payment_type),
    "D": (txn.delivery_txn, txn.cast_delivery_type),
    "O": (txn.order_status_txn, txn.cast_order_status_type),
    "S": (txn.stock_level_txn, txn.cast_stock_level_type),
    "I": (txn.popular_item_txn, txn.cast_popular_item_type),
    "T": (txn.top_balance_txn, txn.cast_top_balance_type),
    "R": (txn.related_customer_txn, txn.cast_related_customer_type),
}

total_num_exec_xacts = 0
total_exec_time = 0
latencies = []


def process_transaction(params):
    global total_num_exec_xacts, total_exec_time
    if not params:
        return

    txn_type = params[0].strip()
    txn_func, cast_type = txn_funcs_dict[txn_type]

    if txn_type not in txn_funcs_dict:
        print(f"Warning: Unknown transaction type '{txn_type}'")
        return

    txn_start_time = time.time()

    if txn_type == "N":
        item_numbers, supplier_warehouses, quantities = [], [], []
        cleaned_params = [item.strip() for item in params[1:]]
        variables = cast_type(cleaned_params)
        total_orders = variables[-1]

        for _ in range(total_orders):
            order = next(sys.stdin)
            order_params = order.strip().split(",")
            cleaned_order_params = [int(item.strip()) for item in order_params]

            item_numbers.append(cleaned_order_params[0])
            supplier_warehouses.append(cleaned_order_params[1])
            quantities.append(cleaned_order_params[2])

        variables.extend([item_numbers, supplier_warehouses, quantities])
        result = txn_func(*variables)
        print(f"Processed {txn_type}: {result}")

    elif txn_type == "T":
        result = txn_func()
        print(f"Processed {txn_type}: {result}")

    else:
        cleaned_params = [item.strip() for item in params[1:]]
        variables = cast_type(cleaned_params)
        result = txn_func(*variables)
        print(f"Processed {txn_type}: {result}")

    txn_end_time = time.time()
    latency = txn_end_time - txn_start_time
    latencies.append(latency)
    total_num_exec_xacts += 1
    total_exec_time += latency

for line in sys.stdin:
    # Read and parse transaction from stdin
    process_transaction(line.split(","))

print("Measuring database statistics")
query_statistics.query_statistics(txn.cursor)

print("Measuring performance metrics")
perf_metrics = metrics.performance_metrics(
    total_num_exec_xacts, total_exec_time, latencies
)

print(f"Client {client_number}: writing performance metrics")
metrics.write_metrics_csv(client_number, perf_metrics)


print(f"Total Transactions Executed: {total_num_exec_xacts}")
print(f"Total Execution Time: {total_exec_time:.2f} seconds")
print(f"Average Latency: {sum(latencies) / total_num_exec_xacts:.2f} seconds")

# txn.__close_connection__()
txn.__close_connection__()
