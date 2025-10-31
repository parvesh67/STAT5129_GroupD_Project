# NYC Yellow Trip Data Analysis

## Overview
This project analyzes **New York City Yellow Taxi trip data** to explore patterns such as **trip duration, payment methods, and peak travel hours**.  
The workflow follows a complete **ETL (Extract–Transform–Load)** structure — from data download to visualization — using **R** and **open data** hosted on AWS.

## Project Setup

### 1. Prerequisites
Ensure **R (≥ 4.0)** and **RStudio** are installed.  
The following R packages are used in this project:

```
arrow, dplyr, ggplot2, lubridate, readr, httr
```

### 2. Directory Setup
Clone or copy the project folder (e.g., `skills_demo_nyc`) and ensure the following structure:

```
skills_demo_nyc/
├── nyc_data_raw/          # Stores raw downloaded datasets
├── outputs/               # Stores cleaned data, results, and plots
├── nyc_taxi_analysis.R    # Main analysis script
└── README.md
```

> 💡 The script automatically creates folders (`nyc_data_raw`, `outputs`) if they do not exist.

## Running the Project

### Option 1 — RStudio (Recommended)
Open the R script (`nyc_taxi_analysis.R`) in **RStudio**, then run:
```r
source("nyc_taxi_analysis.R")
```

### Option 2 — R Console or External Editor
If running outside RStudio, the script will use a **fallback path**:
```r
current_r_dir <- "C:/Users/vikgh/Desktop/STAT5129_GroupD_Project/skills_demo_nyc"
```
Modify this path to match your local directory.

## Script Workflow

### **1. Package Setup**
Automatically installs and loads all required packages:
```r
arrow, dplyr, ggplot2, lubridate, readr, httr
```
Used for efficient data import, manipulation, and visualization.

### **2. Extract — Data Import**
- Downloads the **January 2024 NYC Yellow Taxi trip dataset** in `.parquet` format from:
  ```
  https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet
  ```
- Saves it locally to:
  ```
  nyc_data_raw/yellow_tripdata_2024-01.parquet
  ```

If the file already exists, the script skips re-downloading.

### **3. Transform — Data Cleaning**
Performs the following transformations:
- Converts pickup and drop-off timestamps to `POSIXct`.
- Calculates **trip duration (in minutes)**.
- Filters out invalid records:
  - Trips with `trip_distance <= 0`
  - Trips longer than 240 minutes (4 hours)
- Removes missing values (`na.omit()`).
- Keeps key columns:
  ```
  tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count,
  trip_distance, fare_amount, tip_amount, payment_type, trip_duration
  ```

### **4. Analyze — Exploratory Analysis**
#### a) Payment Method Distribution
Payment types are relabeled for clarity:
```
1 = Credit Card
2 = Cash
3 = No Charge
4 = Dispute
5 = Unknown
6 = Voided Trip
```
Counts and visual summaries are generated and saved in:
```
outputs/payment_type_counts.txt
outputs/Payment_type.png
```

#### b) Trip Duration & Missing Data
Performs descriptive statistics, summaries, and structure inspection.

#### c) Peak Hour Analysis
Extracts the **hour of the day** from pickup timestamps and groups trips by hour to identify:
- **Peak Hour:** Time with the highest trip count  
- **Off-Peak Hour:** Time with the lowest trip count  

Results are saved to:
```
outputs/peak_hours_data.csv
outputs/peak_hours_data.txt
outputs/peak_hour.png
outputs/Trend across 24 Hrs.png
```

### **5. Load — Save Clean Data**
Outputs are saved in the `/outputs` directory:
- Clean dataset: `taxi_clean.parquet`
- Summary files: `taxi_df.txt`
- CSV summaries and visual plots.

## Key Outputs
| File Name | Description |
|-----------|-------------|
| taxi_clean.parquet | Cleaned and filtered dataset ready for analysis. |
| taxi_df.txt | Summary of the dataset structure and descriptive statistics. |
| payment_type_counts.txt | Count of trips by payment type. |
| Payment_type.png | Bar chart showing payment type distribution. |
| peak_hours_data.csv | Hourly trip frequency summary (0–23 hours). |
| peak_hours_data.txt | Text summary of hourly trip counts and identified peak/off-peak hours. |
| peak_hour.png | Bar chart showing total trip counts by hour. |
| Trend across 24 Hrs.png | Line chart showing trip volume trends throughout the day. |

## Notes
- The script automatically detects **RStudio** context; if unavailable, it uses the fallback path.
- Re-run the script anytime to refresh results or reprocess updated data.
- Internet connection is required for the first-time download of the parquet file.
- All generated files are saved under `/skills_demo_nyc/outputs`.

✅ Once the script finishes, all outputs will be available in the `outputs` folder — ready for review and reporting.
