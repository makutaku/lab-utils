import pandas as pd
import sys

def aggregate_csv(input_csv_path, output_csv_path):
    # Read the CSV data
    df = pd.read_csv(input_csv_path, skipinitialspace=True)
    
    # Convert 'start_time' to datetime for proper sorting
    df['start_time'] = pd.to_datetime(df['start_time'])
    
    # Sort the DataFrame by 'local_host', 'remote_host', and 'start_time'
    df = df.sort_values(['local_host', 'remote_host', 'start_time'])
    
    # Convert 'throughput_bps' from bps to Mbps
    df['throughput_bps'] = df['throughput_bps'] / 1_000_000  # Convert to Mbps
    
    # Define the columns to perform statistical aggregation on
    agg_funcs = {
        'throughput_bps': ['count', 'mean', 'std', 'min', 'median', 'max', 'last'],
        'max_rtt_ms': ['mean', 'std', 'min', 'median', 'max', 'last'],
        'min_rtt_ms': ['mean', 'std', 'min', 'median', 'max', 'last'],
        'mean_rtt_ms': ['mean', 'std', 'min', 'median', 'max', 'last'],
        'retransmission_rate (%)': ['mean', 'std', 'min', 'median', 'max', 'last']
    }
    
    # Perform the aggregation
    grouped = df.groupby(['local_host', 'remote_host']).agg(agg_funcs)
    
    # Flatten the MultiIndex columns
    grouped.columns = ['_'.join(col).strip() for col in grouped.columns.values]
    
    # Rename 'throughput_bps_count' to 'samples'
    grouped.rename(columns={'throughput_bps_count': 'samples'}, inplace=True)
    
    # Replace '_bps_' with '_mbps_' in the column names to reflect new unit
    grouped.columns = [col.replace('_bps_', '_mbps_') for col in grouped.columns]
    
    # Shorten the column names smartly while keeping units
    column_rename_map = {
        'throughput_mbps_mean': 'thru_mbps_mean',
        'throughput_mbps_std': 'thru_mbps_std',
        'throughput_mbps_min': 'thru_mbps_min',
        'throughput_mbps_median': 'thru_mbps_median',
        'throughput_mbps_max': 'thru_mbps_max',
        'throughput_mbps_last': 'thru_mbps_last',
        'max_rtt_ms_mean': 'max_rtt_ms_mean',
        'max_rtt_ms_std': 'max_rtt_ms_std',
        'max_rtt_ms_min': 'max_rtt_ms_min',
        'max_rtt_ms_median': 'max_rtt_ms_median',
        'max_rtt_ms_max': 'max_rtt_ms_max',
        'max_rtt_ms_last': 'max_rtt_ms_last',
        'min_rtt_ms_mean': 'min_rtt_ms_mean',
        'min_rtt_ms_std': 'min_rtt_ms_std',
        'min_rtt_ms_min': 'min_rtt_ms_min',
        'min_rtt_ms_median': 'min_rtt_ms_median',
        'min_rtt_ms_max': 'min_rtt_ms_max',
        'min_rtt_ms_last': 'min_rtt_ms_last',
        'mean_rtt_ms_mean': 'mean_rtt_ms_mean',
        'mean_rtt_ms_std': 'mean_rtt_ms_std',
        'mean_rtt_ms_min': 'mean_rtt_ms_min',
        'mean_rtt_ms_median': 'mean_rtt_ms_median',
        'mean_rtt_ms_max': 'mean_rtt_ms_max',
        'mean_rtt_ms_last': 'mean_rtt_ms_last',
        'retransmission_rate (%)_mean': 'retrans_%_mean',
        'retransmission_rate (%)_std': 'retrans_%_std',
        'retransmission_rate (%)_min': 'retrans_%_min',
        'retransmission_rate (%)_median': 'retrans_%_median',
        'retransmission_rate (%)_max': 'retrans_%_max',
        'retransmission_rate (%)_last': 'retrans_%_last',
        # 'samples' remains as is
    }
    
    grouped.rename(columns=column_rename_map, inplace=True)
    
    # Reset index to turn the group keys into columns
    grouped.reset_index(inplace=True)
    
    # Round numeric columns to appropriate decimal places
    for col in grouped.columns:
        if pd.api.types.is_numeric_dtype(grouped[col]):
            grouped[col] = grouped[col].round(3)
    
    # Write the aggregated data to the output CSV file
    grouped.to_csv(output_csv_path, index=False)
    
    # Select key statistics to display
    display_columns = [
        'local_host',
        'remote_host',
        'samples',
        'thru_mbps_mean',
        'thru_mbps_last',
        'max_rtt_ms_mean',
        'max_rtt_ms_last',
        'mean_rtt_ms_mean',
        'mean_rtt_ms_last',
        'retrans_%_mean',
        'retrans_%_last'
    ]
    
    # Create a summary DataFrame with selected columns
    summary_df = grouped[display_columns]
    
    # Print the summary DataFrame
    print("\nSummary Statistics:\n")
    print(summary_df.to_string(index=False))
    
    print(f"\nAggregated data has been written to {output_csv_path}")

if __name__ == "__main__":
    # Check if input and output file paths are provided
    if len(sys.argv) != 3:
        print("Usage: python aggregate_script.py input_csv_path output_csv_path")
        sys.exit(1)
    
    input_csv = sys.argv[1]
    output_csv = sys.argv[2]
    
    aggregate_csv(input_csv, output_csv)
