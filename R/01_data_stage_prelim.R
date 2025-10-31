# =============================
# Mauritius Datasets - Preliminary Exploration
# =============================

# current_r_dir <- "C:/Users/vikgh/Desktop/DHA Assignment/R"

base_dir <- dirname(current_r_dir)
data_raw_dir <- file.path(base_dir, "data_raw")
livestock_zip <- file.path(data_raw_dir, "Production_Crops_Livestock_E_All_Data_(Normalized).zip")
livestock_csv_name <- "Production_Crops_Livestock_E_All_Data_(Normalized).csv"
data_stage_dir <- file.path(base_dir, "data_stage")
report_plots_dir <- file.path(base_dir, "report/datastage_plots")
report_outputs_dir <- file.path(base_dir, "report/datastage_summaries")
validation_dir <- file.path(base_dir, "report/validation_checks")
analysis_outputs_dir <- file.path(base_dir, "report/analysis_outputs")


dir.create(analysis_outputs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(validation_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_outputs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_stage_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_plots_dir, recursive = TRUE, showWarnings = FALSE)

# =============================
# 1. Load / Download Full Datasets
# =============================

# ---- 1.1 Crops dataset ---- crops/livestock stats annually
# Temporary extraction folder
tmp_dir <- tempdir()  # safe temp folder
tmp_csv <- file.path(tmp_dir, livestock_csv_name)

# Check if zip exists
if (file.exists(livestock_zip)) {
  message("Local zip found. Extracting and loading crops dataset...")
  unzip(livestock_zip, files = livestock_csv_name, exdir = tmp_dir)     # Extract only the CSV to temp folder
  crops <- fread(tmp_csv)   # fread reads the extracted file efficiently
  unlink(tmp_csv)           # Clean up
  
} else {
  message("Zip not found. Downloading via FAOSTAT API...")
  crops <- get_faostat_bulk(code = "QCL", data_folder = data_raw_dir)
}
# Clean names
crops <- crops %>% clean_names()

# ---- 1.2 Electricity dataset ---- yearly electricity generation (gWh) by source of energy
elec_file <- file.path(data_raw_dir, "electricity-exported-to-central-electricity-board-by-energy-source.csv")
elec_url  <- "https://data.govmu.org/dataset/ce3a0f9f-7974-4b40-b4bd-aa24f6aef363/resource/61a41cac-d8e4-4fa4-bf29-f539a1e17736/download/electricity-exported-to-central-electricity-board-by-energy-source.csv"

if (!file.exists(elec_file)) {
  message("Electricity CSV not found locally. Downloading from data.govmu.org...")
  tryCatch({
    download.file(elec_url, destfile = elec_file, mode = "wb")
    message("Downloaded electricity data to: ", elec_file)
  }, error = function(e) {
    stop("Failed to download electricity data. Please download manually and place at: ", elec_file, "\nError: ", conditionMessage(e))
  })
}

# Load the file
electricity <- fread(elec_file)
message("Electricity data loaded. Rows: ", nrow(electricity), " Columns: ", ncol(electricity))


# ---- 1.3 NASA dataset ---- daily Weather 
nasa_file <- file.path(data_raw_dir, "nasa_data.json")
if (!file.exists(nasa_file)) {
  message("Downloading NASA dataset...")
  nasa_raw <- fromJSON("https://power.larc.nasa.gov/api/temporal/daily/point?parameters=T2M,PRECTOT&start=20150101&end=20250731&latitude=-20.3&longitude=57.5&community=AG&format=JSON")
  write_json(nasa_raw, nasa_file, pretty = TRUE, auto_unbox = TRUE)
} else {
  message("Loading NASA dataset from local file...")
  nasa_raw <- fromJSON(nasa_file, flatten = TRUE)
}

nasa_data <- data.table(
  date = as.Date(names(nasa_raw$properties$parameter$T2M), format = "%Y%m%d"),
  avg_temp = as.numeric(nasa_raw$properties$parameter$T2M),
  total_precip = as.numeric(nasa_raw$properties$parameter$PRECTOT)
)

# =============================
# 2. Initial Dataset Inspection
# =============================
# Crops
# str(crops)
# summary(crops)
# 
# Electricity
# str(electricity)
# summary(electricity)
# 
# NASA
# View(nasa_data)

# =============================
# 3. Filter Datasets for Mauritius (2015–2022)
# =============================
crops_mauritius <- crops %>% filter(area_code == 137 & year >= 2015 & year <= 2022)

electricity_mauritius <- electricity %>% filter(Island == "Island of Mauritius" & Year >= 2015 & Year <= 2022)

nasa_data <- nasa_data[year(date) >= 2015 & year(date) <= 2022]

# =============================
# 4. Standardize Data Types
# =============================
crops_mauritius <- crops_mauritius %>%
  mutate(across(c(area_code, item_code, element_code, year_code, year), as.integer),
         across(c(area_code_m49, area, item_code_cpc, item, element, unit, flag, note), as.character),
         value = as.numeric(value))

electricity_mauritius <- electricity_mauritius %>%
  mutate(Year = as.integer(Year),
         Island = as.character(Island),
         across(c(`Landfill gas`, Photovoltaic, Wind, Coal, Bagasse), as.numeric))

nasa_data <- nasa_data %>% mutate(avg_temp = as.numeric(avg_temp), total_precip = as.numeric(total_precip))

# =============================
# 5. Dataset Overview for Mauritius
# =============================
datasets <- list(Crops = crops_mauritius, Electricity = electricity_mauritius, NASA = nasa_data)

for (name in names(datasets)) {
  cat("\n====================", name, "====================\n")
  cat("Dimensions (rows x columns):", dim(datasets[[name]]), "\n")
  cat("Column names and types:\n"); print(str(datasets[[name]]))
  cat("Summary statistics:\n"); print(summary(datasets[[name]]))
  cat("Missing values per column:\n"); print(sapply(datasets[[name]], function(x) sum(is.na(x))))
  cat("Duplicate rows:", sum(duplicated(datasets[[name]])), "\n")
}

# =============================
# 6. Descriptive Statistics (skimr)
# =============================
cat("\n==================== Skim Summary ====================\n")
skim(datasets$Crops)
skim(datasets$Electricity)
skim(datasets$NASA)

# =============================
# 7. Quick Visualizations
# =============================
# Crops: Area Harvested over the Years - Filter for Sugarcane Yield (kg/ha)
sugarcane_yield <- crops_mauritius %>%
  filter(item == "Sugar cane", unit == "kg/ha") %>%
  group_by(year) %>%
  summarise(avg_yield_kg_per_ha = mean(value, na.rm = TRUE), .groups = "drop")

p_sugarcane_yield <- ggplot(sugarcane_yield, aes(x = year, y = avg_yield_kg_per_ha)) +
  geom_line(color = "goldenrod", size = 1.5) +
  geom_point(color = "darkorange", size = 3) +
  ggtitle("Average Sugarcane Yield per Year (Mauritius)") +
  xlab("Year") +
  ylab("Yield (kg/ha)") +
  scale_y_continuous(labels = comma) +   # readable Y-axis
  scale_x_continuous(breaks = sugarcane_yield$year) +
  theme_minimal()

ggsave(filename = file.path(report_plots_dir, "Sugarcane_Yield_Per_Year.png"),
       plot = p_sugarcane_yield, width = 8, height = 5)


# Electricity: time trend per energy source
electricity_long <- electricity_mauritius %>%
  pivot_longer(cols = c(`Landfill gas`, Photovoltaic, Wind, Coal, Bagasse), 
               names_to = "Source", values_to = "Value")

p2 <- ggplot(electricity_long, aes(x = Year, y = Value, color = Source)) +
  geom_line(size = 1) +
  geom_point() +
  ggtitle("Electricity Production by Source (Mauritius)") +
  ylab("Electricity Generation (GWh)") +          # <- Changed y-axis label
  theme_minimal()

ggsave(filename = file.path(report_plots_dir, "Electricity_Production_By_Source.png"), 
       plot = p2, width = 8, height = 5)


# NASA: Monthly averages
nasa_monthly <- nasa_data %>%
  mutate(year = year(date), month = month(date)) %>%
  group_by(year, month) %>%
  summarise(mean_temp = mean(avg_temp), total_precip = sum(total_precip), .groups = "drop")

p3 <- ggplot(nasa_monthly, aes(x = as.Date(paste(year, month, "01", sep = "-")), y = mean_temp)) +
  geom_line(color = "red") +
  ggtitle("Monthly Average Temperature in Mauritius") +
  xlab("Year") + ylab("Avg Temperature (°C)") +
  theme_minimal()
ggsave(filename = file.path(report_plots_dir, "NASA_Monthly_Avg_Temperature.png"), plot = p3, width = 8, height = 5)

p4 <- ggplot(nasa_monthly, aes(x = as.Date(paste(year, month, "01", sep = "-")), y = total_precip)) +
  geom_line(color = "blue") +
  ggtitle("Monthly Total Precipitation in Mauritius") +
  xlab("Year") + ylab("Total Precipitation (mm)") +
  theme_minimal()
ggsave(filename = file.path(report_plots_dir, "NASA_Monthly_Total_Precipitation.png"), plot = p4, width = 8, height = 5)

# =============================
# 8. Correlation Check (numeric columns only)
# ============================

library(dplyr)
library(ggplot2)
library(reshape2)  # for melt()

# Ensure directory exists
dir.create(report_plots_dir, recursive = TRUE, showWarnings = FALSE)

for (name in names(datasets)) {
  df <- datasets[[name]]
  
  # Select numeric columns safely
  nums <- df %>% select(where(is.numeric)) %>%
    select(where(~ !all(is.na(.)) && sd(., na.rm = TRUE) != 0))
  
  if (ncol(nums) > 1) {
    # Compute correlation matrix
    cor_matrix <- cor(nums, use = "complete.obs")
    
    # Convert to long format for ggplot
    cor_df <- reshape2::melt(cor_matrix, varnames = c("Variable1", "Variable2"), value.name = "Correlation")
    
    # Create plot
    p <- ggplot(cor_df, aes(x = Variable1, y = Variable2, fill = Correlation)) +
      geom_tile(color = "white") +
      geom_text(aes(label = round(Correlation, 2)), color = "black", size = 3) +
      scale_fill_gradient2(
        low = "blue", mid = "white", high = "red",
        midpoint = 0, limit = c(-1, 1), space = "Lab",
        name = "Correlation\n(-1 to +1)\nBlue = negative\nRed = positive\nWhite = no correlation"
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1),
        axis.text.y = element_text(size = 10),
        axis.title = element_blank()
      ) +
      coord_fixed() +
      ggtitle(paste("Correlation Matrix:", name))
    
    # Save plot
    ggsave(
      file.path(report_plots_dir, paste0(name, "_Correlation.png")),
      plot = p, width = 10, height = 8, dpi = 150
    )
    
    message("Saved correlation plot for ", name)
    
  } else {
    message("Skipping correlation for ", name, " — not enough numeric variation")
  }
}



# =============================
# 9. End of Preliminary Exploration
# =============================
cat("\nPreliminary exploration complete. All plots saved to:", report_plots_dir, "\n")



# saving dataset summaries
for (name in names(datasets)) {
  summary_file <- file.path(report_outputs_dir, paste0(name, "_summary.txt"))
  sink(summary_file)
  cat("\n====================", name, "====================\n")
  cat("Dimensions (rows x columns):", dim(datasets[[name]]), "\n")
  cat("Column names and types:\n"); print(str(datasets[[name]]))
  cat("Summary statistics:\n"); print(summary(datasets[[name]]))
  cat("Missing values per column:\n"); print(sapply(datasets[[name]], function(x) sum(is.na(x))))
  cat("Duplicate rows:", sum(duplicated(datasets[[name]])), "\n")
  sink()
}

# saving skimr outputs
for (name in names(datasets)) {
  skim_file <- file.path(report_outputs_dir, paste0(name, "_skim.txt"))
  capture.output(skim(datasets[[name]]), file = skim_file)
}


# Source pre-processing of missing values
source(file.path(current_r_dir, "02_data_stage_preprocessing.R"))
