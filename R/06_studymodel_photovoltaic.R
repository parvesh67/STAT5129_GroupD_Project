
# ==============================
# Photovoltaic 
# ==============================

# Pull daily weather
weather_daily <- dbGetQuery(con, "
  SELECT d.period_start AS date, w.avg_temp, w.total_precip
  FROM weather w JOIN dim_date d ON w.date_id = d.date_id
  WHERE d.aggregation_level = 'daily' AND d.period_start BETWEEN '2015-01-01' AND '2022-12-31'
") %>% mutate(date = as.Date(date))

# Monthly aggregates needed for SPI and harvest-season sums
weather_monthly <- weather_daily %>%
  mutate(year = year(date), month = month(date)) %>%
  group_by(year, month) %>%
  summarise(total_precip = sum(total_precip, na.rm=TRUE),
            mean_temp = mean(avg_temp, na.rm=TRUE)) %>%
  ungroup() %>%
  arrange(year, month) %>%
  mutate(ym = as.yearmon(paste(year, month), "%Y %m"))

# 1-month SPI on monthly totals
precip_ts <- ts(weather_monthly$total_precip, start = c(min(weather_monthly$year), min(weather_monthly$month)), frequency = 12)
spi1 <- spi(precip_ts, 1)
weather_monthly$spi1 <- as.numeric(spi1$fitted)

# Identify months with SPI <= -1
weather_monthly <- weather_monthly %>% mutate(drought_month = ifelse(spi1 <= -1,1,0))

# Compute max consecutive dry days (CDD) by year
weather_daily <- weather_daily %>%
  arrange(date) %>%
  mutate(is_dry = ifelse(total_precip == 0, 1, 0))

# Compute run lengths of dry days
r <- rle(weather_daily$is_dry)
ends <- cumsum(r$lengths)
starts <- ends - r$lengths + 1
runs <- data.frame(start_idx = starts, end_idx = ends, length = r$lengths, value = r$values)

# Annotate years
runs <- runs %>% filter(value == 1)
runs$start_date <- weather_daily$date[runs$start_idx]
runs$end_date <- weather_daily$date[runs$end_idx]
runs$year <- year(runs$start_date)

# For runs crossing years, split (simple approach)
# Aggregate max CDD per year
max_cdd_per_year <- runs %>% group_by(year) %>% summarise(max_cdd = max(length)) %>% ungroup()

# Yearly extreme counts: hot days (top 5% daily temp across full period)
temp_thresh <- quantile(weather_daily$avg_temp, probs = 0.95, na.rm = TRUE)
hot_days <- weather_daily %>% mutate(is_hot = ifelse(avg_temp >= temp_thresh,1,0)) %>%
  group_by(year = year(date)) %>% summarise(hot_days_95 = sum(is_hot, na.rm=TRUE)) %>% ungroup()

# Yearly SPI drought months summary
spi_yearly <- weather_monthly %>% group_by(year) %>% summarise(drought_months = sum(drought_month, na.rm=TRUE)) %>% ungroup()

# Yearly totals and join everything
yearly_basic <- weather_monthly %>% group_by(year) %>% summarise(total_precip_year = sum(total_precip, na.rm=TRUE),
                                                                  mean_temp_year = mean(mean_temp, na.rm=TRUE)) %>% ungroup()

# Step 1: Get the photovoltaic data (from the SQL query logic)
photovoltaic_data <- electricity_generation %>%
  left_join(dim_date, by = "date_id") %>%
  filter(aggregation_level == 'yearly' & period_start >= '2015-01-01' & period_start <= '2022-12-31') %>%
  group_by(year = year(period_start)) %>%
  summarise(total_photovoltaic = sum(photovoltaic, na.rm = TRUE))

# Step 2: Join the other datasets
weather_yearly_extremes <- yearly_basic %>%
  left_join(max_cdd_per_year, by = "year") %>%
  left_join(hot_days, by = "year") %>%
  left_join(spi_yearly, by = "year") %>%
  left_join(photovoltaic_data, by = "year") %>%
  mutate(
    max_cdd = ifelse(is.na(max_cdd), 0, max_cdd),
    hot_days_95 = ifelse(is.na(hot_days_95), 0, hot_days_95),
    drought_months = ifelse(is.na(drought_months), 0, drought_months)
  )

weather_yearly_extremes <- weather_yearly_extremes %>%
  select(year, total_photovoltaic, total_precip_year, mean_temp_year, max_cdd, hot_days_95, drought_months) %>%
  rename(photovoltaic = total_photovoltaic)

# View the final dataset
# View(weather_yearly_extremes)

# assume elec_yearly df with columns year, photovoltaic, landfill_gas, bagasse, coal, wind
# example outlier detection function:
detect_outliers_yearly <- function(x) {
  x_no_na <- na.omit(x)
  Q1 <- quantile(x_no_na, .25)
  Q3 <- quantile(x_no_na, .75)
  IQR <- Q3 - Q1
  lower <- Q1 - 1.5*IQR
  upper <- Q3 + 1.5*IQR
  med <- median(x_no_na)
  madv <- mad(x_no_na, constant = 1)
  iqr_flag <- (x < lower) | (x > upper)
  mad_flag <- abs(x - med)/madv > 3
  return(list(iqr_flag = iqr_flag, mad_flag = mad_flag, lower = lower, upper = upper))
}

fit1 <- lm(photovoltaic ~ mean_temp_year + total_precip_year + hot_days_95 + max_cdd, data = weather_yearly_extremes)
summary(fit1)

fit2 <- lm(photovoltaic ~ mean_temp_year + total_precip_year, data = weather_yearly_extremes)
summary(fit2)

# Compute predicted values
weather_yearly_extremes$predicted <- predict(fit1)

# Plot observed vs. predicted
library(ggplot2)
# --- 1. Actual vs Predicted Plot ---
p1 <- ggplot(weather_yearly_extremes, aes(x = photovoltaic, y = predicted)) +
  geom_point(size = 3, color = "steelblue") +
  geom_smooth(method = "lm", se = FALSE, color = "darkred", linetype = "dashed") +
  geom_abline(intercept = 0, slope = 1, color = "gray50", linetype = "dotted") +
  labs(
    title = "Actual vs Predicted Photovoltaic Generation",
    x = "Actual Photovoltaic (MWh or kWh)",
    y = "Predicted Photovoltaic"
  ) +
  theme_minimal(base_size = 13)

ggsave(filename = file.path(analysis_outputs_dir, "Actual_vs_Predicted_Photovoltaic.png"), plot = p1, width = 8, height = 6, dpi = 150)
message("Saved: Actual vs Predicted Photovoltaic plot.")

# --- 2. Residuals vs Fitted Values ---
p2 <- ggplot(weather_yearly_extremes, aes(x = predicted, y = residuals(fit1))) +
  geom_point(size = 3, color = "orange") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(
    title = "Residuals vs Fitted Values",
    x = "Predicted Photovoltaic",
    y = "Residuals"
  ) +
  theme_minimal(base_size = 13)

ggsave(filename = file.path(analysis_outputs_dir, "Residuals_vs_Fitted.png"), plot = p2, width = 8, height = 6, dpi = 150)
message("Saved: Residuals vs Fitted plot.")

# --- 3. Relationship with Each Predictor ---
weather_long <- weather_yearly_extremes |>
  tidyr::pivot_longer(
    cols = c(mean_temp_year, total_precip_year, hot_days_95, max_cdd),
    names_to = "variable", values_to = "value"
  )

p3 <- ggplot(weather_long, aes(x = value, y = photovoltaic)) +
  geom_point(color = "steelblue", size = 3) +
  geom_smooth(method = "lm", se = FALSE, color = "darkred") +
  facet_wrap(~ variable, scales = "free_x") +
  labs(
    title = "Relationship Between Weather Variables and Photovoltaic Generation",
    x = "Weather Variable Value",
    y = "Photovoltaic Generation"
  ) +
  theme_minimal(base_size = 13)

ggsave(filename = file.path(analysis_outputs_dir, "Weather_vs_Photovoltaic.png"), plot = p3, width = 10, height = 6, dpi = 150)
message("Saved: Weather vs Photovoltaic plot.")

# -----------------------------
# 1. Save yearly aggregated dataset
# -----------------------------
write.csv(weather_yearly_extremes,
          file.path(analysis_outputs_dir, "photovoltaic_yearly_extremes.csv"),
          row.names = FALSE)

# -----------------------------
# 2. Save model summaries
# -----------------------------
sink(file.path(analysis_outputs_dir, "photovoltaic_model_summary.txt"))
cat("=== Fit 1: Full Model ===\n")
print(summary(fit1))
cat("\n=== Fit 2: Simple Model ===\n")
print(summary(fit2))
sink()



message("Analysis Completed!")
