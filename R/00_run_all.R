# -----------------------------
# Install and load required libraries
# -----------------------------
required_pkgs <- c(
  "DBI", "RMariaDB", "dplyr", "lubridate", "zoo", "SPEI", "reshape2",
  "FAOSTAT", "data.table", "jsonlite", "tidyr", "naniar", "readr",
  "ggplot2", "skimr", "corrplot", "scales", "janitor", "renv"
)


for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cran.rstudio.com")
  }
  library(pkg, character.only = TRUE)
}

# -----------------------------
# Connect to MySQL
# -----------------------------
con <- dbConnect(
  MariaDB(),
  
                            #------------------ Update credentials if needed
  user = "root",
  password = "abc123",
  
  dbname = "mauritius_data",
  host = "127.0.0.1",
  port = 3306
)

# -----------------------------
# Set directories: Use RStudio API or fallback
# -----------------------------
if (requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable()) {
  current_r_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
} else {
  
                       # FALLBACK PATH — change this to the folder containing your R scripts
  current_r_dir <- "C:/Users/vikgh/Desktop/STAT5129_GroupD_Project/R"
  
}

# Set working directory to current_r_dir
setwd(current_r_dir)

# Check
print(current_r_dir)
print(list.files(current_r_dir))


# LOCK ENV
# setwd("C:/Users/vikgh/Desktop/STAT5129_GroupD_Project")
# renv::init()   # Run this once at the start of the project
# renv::snapshot()  # Updates renv.lock with currently installed packages

# renv::activate()
# if (file.exists("renv.lock")) renv::restore()
# Any code after renv::restore() will not automatically run.
# You need to run the rest of your script again (or split your script so you first restore the environment, 
#                                                then run your analysis scripts).

# default 
options(warn = 0)

# suppress warnings for output readability (comment this line when debugging)
options(warn = -1)

source(file.path(current_r_dir, "01_data_stage_prelim.R"))
