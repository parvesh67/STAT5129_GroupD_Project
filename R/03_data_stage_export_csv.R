# =============================
# Mauritius -> CSV Export (schema-ready) — UPDATED: unit moved to dim_element
# =============================

data_dir <- data_stage_dir
dir.create(data_dir, showWarnings = FALSE)
# =============================
# 1. dim_date
# =============================
# yearly from crops + electricity
yearly_dates <- unique(c(crops_mauritius$year, electricity_mauritius$Year))
dim_date_yearly <- data.frame(
  period_start = as.Date(paste0(yearly_dates, "-01-01")),
  aggregation_level = "yearly"
)

# monthly from NASA
monthly_dates <- unique(floor_date(nasa_data$date, "month"))
dim_date_monthly <- data.frame(
  period_start = monthly_dates,
  aggregation_level = "monthly"
)

# daily from NASA
daily_dates <- unique(nasa_data$date)
dim_date_daily <- data.frame(
  period_start = daily_dates,
  aggregation_level = "daily"
)

# Combine all, remove duplicates, arrange, and add date_id
dim_date <- bind_rows(dim_date_yearly, dim_date_monthly, dim_date_daily) %>%
  distinct() %>%
  arrange(period_start, aggregation_level) %>%
  mutate(date_id = row_number()) %>%
  select(date_id, everything())  # move date_id to first column

write.csv(dim_date, file.path(data_dir, "dim_date.csv"), row.names = FALSE)


# =============================
# 2. dim_item
# =============================
dim_item <- crops_mauritius %>%
  distinct(item_code, item) %>%
  mutate(item = substr(item, 1, 200))

write.csv(dim_item, file.path(data_dir, "dim_item.csv"), row.names = FALSE)


# =============================
# 3. dim_element
# =============================
dim_element <- crops_mauritius %>%
  select(element_code, element, unit) %>%
  group_by(element_code, element) %>%
  summarise(
    unit = if (length(na.omit(unit)) > 0) na.omit(unit)[1] else NA_character_,
    .groups = "drop"
  ) %>%
  mutate(element = substr(element, 1, 100),
         unit = substr(unit, 1, 50)) %>%
  arrange(element_code)

write.csv(dim_element, file.path(data_dir, "dim_element.csv"), row.names = FALSE)


# =============================
# 4. crop_production
# =============================
crop_production <- crops_mauritius %>%
  mutate(period_start = as.Date(paste0(year, "-01-01"))) %>%
  left_join(
    dim_date %>% filter(aggregation_level == "yearly") %>% select(date_id, period_start),
    by = "period_start"
  ) %>%
  # remove unit from output; dim_element holds the unit now
  select(item_code, element_code, date_id, value, flag, note)

write.csv(crop_production, file.path(data_dir, "crop_production.csv"), row.names = FALSE)


# =============================
# 5. weather 
# =============================

# Daily
weather_daily <- nasa_data %>%
  rename(period_start = date) %>%
  left_join(
    dim_date %>% filter(aggregation_level == "daily") %>% select(date_id, period_start),
    by = "period_start"
  ) %>%
  select(date_id, avg_temp, total_precip)

# Monthly aggregation
weather_monthly <- nasa_data %>%
  mutate(period_start = floor_date(date, "month")) %>%
  group_by(period_start) %>%
  summarise(
    avg_temp = mean(avg_temp, na.rm = TRUE),
    total_precip = sum(total_precip, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(
    dim_date %>% filter(aggregation_level == "monthly") %>% select(date_id, period_start),
    by = "period_start"
  ) %>%
  select(date_id, avg_temp, total_precip)

# Yearly aggregation
weather_yearly <- nasa_data %>%
  mutate(period_start = as.Date(paste0(year(date), "-01-01"))) %>%
  group_by(period_start) %>%
  summarise(
    avg_temp = mean(avg_temp, na.rm = TRUE),
    total_precip = sum(total_precip, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(
    dim_date %>% filter(aggregation_level == "yearly") %>% select(date_id, period_start),
    by = "period_start"
  ) %>%
  select(date_id, avg_temp, total_precip)

# Combine all
weather_all <- bind_rows(weather_daily, weather_monthly, weather_yearly) %>%
  arrange(date_id)

write.csv(weather_all, file.path(data_dir, "weather.csv"), row.names = FALSE)

#save
weather_all_export <- weather_all %>%
  mutate(across(where(is.numeric), ~round(., 2)))

write.csv(weather_all_export,
          file.path(report_outputs_dir, "nasa_weather_all.csv"),
          row.names = FALSE)



# =============================
# 6. electricity_generation (yearly)
# =============================
electricity_generation <- electricity_mauritius %>%
  mutate(period_start = as.Date(paste0(Year, "-01-01"))) %>%
  left_join(dim_date %>% filter(aggregation_level == "yearly") %>% select(date_id, period_start),
            by = "period_start") %>%
  select(date_id, `Landfill gas`, Photovoltaic, Wind, Coal, Bagasse) %>%
  rename(
    landfill_gas = `Landfill gas`,
    photovoltaic = Photovoltaic,
    wind = Wind,
    coal = Coal,
    bagasse = Bagasse
  )

write.csv(electricity_generation, file.path(data_dir, "electricity_generation.csv"), row.names = FALSE)

cat("All CSV files exported successfully to:", data_dir, "\n")




source(file.path(current_r_dir, "04_data_stage_csv_check.R"))
