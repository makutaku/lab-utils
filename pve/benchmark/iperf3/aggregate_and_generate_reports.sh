#!/bin/bash

# Determine the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if at least 2 arguments are provided
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <source_dir> <csv_dir> [pdf_dir]"
  echo ""
  echo "Example:"
  echo "  $0 ~/iperf/results/ ~/iperf/reports/"
  echo "  $0 ~/iperf/results/ ~/iperf/reports/ ~/iperf/pdfs/"
  exit 1
fi

# Assign variables from input arguments
SOURCE_DIR="$1"
CSV_DIR="$2"
PDF_DIR="${3:-$CSV_DIR}" # Use CSV directory if PDF directory is not provided

# Activate the virtual environment
VENV_PATH="$SCRIPT_DIR/venv"
if [ -d "$VENV_PATH" ]; then
  source "$VENV_PATH/bin/activate"
  echo "Virtual environment activated."
else
  echo "Virtual environment not found at $VENV_PATH. Please set up the virtual environment."
  exit 1
fi

# Run metrics aggregation and report generation
python3 "$SCRIPT_DIR/metrics_aggregator.py" "$SOURCE_DIR" "$CSV_DIR" &&
find "$CSV_DIR" -name "*.csv" -exec python3 "$SCRIPT_DIR/generate_report.py" {} "$PDF_DIR" \;

# Check the exit status of the entire operation
if [ $? -eq 0 ]; then
  echo "Metrics aggregation and report generation completed successfully."
else
  echo "An error occurred during the process."
fi

# Deactivate the virtual environment
deactivate


