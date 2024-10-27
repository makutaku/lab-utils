import pandas as pd
import matplotlib.pyplot as plt
from fpdf import FPDF
import os
import sys
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(), logging.FileHandler("generate_report.log", mode='a')]
)

# Load the data
def load_data(file_path):
    logging.info(f"Loading data from {file_path}")
    try:
        df = pd.read_csv(file_path, parse_dates=True)
        logging.info(f"Data loaded successfully with {len(df)} rows.")
        return df
    except Exception as e:
        logging.error(f"Error loading data from {file_path}: {e}")
        raise

# Detect the datetime column and numeric columns, excluding empty columns
def identify_columns(df):
    datetime_col = None
    numeric_cols = []

    # Identify the first datetime-like column
    for col in df.columns:
        try:
            if pd.to_datetime(df[col], errors='raise').notnull().all():
                datetime_col = col
                break
        except Exception:
            continue

    # Identify all numeric columns with at least one non-null value
    for col in df.columns:
        if pd.api.types.is_numeric_dtype(df[col]) and df[col].notnull().any():
            numeric_cols.append(col)

    if not datetime_col:
        logging.error("No datetime column found in the dataset.")
        raise ValueError("No datetime column found in the dataset.")
    if not numeric_cols:
        logging.error("No numeric columns found in the dataset.")
        raise ValueError("No numeric columns found in the dataset.")

    logging.info(f"Identified datetime column: {datetime_col}")
    logging.info(f"Identified numeric columns: {numeric_cols}")
    return datetime_col, numeric_cols

# Plot each metric over time
def plot_metric(df, x_col, y_col, title):
    logging.info(f"Plotting {y_col} over {x_col}")
    plt.figure()
    plt.plot(df[x_col], df[y_col], marker='o', linestyle='-', color='b')
    plt.title(title)
    plt.xlabel(x_col.replace("_", " ").capitalize())
    plt.ylabel(y_col.replace("_", " ").capitalize())
    plt.xticks(rotation=45)
    plt.tight_layout()
    file_name = f"{y_col}.png"
    try:
        plt.savefig(file_name)
        logging.info(f"Saved plot {file_name}")
    except Exception as e:
        logging.error(f"Failed to save plot {file_name}: {e}")
    finally:
        plt.close()
    return file_name

# Create a PDF with charts for each metric
def create_pdf(metrics, pdf_file_name):
    logging.info(f"Creating PDF report: {pdf_file_name}")
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)

    for metric, title in metrics.items():
        try:
            pdf.add_page()
            pdf.set_font("Arial", "B", 12)
            pdf.cell(200, 10, title, ln=True, align='C')
            pdf.image(f"{metric}.png", x=10, y=20, w=180)
            logging.info(f"Added plot {metric}.png to PDF")
        except Exception as e:
            logging.error(f"Error adding {metric} to PDF: {e}")

    pdf.output(pdf_file_name)
    logging.info(f"PDF report created successfully: {pdf_file_name}")

# Clean up image files
def cleanup_images(metrics):
    for metric in metrics:
        try:
            os.remove(f"{metric}.png")
            logging.info(f"Deleted image file {metric}.png")
        except FileNotFoundError:
            logging.warning(f"Image file {metric}.png not found for deletion")

def main(input_csv, output_dir):
    logging.info(f"Starting report generation for {input_csv}")
    # Load the data
    df = load_data(input_csv)

    # Identify the datetime and numeric columns
    x_col, y_cols = identify_columns(df)

    # Prepare metrics for plotting
    metrics = {y_col: y_col.replace("_", " ").capitalize() for y_col in y_cols}

    # Plot each metric and save to PDF
    image_files = [plot_metric(df, x_col, y_col, title) for y_col, title in metrics.items()]

    # Generate output PDF filename
    output_pdf = Path(output_dir) / f"{Path(input_csv).stem}.pdf"
    create_pdf(metrics, str(output_pdf))
    
    # Clean up images
    cleanup_images(metrics)
    logging.info(f"Report generation completed for {input_csv}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python generate_report.py <input_csv_file> <output_directory>")
        sys.exit(1)
    else:
        input_csv = sys.argv[1]
        output_dir = sys.argv[2]

        # Check if input file exists
        if not os.path.isfile(input_csv):
            logging.error(f"Input file '{input_csv}' does not exist.")
            sys.exit(1)

        # Check if output directory exists
        if not os.path.isdir(output_dir):
            logging.error(f"Output directory '{output_dir}' does not exist.")
            sys.exit(1)

        main(input_csv, output_dir)
