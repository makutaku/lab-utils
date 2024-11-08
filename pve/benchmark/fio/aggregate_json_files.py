import os
import json
import logging
import argparse
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

def aggregate_json_files(input_dir, output_file):
    """
    Aggregates JSON data from multiple files in a directory into a single JSON array.

    Parameters:
        input_dir (str): Directory containing JSON files to aggregate.
        output_file (str): File path to save the aggregated JSON output.
    """
    aggregated_results = []

    # Check if the input directory exists
    if not os.path.isdir(input_dir):
        logger.error(f"Input directory does not exist: {input_dir}")
        return

    # Process each JSON file in the directory
    for filename in os.listdir(input_dir):
        if filename.endswith(".json"):
            file_path = os.path.join(input_dir, filename)
            try:
                with open(file_path, "r") as file:
                    json_data = json.load(file)
                    aggregated_results.append(json_data)
                    logger.info(f"Processed file: {filename}")
            except json.JSONDecodeError as e:
                logger.error(f"Error decoding JSON in file {filename}: {e}")
            except Exception as e:
                logger.error(f"Unexpected error in file {filename}: {e}")

    # Save the aggregated JSON array to the specified output file
    try:
        with open(output_file, "w") as outfile:
            json.dump(aggregated_results, outfile, indent=4)
        logger.info(f"Aggregated results saved to {output_file}")
    except Exception as e:
        logger.error(f"Failed to save the aggregated JSON file: {e}")

def main():
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Aggregate JSON files into a single JSON array.")
    parser.add_argument("input_dir", type=str, help="Directory containing JSON files to aggregate.")
    parser.add_argument("output_file", type=str, help="Output file to save the aggregated JSON data.")
    
    # Parse arguments
    args = parser.parse_args()
    
    # Call the aggregation function
    aggregate_json_files(args.input_dir, args.output_file)

if __name__ == "__main__":
    main()

