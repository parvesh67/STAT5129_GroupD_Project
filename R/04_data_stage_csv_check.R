# -----------------------------
# Set data staging directory
# -----------------------------
data_dir <- data_stage_dir

# -----------------------------
# Read back all CSV files
# -----------------------------
dim_date_csv <- read_csv(file.path(data_dir, "dim_date.csv"), show_col_types = FALSE)
dim_item_csv <- read_csv(file.path(data_dir, "dim_item.csv"), show_col_types = FALSE)
dim_element_csv <- read_csv(file.path(data_dir, "dim_element.csv"), show_col_types = FALSE)
crop_production_csv <- read_csv(file.path(data_dir, "crop_production.csv"), show_col_types = FALSE)
weather_csv <- read_csv(file.path(data_dir, "weather.csv"), show_col_types = FALSE)
electricity_csv <- read_csv(file.path(data_dir, "electricity_generation.csv"), show_col_types = FALSE)

# -----------------------------
# 1. Compare counts
# -----------------------------
cat("\n===== Row Counts Comparison =====\n")
cat("Crops original:", nrow(crops_mauritius), " | crop_production CSV:", nrow(crop_production_csv), "\n")
cat("Electricity original:", nrow(electricity_mauritius), " | electricity CSV:", nrow(electricity_csv), "\n")
cat("NASA original (rows):", nrow(nasa_data), " | weather CSV rows:", nrow(weather_csv), "\n")
cat("dim_date rows:", nrow(dim_date_csv), " (yearly, monthly, daily counts):\n")
print(table(dim_date_csv$aggregation_level))

# -----------------------------
# 1b. Unit comparison
# Compare unit per element between original crops and dim_element CSV
# -----------------------------
orig_element_units <- crops_mauritius %>%
  group_by(element_code) %>%
  summarise(orig_unit = if (length(na.omit(unit))>0) na.omit(unit)[1] else NA_character_, .groups = "drop")

element_unit_check <- dim_element_csv %>%
  select(element_code, element, unit) %>%
  left_join(orig_element_units, by = "element_code") %>%
  mutate(unit_match = ifelse(is.na(orig_unit) & is.na(unit), TRUE,
                             ifelse(is.na(orig_unit) | is.na(unit), FALSE,
                                    trimws(unit) == trimws(orig_unit))))

cat("\n===== Element unit comparison (dim_element vs original crops) =====\n")
cat("Total elements:", nrow(element_unit_check), "\n")
cat("Units matching:", sum(element_unit_check$unit_match, na.rm = TRUE), "\n")
cat("Units mismatching:", sum(!element_unit_check$unit_match, na.rm = TRUE), "\n")
if (any(!element_unit_check$unit_match, na.rm = TRUE)) {
  cat("Samples of mismatches:\n")
  print(filter(element_unit_check, !unit_match) %>% select(element_code, element, orig_unit, unit) %>% head(10))
}

# -----------------------------
# 2. Compare Crop Production (UPDATED: no unit column in CSV)
# We join by date_id -> period_start -> original crops' period_start
# -----------------------------
crop_check <- crop_production_csv %>%
  left_join(dim_date_csv %>% filter(aggregation_level == "yearly") %>% select(date_id, period_start),
            by = "date_id") %>%
  # bring original data's period_start for matching
  left_join(crops_mauritius %>% mutate(period_start = as.Date(paste0(year, "-01-01"))),
            by = c("item_code", "element_code", "period_start"),
            suffix = c("_csv", "_orig"))

# Count rows where original join failed (missing original row)
missing_orig <- sum(is.na(crop_check$year))
# Now check value mismatches (where both present)
value_mismatch <- crop_check %>%
  filter(!is.na(value_csv) & !is.na(value_orig) & (abs(value_csv - value_orig) > .Machine$double.eps^0.5)) %>%
  nrow()
flag_mismatch <- crop_check %>%
  filter(!is.na(flag_csv) & !is.na(flag_orig) & trimws(flag_csv) != trimws(flag_orig)) %>%
  nrow()

cat("\nCrops: rows with no matching original row after join (by item_code, element_code, period_start):", missing_orig, "\n")
cat("Crops: value mismatches (csv vs original):", value_mismatch, "\n")
cat("Crops: flag mismatches (csv vs original):", flag_mismatch, "\n")

# Show a few sample mismatches (if any)
if (value_mismatch > 0) {
  cat("Sample value mismatches:\n")
  print(crop_check %>%
          filter(!is.na(value_csv) & !is.na(value_orig) & (abs(value_csv - value_orig) > .Machine$double.eps^0.5)) %>%
          select(item_code, element_code, period_start, value_csv, value_orig) %>%
          head(10))
}

# -----------------------------
# 3. Compare Electricity Generation
# -----------------------------
electricity_check <- electricity_csv %>%
  left_join(dim_date_csv %>% filter(aggregation_level == "yearly") %>% select(date_id, period_start),
            by = "date_id") %>%
  left_join(electricity_mauritius %>% mutate(period_start = as.Date(paste0(Year, "-01-01"))),
            by = "period_start",
            suffix = c("_csv", "_orig"))

cat("\nElectricity: mismatches after join (rows with no matching original Year entry):", sum(is.na(electricity_check$Year)), "\n")

