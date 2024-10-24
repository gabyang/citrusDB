import csv
import time
results_dir = "./metrics" # Insert later

def query_statistics(cursor):
    measurements = [
        "SELECT SUM(W_YTD) FROM Warehouse",
        "SELECT SUM(D_YTD), SUM(D_NEXT_O_ID) FROM District",
        "SELECT SUM(C_BALANCE), SUM(C_YTD_PAYMENT), SUM(C_PAYMENT_CNT), SUM(C_DELIVERY_CNT) from Customer",
        "SELECT MAX(O_ID), SUM(O_OL_CNT) FROM \"order\"",
        "SELECT SUM(OL_AMOUNT), SUM(OL_QUANTITY) FROM \"order-line\"",
        "SELECT SUM(S_QUANTITY), SUM(S_YTD), SUM(S_ORDER_CNT), SUM(S_REMOTE_CNT) FROM Stock"
    ]
    resultPath = f"{results_dir}/database_state.csv"
    print(resultPath)

    with open(resultPath, "w") as f:
        print(f"Writing Database State statistics to {resultPath}")
        index = 1
        for measurementQuery in measurements:
            start = time.time()
            cursor.execute(measurementQuery)
            values = cursor.fetchall()
            end = time.time()
            time_taken = end - start
            print(f"Query {index}: {measurementQuery} took {time_taken} seconds")
            index += 1
            for row in values:
                for field in row:
                    f.write(str(field) + "\n")

