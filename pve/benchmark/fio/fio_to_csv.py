import json
import csv
import argparse
from datetime import datetime
from pathlib import Path

def parse_aggregated_fio_json(json_data):
    """
    Parses the aggregated fio JSON data to extract relevant metrics.

    Parameters:
        json_data (list): Loaded JSON data from the aggregated fio results.

    Returns:
        list of dict: A list of dictionaries containing parsed metrics for each test run.
    """
    results = []

    for test_entry in json_data:
        # Get the filename, if available
        filename = test_entry.get("filename", "unknown")

        # Attempt to extract host and storage name from filename
        # Expected filename format: fio_<host>_<storage>_<timestamp>.json
        filename_stem = Path(filename).stem  # Remove directory and .json extension
        parts = filename_stem.split('_')
        if len(parts) >= 4:
            # fio_<host>_<storage>_<timestamp>
            host = parts[1]
            storage = parts[2]
        else:
            # Fallback to parsing jobname
            host = "unknown"
            storage = "unknown"

        # Get the test timestamp from fio output
        timestamp = test_entry.get("timestamp", None)
        if timestamp:
            test_time = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
        else:
            test_time = "unknown"

        # Iterate over jobs
        jobs = test_entry.get("jobs", [])
        for job in jobs:
            jobname = job.get("jobname", "unknown")

            # If host and storage are unknown, attempt to parse from jobname
            if host == "unknown" and storage == "unknown":
                # Assume jobname format is <host>_<storage>
                jobname_parts = jobname.split('_')
                if len(jobname_parts) >= 2:
                    host = jobname_parts[0]
                    storage = jobname_parts[1]
                else:
                    host = jobname
                    storage = "unknown"

            # Get read and write metrics
            read_metrics = job.get("read", {})
            write_metrics = job.get("write", {})

            # For read
            read_bw_kbps = read_metrics.get("bw", 0)  # bw in KB/s
            read_bw_MBps = read_bw_kbps / 1024  # Convert to MB/s
            read_iops = read_metrics.get("iops", 0)
            read_clat_mean_ns = read_metrics.get("clat_ns", {}).get("mean", 0)  # clat in ns
            read_clat_mean_ms = read_clat_mean_ns / 1_000_000  # Convert ns to ms

            # For write
            write_bw_kbps = write_metrics.get("bw", 0)  # bw in KB/s
            write_bw_MBps = write_bw_kbps / 1024  # Convert to MB/s
            write_iops = write_metrics.get("iops", 0)
            write_clat_mean_ns = write_metrics.get("clat_ns", {}).get("mean", 0)  # clat in ns
            write_clat_mean_ms = write_clat_mean_ns / 1_000_000  # Convert ns to ms

            # Append parsed results
            results.append({
                "host": host,
                "storage": storage,
                "jobname": jobname,
                "test_time": test_time,
                "read_bw_MBps": round(read_bw_MBps, 3),
                "read_iops": read_iops,
                "read_clat_mean_ms": round(read_clat_mean_ms, 3),
                "write_bw_MBps": round(write_bw_MBps, 3),
                "write_iops": write_iops,
                "write_clat_mean_ms": round(write_clat_mean_ms, 3),
            })

    return results

def write_csv(data, output_file):
    """
    Writes parsed metrics data to a CSV file.

    Parameters:
        data (list of dict): Parsed fio metrics data.
        output_file (str): Path to the output CSV file.
    """
    if not data:
        print("No data to write.")
        return

    # Define CSV headers
    headers = [
        "host",
        "storage",
        "jobname",
        "test_time",
        "read_bw_MBps",
        "read_iops",
        "read_clat_mean_ms",
        "write_bw_MBps",
        "write_iops",
        "write_clat_mean_ms",
    ]

    with open(output_file, mode="w", newline='') as file:
        writer = csv.DictWriter(file, fieldnames=headers)
        writer.writeheader()
        writer.writerows(data)
    print(f"Data successfully written to {output_file}")

def main():
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Parse aggregated fio JSON results and export metrics to CSV.")
    parser.add_argument("json_file", type=str, help="Path to the aggregated fio JSON result file.")
    parser.add_argument("output_file", type=str, help="Path to the output CSV file.")

    args = parser.parse_args()

    # Load JSON data
    with open(args.json_file, "r") as file:
        json_data = json.load(file)

    # Parse JSON data for metrics
    parsed_data = parse_aggregated_fio_json(json_data)

    # Sort data by host, storage, test_time
    parsed_data.sort(
        key=lambda x: (
            x["host"],
            x["storage"],
            x["test_time"]
        )
    )

    # Write parsed data to CSV
    write_csv(parsed_data, args.output_file)

if __name__ == "__main__":
    main()

