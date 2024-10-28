import json
import csv
import argparse
from datetime import datetime
from pathlib import Path

def parse_aggregated_iperf3_json(json_data):
    """
    Parses the aggregated iperf3 JSON data to extract relevant metrics, including total packets sent and retransmission rate.

    Parameters:
        json_data (list): Loaded JSON data from the aggregated iperf3 results.

    Returns:
        list of dict: A list of dictionaries containing parsed metrics for each test run.
    """
    results = []

    for test in json_data:
        if "error" in test:
            # Skip tests that have an error
            continue

        start_time = test["start"]["timestamp"]["time"]
        local_host = test["start"]["connected"][0]["local_host"]
        remote_host = test["start"]["connected"][0]["remote_host"]
        
        # Fetch tcp_mss_default (MSS size for packet calculation)
        tcp_mss_default = test["start"].get("tcp_mss_default", None)
        if not tcp_mss_default:
            print(f"Warning: tcp_mss_default missing in test starting at {start_time}")
            continue

        # End summary data
        end_summary = test["end"]["streams"][0]["sender"]
        total_bytes_sent = end_summary["bytes"]
        throughput_bps = end_summary["bits_per_second"]
        retransmits = end_summary.get("retransmits", 0)
        max_rtt = end_summary.get("max_rtt", None)  # in microseconds
        min_rtt = end_summary.get("min_rtt", None)
        mean_rtt = end_summary.get("mean_rtt", None)

        # Calculate total packets sent and retransmission rate
        total_packets_sent = total_bytes_sent / tcp_mss_default
        retransmission_rate = (retransmits / total_packets_sent) * 100 if total_packets_sent > 0 else None

        # Append parsed results with specified column order
        results.append({
            "local_host": local_host,
            "remote_host": remote_host,
            "start_time": start_time,
            "throughput_bps": throughput_bps,
            "max_rtt_ms": max_rtt / 1000 if max_rtt else None,
            "min_rtt_ms": min_rtt / 1000 if min_rtt else None,
            "mean_rtt_ms": mean_rtt / 1000 if mean_rtt else None,
            "retransmission_rate (%)": retransmission_rate,
            "retransmits": retransmits,
            "total_packets_sent": total_packets_sent
        })

    return results

def write_csv(data, output_file):
    """
    Writes parsed metrics data to a CSV file.

    Parameters:
        data (list of dict): Parsed iperf3 metrics data.
        output_file (str): Path to the output CSV file.
    """
    if not data:
        print("No data to write.")
        return

    # Define CSV headers based on the specified column order
    headers = [
        "local_host",
        "remote_host",
        "start_time",
        "throughput_bps",
        "max_rtt_ms",
        "min_rtt_ms",
        "mean_rtt_ms",
        "retransmission_rate (%)",
        "retransmits",
        "total_packets_sent"
    ]

    with open(output_file, mode="w", newline='') as file:
        writer = csv.DictWriter(file, fieldnames=headers)
        writer.writeheader()
        writer.writerows(data)
    print(f"Data successfully written to {output_file}")

def main():
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Parse aggregated iperf3 JSON results and export metrics to CSV.")
    parser.add_argument("json_file", type=str, help="Path to the aggregated iperf3 JSON result file.")
    parser.add_argument("output_file", type=str, help="Path to the output CSV file.")

    args = parser.parse_args()

    # Load JSON data
    with open(args.json_file, "r") as file:
        json_data = json.load(file)

    # Parse JSON data for metrics
    parsed_data = parse_aggregated_iperf3_json(json_data)

    # Sort data by local_host ascending, remote_host ascending, start_time descending
    parsed_data.sort(
        key=lambda x: (
            x["local_host"],
            x["remote_host"],
            -datetime.strptime(x["start_time"], "%a, %d %b %Y %H:%M:%S %Z").timestamp()
        )
    )

    # Write parsed data to CSV
    write_csv(parsed_data, args.output_file)

if __name__ == "__main__":
    main()
