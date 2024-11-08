import pandas as pd
import sys

def aggregate_csv(input_csv_path, output_csv_path):
    # Read the CSV data
    df = pd.read_csv(input_csv_path, skipinitialspace=True)
    
    # Convert 'test_time' to datetime for proper sorting
    df['test_time'] = pd.to_datetime(df['test_time'])
    
    # Sort the DataFrame by 'host', 'storage', and 'test_time'
    df = df.sort_values(['host', 'storage', 'test_time'])
    
    # Define the columns to perform statistical aggregation on
    agg_funcs = {
        'read_bw_MBps': ['count', 'mean', 'std', 'min', 'median', 'max', 'last'],
        'read_iops': ['mean', 'std', 'min', 'median', 'max', 'last'],
        'read_clat_mean_ms': ['mean', 'std', 'min', 'median', 'max', 'last'],
        'write_bw_MBps': ['mean', 'std', 'min', 'median', 'max', 'last'],
        'write_iops': ['mean', 'std', 'min', 'median', 'max', 'last'],
        'write_clat_mean_ms': ['mean', 'std', 'min', 'median', 'max', 'last'],
    }
    
    # Perform the aggregation
    grouped = df.groupby(['host', 'storage']).agg(agg_funcs)
    
    # Flatten the MultiIndex columns
    grouped.columns = ['_'.join(col).strip() for col in grouped.columns.values]
    
    # Rename 'read_bw_MBps_count' to 'samples'
    grouped.rename(columns={'read_bw_MBps_count': 'samples'}, inplace=True)
    
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
        'host',
        'storage',
        'samples',
        'read_bw_MBps_mean',
        'read_bw_MBps_last',
        'write_bw_MBps_mean',
        'write_bw_MBps_last',
        'read_iops_mean',
        'read_iops_last',
        'write_iops_mean',
        'write_iops_last',
        'read_clat_mean_ms_mean',
        'read_clat_mean_ms_last',
        'write_clat_mean_ms_mean',
        'write_clat_mean_ms_last',
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
        print("Usage: python fio_summarize.py input_csv_path output_csv_path")
        sys.exit(1)
    
    input_csv = sys.argv[1]
    output_csv = sys.argv[2]
    
    aggregate_csv(input_csv, output_csv)

