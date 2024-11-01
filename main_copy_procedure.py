import sys
import time

from transactionsV3_procedure import Transactions

txn = Transactions()

txn_funcs_dict = {
    "N": (txn.new_order_txn, txn.cast_new_order_type),
    "P": (txn.payment_txn, txn.cast_payment_type),
    "D": (txn.delivery_txn, txn.cast_delivery_type),
    "O": (txn.order_status_txn,txn.cast_order_status_type),
    "S": (txn.stock_level_txn, txn.cast_stock_level_type),
    "I": (txn.popular_item_txn, txn.cast_popular_item_type),
    "T": (txn.top_balance_txn, txn.cast_top_balance_type),
    "R": (txn.related_customer_txn, txn.cast_related_customer_type)
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
        split_params = params.split(",")
        customer_id = int(split_params[1])
        warehouse_id = int(split_params[2])
        district_id = int(split_params[3])
        num_items = int(split_params[4])
        item_id_array= []
        supply_warehouse_id = []
        qty = [] 
        for x in sys.stdin:
            try:
                int(x.split(",")[0]) 
                input_array = x.split(",")
                order_line_item_id = int(input_array[0])
                order_line_supply_warehouse_id = int(input_array[1])
                qty_item = int(input_array[2])
                item_id_array.append(order_line_item_id)
                supply_warehouse_id.append(order_line_supply_warehouse_id)
                qty.append(qty_item)
            except ValueError:
                print('break!')
                break
        result = txn_func(customer_id,warehouse_id, district_id,num_items,item_id_array,supply_warehouse_id,qty)
        print(f"Processed {txn_type}: {result}")
    elif txn_type == "D": 
        split_params = params.split(",")
        warehouse_id = int(split_params[1])
        carrier_id = int(split_params[2])
        print(split_params)
        result = txn_func(warehouse_id,carrier_id)
        print(f"Processed {txn_type}: {result}")
    elif txn_type == 'T':
        result = txn_func()
        print(f"Processed {txn_type}: {result}")
    elif txn_type == 'S': 
        params_array = params.split(',')[1:]
        w_id =int(params_array[0])
        d_id= int(params_array[1])
        threshold= int(params_array[2])
        num_last_orders=int(params_array[3])
        result = txn_func(w_id, d_id, threshold, num_last_orders)
        print(f"Processed {txn_type}: {result}")
    elif txn_type == 'I':
        params_array = params.split(',')[1:]
        warehouse_id = int(params_array[0])
        district_id = int(params_array[1])
        num_of_last_orders_to_examine = int(params_array[2])
        result = txn_func(warehouse_id, district_id, num_of_last_orders_to_examine)
        print(f"Processed {txn_type}: {result}")
    elif txn_type == 'P':
        values = params.split(',')
        print(values)
        c_w_id = int(values[1])  
        c_d_id = int(values[2])  
        c_id = int(values[3])   
        payment = float(values[4])  
        result = txn_func(c_w_id, c_d_id, c_id, payment)
        print(f"Processed {txn_type}: {result}")       
    elif txn_type == 'O':
        values = params.split(',')
        c_w_id = int(values[1])  
        c_d_id = int(values[2])  
        c_id = int(values[3])   
        result = txn_func(c_w_id, c_d_id, c_id)
        print(f"Processed {txn_type}: {result}")
    elif txn_type == 'R':
        values = params.split(',')
        c_w_id = int(values[1])  
        c_d_id = int(values[2])  
        c_id = int(values[3])   
        result = txn_func(c_w_id, c_d_id, c_id)
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
    values = line.split(',')
    # Read and parse transaction from stdin
    if values[0] in {'N', 'P', 'D', 'O', 'S', 'I', 'T', 'R'}:
        process_transaction(line)
    
    # try:
    #     process_transaction()
    # except Exception as e:
    #     print(f"Error processing transaction: {e}", file=sys.stderr)

# filename = "test1.txt"

# if filename:
#   try:
#     with open(filename, 'r') as file:
#       for line in file:
#         process_transaction(line.split(','))
#   except FileNotFoundError:
#     print(f"Error: File '{filename}' not found.")
#   except Exception as e:
#     print(f"An error occurred: {str(e)}")
# else:
#   print("Please provide a filename as an argument.")
#   sys.exit(1)

print(f"Total Transactions Executed: {total_num_exec_xacts}")
print(f"Total Execution Time: {total_exec_time:.2f} seconds")
print(f"Average Latency: {sum(latencies) / total_num_exec_xacts:.2f} seconds")

# txn.__close_connection__()
txn.__close_connection__()