# Check numeric column totals (quick sanity)
elec_orig_totals <- colSums(select(electricity_mauritius, `Landfill gas`, Photovoltaic, Wind, Coal, Bagasse), na.rm = TRUE)
elec_csv_totals <- colSums(select(electricity_csv, landfill_gas, photovoltaic, wind, coal, bagasse), na.rm = TRUE)
cat("Electricity totals comparison (original vs csv):\n")
print(data.frame(original = elec_orig_totals, csv = elec_csv_totals))

# -----------------------------
# 4. Compare Weather (daily)
# -----------------------------
weather_daily_check <- weather_csv %>%
  left_join(dim_date_csv %>% filter(aggregation_level == "daily") %>% select(date_id, period_start),
            by = "date_id") %>%
  left_join(nasa_data %>% rename(period_start = date),
            by = "period_start",
            suffix = c("_csv", "_orig"))

cat("\nWeather daily: rows with no matching original daily record:", sum(is.na(weather_daily_check$avg_temp_orig)), "\n")

# -----------------------------
# 5. Summary statistics comparison
# -----------------------------
cat("\n===== Summary Statistics Comparison =====\n")

# Crops
cat("\nCrops value range:\n")
cat("Original: min =", min(crops_mauritius$value, na.rm = TRUE),
    "max =", max(crops_mauritius$value, na.rm = TRUE), "\n")
cat("CSV: min =", min(crop_production_csv$value, na.rm = TRUE),
    "max =", max(crop_production_csv$value, na.rm = TRUE), "\n")

# Electricity (already printed above but include again)
cat("\nElectricity totals (repeated):\n")
print(data.frame(original = elec_orig_totals, csv = elec_csv_totals))

# Weather (daily)
cat("\nWeather daily averages:\n")
daily_ids <- dim_date_csv$date_id[dim_date_csv$aggregation_level == "daily"]
cat("Original avg_temp mean =", mean(nasa_data$avg_temp, na.rm = TRUE),
    " | CSV avg_temp mean =", mean(weather_csv$avg_temp[weather_csv$date_id %in% daily_ids], na.rm = TRUE), "\n")
cat("Original total_precip sum =", sum(nasa_data$total_precip, na.rm = TRUE),
    " | CSV total_precip sum =", sum(weather_csv$total_precip[weather_csv$date_id %in% daily_ids], na.rm = TRUE), "\n")

# -----------------------------
# 6. Count per aggregation level for weather
# -----------------------------
cat("\nWeather counts by aggregation level:\n")
weather_counts <- weather_csv %>%
  left_join(dim_date_csv %>% select(date_id, aggregation_level), by = "date_id") %>%
  group_by(aggregation_level) %>%
  summarise(n_rows = n(), .groups = "drop")
print(weather_counts)

# -----------------------------
# 7. Missing values in CSVs
# -----------------------------
cat("\n===== Missing Values in CSVs =====\n")
csv_list <- list(dim_date_csv, dim_item_csv, dim_element_csv, crop_production_csv, weather_csv, electricity_csv)
csv_names <- c("dim_date", "dim_item", "dim_element", "crop_production", "weather", "electricity_generation")

for (i in seq_along(csv_list)) {
  cat("\n", csv_names[i], ":\n", sep = "")
  print(colSums(is.na(csv_list[[i]])))
}

cat("\nFull comparison complete: row counts, joins, summary stats, unit checks, and missing values checked.\n")
message("DataStage CSV Check Complete!")




# -----------------------------
# Save all validation outputs
# -----------------------------
row_counts <- data.frame(
  Dataset = c("Crops", "Crop Production CSV", "Electricity", "Electricity CSV", "NASA", "Weather CSV"),
  Rows = c(nrow(crops_mauritius), nrow(crop_production_csv),
           nrow(electricity_mauritius), nrow(electricity_csv),
           nrow(nasa_data), nrow(weather_csv))
)
write.csv(row_counts, file.path(validation_dir, "row_counts_comparison.csv"), row.names = FALSE)

write.csv(element_unit_check, file.path(validation_dir, "element_unit_comparison.csv"), row.names = FALSE)
write.csv(crop_check, file.path(validation_dir, "crop_production_check.csv"), row.names = FALSE)
write.csv(electricity_check, file.path(validation_dir, "electricity_check.csv"), row.names = FALSE)
write.csv(weather_daily_check, file.path(validation_dir, "weather_daily_check.csv"), row.names = FALSE)

summary_stats <- data.frame(
  Dataset = c("Crops value", "Crop Production CSV", "Electricity total (original)", "Electricity total (CSV)",
              "Weather avg_temp (original)", "Weather avg_temp (CSV)",
              "Weather total_precip (original)", "Weather total_precip (CSV)"),
  Value = c(min(crops_mauritius$value, na.rm=TRUE), min(crop_production_csv$value, na.rm=TRUE),
            sum(elec_orig_totals), sum(elec_csv_totals),
            mean(nasa_data$avg_temp, na.rm=TRUE),
            mean(weather_csv$avg_temp[weather_csv$date_id %in% daily_ids], na.rm=TRUE),
            sum(nasa_data$total_precip, na.rm=TRUE),
            sum(weather_csv$total_precip[weather_csv$date_id %in% daily_ids], na.rm=TRUE))
)
write.csv(summary_stats, file.path(validation_dir, "summary_statistics_comparison.csv"), row.names = FALSE)





source(file.path(current_r_dir, "05_studymodel_bagasse.R"))

