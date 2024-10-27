import pandas as pd
import matplotlib.pyplot as plt
from fpdf import FPDF
import os
import sys
from pathlib import Path

# Load the data
def load_data(file_path):
    return pd.read_csv(file_path, parse_dates=True)

# Detect the datetime column and numeric columns
def identify_columns(df):
    datetime_col = None
    numeric_cols = []

    # Identify the first datetime column
    for col in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            datetime_col = col
            break

    # Identify all numeric columns
    for col in df.columns:
        if pd.api.types.is_numeric_dtype(df[col]):
            numeric_cols.append(col)

    if not datetime_col:
        raise ValueError("No datetime column found in the dataset.")
    if not numeric_cols:
        raise ValueError("No numeric columns found in the dataset.")

    return datetime_col, numeric_cols

# Plot each metric over time
def plot_metric(df, x_col, y_col, title):
    plt.figure()
    plt.plot(df[x_col], df[y_col], marker='o', linestyle='-', color='b')
    plt.title(title)
    plt.xlabel(x_col.replace("_", " ").capitalize())
    plt.ylabel(y_col.replace("_", " ").capitalize())
    plt.xticks(rotation=45)
    plt.tight_layout()
    file_name = f"{y_col}.png"
    plt.savefig(file_name)
    plt.close()
    return file_name

# Create a PDF with charts for each metric
def create_pdf(metrics, pdf_file_name):
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)

    for metric, title in metrics.items():
        pdf.add_page()
        pdf.set_font("Arial", "B", 12)
        pdf.cell(200, 10, title, ln=True, align='C')
        
        # Add the image to the PDF
        pdf.image(f"{metric}.png", x=10, y=20, w=180)
        
    pdf.output(pdf_file_name)

# Clean up image files
def cleanup_images(metrics):
    for metric in metrics:
        os.remove(f"{metric}.png")

def main(input_csv, output_dir):
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
    print(f"PDF report generated: {output_pdf}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python generate_report.py <input_csv_file> <output_directory>")
    else:
        input_csv = sys.argv[1]
        output_dir = sys.argv[2]

        # Check if input file exists
        if not os.path.isfile(input_csv):
            print(f"Error: Input file '{input_csv}' does not exist.")
            sys.exit(1)

        # Check if output directory exists
        if not os.path.isdir(output_dir):
            print(f"Error: Output directory '{output_dir}' does not exist.")
            sys.exit(1)

        main(input_csv, output_dir)

