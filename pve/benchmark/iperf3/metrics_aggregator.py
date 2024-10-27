import os
import re
import json
import argparse
import logging
from datetime import datetime
from collections import defaultdict

import pandas as pd

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def parse_filename(filename, prefix):
    """
    Parse the filename to extract client IP, server IP, and timestamp.
    """
    pattern = rf'{prefix}_(\d+\.\d+\.\d+\.\d+)_to_(\d+\.\d+\.\d+\.\d+)_(\d{8})_(\d{6})\.json$'
    match = re.match(pattern, filename)
    if not match:
        logging.warning(f"Filename {filename} does not match expected pattern.")
        return None, None, None
    client_ip, server_ip, date_str, time_str = match.groups()
    try:
        timestamp = datetime.strptime(date_str + time_str, "%Y%m%d%H%M%S")
    except ValueError as e:
        logging.error(f"Error parsing date and time from filename {filename}: {e}")
        return client_ip, server_ip, None
    return client_ip, server_ip, timestamp

def extract_iperf_metrics(json_data):
    """
    Extract relevant metrics from the iperf3 JSON data.
    """
    metrics = {}
    try:
        end = json_data.get('end', {})
        sum_sent = end.get('sum_sent', {})
        sum_received = end.get('sum_received', {})
        
        # Extracting sent metrics
        metrics['sent_bits_per_sec'] = sum_sent.get('bits_per_second', 0)
        metrics['sent_bytes'] = sum_sent.get('bytes', 0)
        metrics['sent_retransmits'] = sum_sent.get('retransmits', 0)
        
        # Extracting received metrics
        metrics['received_bits_per_sec'] = sum_received.get('bits_per_second', 0)
        metrics['received_bytes'] = sum_received.get('bytes', 0)
        metrics['received_retransmits'] = sum_received.get('retransmits', 0)
        
        # Jitter and packet loss
        metrics['jitter_ms'] = sum_received.get('jitter_ms', 0)
        metrics['packet_loss_percent'] = sum_received.get('lost_percent', 0)
        
    except Exception as e:
        logging.error(f"Error extracting metrics: {e}")
    return metrics

def extract_ping_metrics(ping_file):
    """
    Extract latency metrics (min, avg, max, stddev) from a ping output file.
    """
    metrics = {}
    try:
        with open(ping_file, 'r') as file:
            lines = file.readlines()
            for line in lines:
                if "min/avg/max/mdev" in line:
                    parts = line.split(" = ")[1].split("/")
                    metrics['latency_min_ms'] = float(parts[0])
                    metrics['latency_avg_ms'] = float(parts[1])
                    metrics['latency_max_ms'] = float(parts[2])
                    metrics['latency_stddev_ms'] = float(parts[3].split()[0])  # Remove trailing ms
                    break
    except Exception as e:
        logging.error(f"Error extracting ping metrics from {ping_file}: {e}")
    return metrics

def process_files(input_dir):
    """
    Process all JSON files in the input directory.
    """
    client_data = defaultdict(list)
    iperf_files = [f for f in os.listdir(input_dir) if f.startswith('iperf_') and f.endswith('.json')]
    ping_files = [f for f in os.listdir(input_dir) if f.startswith('ping_') and f.endswith('.json')]

    logging.info(f"Found {len(iperf_files)} iperf JSON files and {len(ping_files)} ping files in {input_dir}.")

    for filename in iperf_files:
        client_ip, server_ip, timestamp = parse_filename(filename, "iperf")
        if not client_ip or not timestamp:
            logging.warning(f"Skipping file {filename} due to parsing issues.")
            continue
        filepath = os.path.join(input_dir, filename)
        try:
            with open(filepath, 'r') as file:
                json_data = json.load(file)
            metrics = extract_iperf_metrics(json_data)
            metrics['timestamp'] = timestamp
            metrics['server_ip'] = server_ip
            client_data[client_ip].append(metrics)
        except json.JSONDecodeError as e:
            logging.error(f"JSON decode error in file {filename}: {e}")
        except Exception as e:
            logging.error(f"Unexpected error processing file {filename}: {e}")
    
    for filename in ping_files:
        client_ip, server_ip, timestamp = parse_filename(filename, "ping")
        if not client_ip or not timestamp:
            logging.warning(f"Skipping file {filename} due to parsing issues.")
            continue
        filepath = os.path.join(input_dir, filename)
        metrics = extract_ping_metrics(filepath)
        metrics['timestamp'] = timestamp
        metrics['server_ip'] = server_ip
        client_data[client_ip].append(metrics)
    
    return client_data

def compute_additional_metrics(df):
    """
    Compute additional statistical metrics like 7-day and 30-day SMAs.
    """
    df.sort_values('timestamp', inplace=True)
    df.set_index('timestamp', inplace=True)

    windows = {
        '7_day_SMA_bits_per_sec_sent': 7,
        '30_day_SMA_bits_per_sec_sent': 30,
        '7_day_SMA_bits_per_sec_received': 7,
        '30_day_SMA_bits_per_sec_received': 30,
        '7_day_SMA_latency_avg_ms': 7,
        '30_day_SMA_latency_avg_ms': 30,
    }

    for col_suffix, window in windows.items():
        if 'sent_bits_per_sec' in col_suffix:
            df[col_suffix] = df['sent_bits_per_sec'].rolling(f'{window}D').mean()
        elif 'received_bits_per_sec' in col_suffix:
            df[col_suffix] = df['received_bits_per_sec'].rolling(f'{window}D').mean()
        elif 'latency_avg_ms' in col_suffix:
            df[col_suffix] = df['latency_avg_ms'].rolling(f'{window}D').mean()

    df.reset_index(inplace=True)

def write_csv_per_client(client_data, output_dir):
    """
    Write the aggregated data for each client to separate CSV files.
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        logging.info(f"Created output directory {output_dir}.")

    for client_ip, metrics_list in client_data.items():
        if not metrics_list:
            logging.warning(f"No data for client {client_ip}. Skipping.")
            continue
        df = pd.DataFrame(metrics_list)
        if 'timestamp' not in df.columns:
            logging.warning(f"No timestamp for client {client_ip}. Skipping.")
            continue

        compute_additional_metrics(df)

        csv_filename = f"client_{client_ip.replace('.', '_')}.csv"
        csv_filepath = os.path.join(output_dir, csv_filename)
        
        try:
            df.to_csv(csv_filepath, index=False)
            logging.info(f"Written CSV for client {client_ip} to {csv_filepath}.")
        except Exception as e:
            logging.error(f"Error writing CSV for client {client_ip}: {e}")

def main():
    parser = argparse.ArgumentParser(
        description="Process iperf3 and ping results, aggregate metrics per client.",
        epilog="Example usage:\n"
               "python iperf3_metrics_aggregator.py ./iperf3_results/ ./output_csvs/\n\n"
               "This command will process all iperf3 and ping files in the ./iperf3_results/ directory "
               "and store output CSV files in the ./output_csvs/ directory.",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('input_dir', help="Directory containing iperf3 and ping files.")
    parser.add_argument('output_dir', help="Directory to store output CSV files.")
    
    args = parser.parse_args()

    if not args.input_dir or not args.output_dir:
        parser.print_help()
        exit(1)

    input_dir = args.input_dir
    output_dir = args.output_dir

    if not os.path.isdir(input_dir):
        logging.error(f"Input directory {input_dir} does not exist or is not a directory.")
        parser.print_help()
        exit(1)

    client_data = process_files(input_dir)
    write_csv_per_client(client_data, output_dir)
    logging.info("Processing complete.")

if __name__ == "__main__":
    main()

