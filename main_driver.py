import sys
import time

def handle_new_order_transaction(params: list):
    print("handle_new_order_transaction")
    print(params)
    print()
    return

def handle_payment_transaction(params: list):
    print("handle_payment_transaction")
    print(params)
    print()
    return

def handle_delivery_transaction(params: list):
    print("handle_delivery_transaction")
    print(params)
    print()
    return

def handle_order_status_transaction(params: list):
    print("handle_order_status_transaction")
    print(params)
    print()
    return

def handle_stock_level_transaction(params: list):
    print("handle_stock_level_transaction")
    print(params)
    print()
    return

def handle_popular_item_transaction(params: list):
    print("handle_popular_item_transaction")
    print(params)
    print()
    return

def handle_top_balance_transaction(params: list):
    print("handle_top_balance_transaction")
    print(params)
    print()
    return

def handle_related_customer_transaction(params: list):
    print("handle_related_customer_transaction")
    print(params)
    print()
    return

transaction_funcs = {
    "N": handle_new_order_transaction,
    "P": handle_payment_transaction,
    "D": handle_delivery_transaction,
    "O": handle_order_status_transaction,
    "S": handle_stock_level_transaction,
    "I": handle_popular_item_transaction,
    "T": handle_top_balance_transaction,
    "R": handle_related_customer_transaction,
}

def process_inputs(content):
    outputs = []

    lines = content.strip().split("\n")
    line_number = 0
    number_of_lines = len(lines)
    while line_number < number_of_lines:
        line = lines[line_number]
        if line.startswith("N"):
            N = int(line.split(",")[-1]) + 1
            outputs.append((line[0], lines[line_number:line_number+N]))
            line_number += N
        else:
            outputs.append((line[0], line))
            line_number += 1
    return outputs


def main():
    content = sys.stdin.read()

    transaction_params = process_inputs(content)
    for type_, params in transaction_params:
        transaction_funcs[type_](params)

if __name__ == "__main__":
    main()