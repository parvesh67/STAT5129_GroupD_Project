# ==============================
# Data Cleaning & Preprocessing with Before/After Diagnostics
# ==============================

# backup for testing
# electricity_backup <- electricity_mauritius
# electricity_mauritius <- electricity_backup

# ------------------------------
# 1. Crops Dataset: Remove rows where values are missing (flag == "M")
# ------------------------------
cat("\n--- Crops: Removing structural missing values ---\n")
cat("Before removal: ", nrow(crops_mauritius), "rows\n")

# Keep a copy of rows that will be removed for reference
crops_missing_rows <- crops_mauritius %>% filter(flag == "M")
if(nrow(crops_missing_rows) > 0){
  cat("Rows with structural missing values (flag 'M'):\n")
  print(crops_missing_rows)
}

# Remove rows
crops_mauritius <- crops_mauritius %>%
  filter(flag != "M")
cat("After removal: ", nrow(crops_mauritius), "rows\n")


# Recheck missing values after crops removal
cat("\n--- Rechecking Missing Values After Cleaning ---\n")
cat("\nCrops Dataset:\n")
print(sapply(crops_mauritius, function(x) sum(is.na(x))))


# ----------------------------------------------------
# Electricity Dataset - electricity generation (kWh) by source of energy 
# ----------------------------------------------------

# 1) Missingness Diagnostics for Wind - electricity dataset
# Check if missingness relates to other variables (potential MAR)
electricity_mauritius %>%
  mutate(wind_missing = is.na(Wind)) %>%
  group_by(wind_missing) %>%
  summarise(
    mean_landfill = mean(`Landfill gas`, na.rm = TRUE),
    mean_pv       = mean(Photovoltaic, na.rm = TRUE)
  )

# Interpretation:
# When Wind is missing (2015), Photovoltaic is much lower (~23.7 vs ~89.5)
# Landfill gas is similar (~20). 
# => Missingness likely related to early reporting years with low PV.
# => Depends on observed PV → Missing At Random (MAR), not MCAR.

# Little's MCAR test
mcar_test(select(electricity_mauritius, Wind, `Landfill gas`, Photovoltaic, Coal, Bagasse))
# p = 0.391 (>0.05) → fail to reject MCAR, but contextual evidence (low PV) suggests MAR.

# ----------------------------------------------------
# 2) Imputation of Wind
# ----------------------------------------------------

# Median imputation (robust for one-off missing at the start)
# Justification:
# - Only one missing value at start of series
# - Median robust to outliers and preserves trend

electricity_mauritius <- electricity_mauritius %>%
  mutate(
    wind_imp_flag = as.integer(is.na(Wind)),            # mark imputed row
    Wind = ifelse(is.na(Wind), median(Wind, na.rm=TRUE), Wind) # replace NA with median
  )

# ----------------------------------------------------
# 3) Validation
# ----------------------------------------------------

# Check imputed row
electricity_mauritius %>% filter(wind_imp_flag == 1)

# plot
df_long <- electricity_mauritius %>%
  select(Year, Wind, wind_imp_flag) %>%
  mutate(Wind_original = ifelse(wind_imp_flag == 1, NA, Wind)) %>%
  pivot_longer(
    cols = c(Wind_original, Wind),
    names_to = "type",
    values_to = "Wind_value"
  ) %>%
  mutate(type = dplyr::recode(type,
                              "Wind_original" = "Original",
                              "Wind" = "Imputed"))



p_wind <- ggplot(df_long, aes(x = Year, y = Wind_value, color = type)) +
  geom_line(size = 1.2, na.rm = TRUE) +  # only lines, skip NAs
  ggtitle("Electricity Generation: Wind (Original vs Imputed)") +
  ylab(expression("Electricity Generation (GWh)")) +
  scale_color_discrete(labels = c("Imputed", "Original")) +
  guides(color = guide_legend(override.aes = list(linetype = 1, shape = NA, size = 1.2))) +
  theme_minimal()

ggsave(filename = file.path(report_plots_dir, "Wind_Imputation_Plot.png"),plot = p_wind, width = 8,height = 5)

# ----------------------------------------------------
# 4) Decision Justification
# ----------------------------------------------------
# Median chosen because:
# - Only 1 missing value → small sample → simpler method preferred
# - Stable and unbiased for single-value imputation
# - MAR assumption acceptable as missingness depends on Photovoltaic
# - Imputation flag retained for transparency

# ----------------------------------------------------
# 5) Updated electricity_mauritius dataframe
# ----------------------------------------------------
electricity_mauritius


# saving datasets after filtering/cleaning/imputation
write.csv(crops_mauritius, file.path(report_outputs_dir, "crops_mauritius_clean.csv"), row.names = FALSE)
write.csv(electricity_mauritius, file.path(report_outputs_dir, "electricity_mauritius_clean.csv"), row.names = FALSE)
write.csv(electricity_mauritius %>% filter(wind_imp_flag == 1),
          file.path(report_outputs_dir, "electricity_wind_imputed_row.csv"), row.names = FALSE)


source(file.path(current_r_dir, "03_data_stage_export_csv.R"))