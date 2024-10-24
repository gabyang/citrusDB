import csv
import statistics
import sys
import time

# RESULTSDIR=$HOME/relevant_directory
results_dir = "./metrics" # Insert later

def performance_metrics(total_xacts, total_xact_time, latencies):
    total_xact_time = round(total_xact_time, 2)
    throughput = round(total_xacts / total_xact_time, 2)
    avg_latency = round(statistics.mean(latencies), 2)
    median_latency = round(statistics.median(latencies), 2)
    percentile_95_latency = round(statistics.quantiles(latencies, n=100)[94] * 1000, 2)
    percentile_99_latency = round(statistics.quantiles(latencies, n=100)[98] * 1000, 2)
    
    # output the metrics into stderr
    print(f"Total Transactions: {total_xacts}", file=sys.stderr)
    print(f"Total Time: {total_xact_time}", file=sys.stderr)
    print(f"Throughput: {throughput}", file=sys.stderr)
    print(f"Average Latency: {avg_latency}", file=sys.stderr)
    print(f"Median Latency: {median_latency}", file=sys.stderr)
    print(f"95th Percentile Latency: {percentile_95_latency}", file=sys.stderr)
    print(f"99th Percentile Latency: {percentile_99_latency}", file=sys.stderr)

    return (total_xacts, total_xact_time, throughput, avg_latency, median_latency, percentile_95_latency, percentile_99_latency)

def write_metrics_csv(client_number, metrics):
    headers = ['client_number', 'measurement_a', 'measurement_b', 'measurement_c', 'measurement_d', 'measurement_e', 'measurement_f', 'measurement_g']
    resultPath = f"{results_dir}/performance_metrics.csv"

    with open(resultPath, 'a') as f:
        writer = csv.writer(f)
        total_xact, total_xact_time, throughput, avg_latency, median_latency, percentile_95_latency, percentile_99_latency = metrics

        if f.tell() == 0: # no headers present
            writer.writerow(headers)
        
        writer.writerow([client_number, total_xact, total_xact_time, throughput, avg_latency, median_latency, percentile_95_latency, percentile_99_latency])
        print(f"Client {client_number} metrics written to {resultPath}")




