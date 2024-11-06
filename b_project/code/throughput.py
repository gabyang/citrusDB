import csv

result_path = "throughput.csv"


def throughput(results_dir):
    result_path = f"{results_dir}/throughput.csv"
    performance_metrics_path = f"{results_dir}/clients.csv"
    with open(result_path, "w") as f:
        # Open the clients.csv file and read in the 3rd column into a list
        # Get the minimum, average and maximum values of the list
        # Write the values to the throughput.csv file
        with open(performance_metrics_path, "r") as c:
            reader = csv.reader(c)
            next(reader)
            values = [float(row[3]) for row in reader]
        min_val = round(min(values), 2)
        avg_val = round(sum(values) / len(values), 2)
        max_val = round(max(values), 2)
        writer = csv.writer(f)
        writer.writerow(["min_throughput", "max_throughput", "avg_throughput"])
        writer.writerow([min_val, max_val, avg_val])


if __name__ == "__main__":
    throughput()
