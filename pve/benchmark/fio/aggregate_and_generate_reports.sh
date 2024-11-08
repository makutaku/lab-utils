#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Determine the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage instructions
usage() {
  echo "Usage: $0 <source_dir> [summary_csv_path]"
  echo ""
  echo "Arguments:"
  echo "  <source_dir>         Directory containing the source fio JSON results."
  echo "  [summary_csv_path]   (Optional) Full path for the summary CSV report."
  echo "                       If not provided, defaults to <source_dir>/summary.csv."
  echo ""
  echo "Examples:"
  echo "  $0 ~/fio/results/"
  echo "  $0 ~/fio/results/ ~/fio/reports/fio_summary.csv"
  exit 1
}

# Check if at least 1 argument is provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Assign variables from input arguments
SOURCE_DIR="$1"

if [ "$#" -ge 2 ]; then
  SUMMARY_CSV_PATH="$2"
else
  SUMMARY_CSV_PATH="$SOURCE_DIR/summary.csv"
fi

# Extract the directory from the summary CSV path
SUMMARY_CSV_DIR="$(dirname "$SUMMARY_CSV_PATH")"

# Check if the summary CSV directory exists; if not, attempt to create it
if [ ! -d "$SUMMARY_CSV_DIR" ]; then
  echo "Summary CSV directory '$SUMMARY_CSV_DIR' does not exist. Attempting to create it..."
  mkdir -p "$SUMMARY_CSV_DIR" || { echo "Failed to create directory '$SUMMARY_CSV_DIR'."; exit 1; }
  echo "Directory '$SUMMARY_CSV_DIR' created successfully."
fi

# Activate the virtual environment
VENV_PATH="$SCRIPT_DIR/venv"
if [ -d "$VENV_PATH" ]; then
  source "$VENV_PATH/bin/activate"
  echo "Virtual environment activated."
else
  echo "Virtual environment not found at $VENV_PATH. Please set up the virtual environment."
  exit 1
fi

# Create a temporary file for aggregated fio JSON data
TEMP_JSON=$(mktemp) || { echo "Failed to create temporary file."; exit 1; }

# Ensure the temporary file is deleted when the script exits
trap 'rm -f "$TEMP_JSON"' EXIT

# Aggregate individual results into the temporary JSON file
python3 "$SCRIPT_DIR/aggregate_json_files.py" "$SOURCE_DIR" "$TEMP_JSON"

# Process the JSON file, select important fields, and output to CSV
TEMP_CSV=$(mktemp) || { echo "Failed to create temporary CSV file."; exit 1; }
python3 "$SCRIPT_DIR/fio_to_csv.py" "$TEMP_JSON" "$TEMP_CSV"

# Group and analyze metrics, generating the summary CSV report at the specified path
python3 "$SCRIPT_DIR/fio_summarize.py" "$TEMP_CSV" "$SUMMARY_CSV_PATH"

# Check the exit status of the entire operation
if [ $? -eq 0 ]; then
  echo "Metrics aggregation and report generation completed successfully."
  echo "Summary report available at: $SUMMARY_CSV_PATH"
else
  echo "An error occurred during the process."
fi

# Deactivate the virtual environment
deactivate

