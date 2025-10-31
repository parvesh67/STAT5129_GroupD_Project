# Mauritius Case Study Analysis Project

## Overview
This project analyzes and models relationships between **climate**, **energy**, and **agriculture** datasets for Mauritius.  
It uses **MySQL** for data storage and **R** for data processing, visualization, and modeling.

## Database Setup
1. Import the MySQL database file into your local server:
   ```
   mauritius_data.sql
   ```
2. Make sure MySQL Workbench or your MySQL server is running.
3. Update credentials in the R script (`R/00_run_all.R`) if needed:
   ```r
   user = "root"
   password = "abc123"
   dbname = "mauritius_data"
   host = "127.0.0.1"
   port = 3306
   ```

## Project Environment Setup
The project uses **renv** to ensure reproducible environments and consistent package versions.  

Run these commands in **R** (preferably inside RStudio):

```r
# ============================
# Project Setup: Environment Activation & Package Restore
# ============================

# Set working directory (Change path to your working directory)
setwd("C:/Users/vikgh/Desktop/STAT5129_GroupD_Project")

# Install renv if not already available
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cran.rstudio.com")

# Load renv
library(renv)

# Activate the project environment
renv::activate()

# Restore packages from renv.lock
renv::restore()
```

✅ After restoring:
- The environment will match the project setup.
- Restart R if prompted.
- Then execute:
  ```r
  source("R/00_run_all.R")
  ```

## Running the Project

### Option 1 — RStudio (Recommended)
Open the R project folder (`STAT5129_GroupD_Project`) in **RStudio** and run:
```r
source("R/00_run_all.R")
```

### Option 2 — R GUI or External Editor 
If not using RStudio, manually set the working directory as a fallback path:
```r
current_r_dir <- "C:/Users/vikgh/Desktop/STAT5129_GroupD_Project/R"
```
Then run:
```r
source("R/00_run_all.R")
```

This will:
- Install and load all required packages.
- Connect to the **MySQL database**.
- Automatically detect or fallback to the correct R working directory.
- Source `R/01_data_stage_standardisation.R` (and subsequent scripts).

💡 Note:  
If `rstudioapi` is not available, the fallback path `"C:/Users/vikgh/Desktop/STAT5129_GroupD_Project/R"` will be used automatically. Change this path to match your project’s working directory if different.

## Project Structure
```
STAT5129_GroupD_Project/
├── data_raw/                # Original unprocessed datasets
├── data_stage/              # Cleaned / intermediate datasets
├── R/                       # R scripts for processing and modeling
│   ├── 00_run_all.R
│   ├── 01_data_stage_prelim.R
│   ├── 02_data_stage_preprocessing.R
│   ├── 03_data_stage_export_csv.R
│   ├── 04_data_stage_csv_check.R
│   ├── 05_studymodel_bagasse.R
│   ├── 06_studymodel_photovoltaic.R
│   └── ...
├── renv/                    # Local environment package library
├── report/                  # Outputs and visualizations
│   ├───analysis_outputs/
│   ├───datastage_plots/
│   ├───datastage_summaries/
│   └───validation_checks/
├── skills_demo_nyc/         # NYC Yellow Taxi analysis scripts and outputs
│   ├── nyc_data_raw/        
│   ├── outputs/             
│   ├── NYC_Parquet.R        # Analysis script for NYC Yellow Taxi data
│   └── README.md            
└── mauritius_data.sql       # MySQL schema and data dump

```

💡 **Note:**  
The folders `data_raw`, `data_stage`, and `report/plots` are automatically created by the scripts if they do not exist. If you delete these folders, running the code will regenerate them and load or process the necessary data.  

## Package Management (00_run_all.R)
The main script (`00_run_all.R`) automatically:
- Installs required packages if missing.
- Loads all dependencies:
```
DBI, RMariaDB, dplyr, lubridate, zoo, SPEI, reshape2,
FAOSTAT, data.table, jsonlite, tidyr, naniar, readr,
ggplot2, skimr, corrplot, scales, janitor, renv
```
- Connects to MySQL (`mauritius_data`).
- Detects RStudio environment and adjusts paths.
- Sources subsequent scripts sequentially.

## One-Line Quick Build
Run this single line in **R** to automatically set up and execute the entire project (Change to your working directory):

```r
setwd("C:/Users/vikgh/Desktop/STAT5129_GroupD_Project"); if(!requireNamespace("renv", quietly=TRUE)) install.packages("renv", repos="https://cran.rstudio.com"); library(renv); renv::activate(); renv::restore(); source("R/00_run_all.R")
```

## Notes
- Always run `renv::snapshot()` after adding new packages to update `renv.lock`.
- Comment out `options(warn = -1)` inside `00_run_all.R` if you want to debug warnings.
- Ensure MySQL is active before running the scripts.
- The fallback (current_r_dir) path ensures execution even outside RStudio.
- The Quarto PDF (report.pdf) is automatically generated via GitHub Actions on every push to the main branch. TinyTeX is used to compile the PDF, ensuring reproducibility. The workflow file is located at .github/workflows/render-pdf.yml
- Github URL: https://github.com/parvesh67/STAT5129_GroupD_Project

✅ You’re ready to run the full Mauritius Case Study Data workflow!
"# STAT5129_GroupD_Project" 
