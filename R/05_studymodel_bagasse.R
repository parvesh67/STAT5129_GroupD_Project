# ==============================
# Climate → Sugarcane → Energy Model (Mauritius)
# ==============================

# --- 2. Extract Data ---

# 2.1 Bagasse (Electricity)
bagasse_df <- dbGetQuery(con, "
  SELECT YEAR(d.period_start) AS year, SUM(eg.bagasse) AS bagasse
  FROM electricity_generation eg
  JOIN dim_date d ON eg.date_id = d.date_id
  WHERE d.aggregation_level = 'yearly'
    AND d.period_start BETWEEN '2015-01-01' AND '2022-12-31'
  GROUP BY YEAR(d.period_start)
  ORDER BY year;
")

# 2.2 Sugarcane Production (tonnes)
sugarcane_prod_df <- dbGetQuery(con, "
  SELECT YEAR(d.period_start) AS year, SUM(c.value) AS sugarcane_prod
  FROM crop_production c
  JOIN dim_date d ON c.date_id = d.date_id
  JOIN dim_element e ON c.element_code = e.element_code
  WHERE d.aggregation_level = 'yearly'
    AND e.element = 'Production'
    AND c.item_code = (SELECT item_code FROM dim_item WHERE item = 'Sugar cane')
  GROUP BY YEAR(d.period_start)
  ORDER BY year;
")

# 2.3 Sugarcane Area Harvested (hectares)
sugarcane_area_df <- dbGetQuery(con, "
  SELECT YEAR(d.period_start) AS year, SUM(c.value) AS area_harvested
  FROM crop_production c
  JOIN dim_date d ON c.date_id = d.date_id
  JOIN dim_element e ON c.element_code = e.element_code
  WHERE d.aggregation_level = 'yearly'
    AND e.element = 'Area harvested'
    AND c.item_code = (SELECT item_code FROM dim_item WHERE item = 'Sugar cane')
  GROUP BY YEAR(d.period_start)
  ORDER BY year;
")

# 2.4 Weather (daily → yearly)
weather_daily <- dbGetQuery(con, "
  SELECT 
    d.period_start AS date,
    w.total_precip,
    w.avg_temp
  FROM weather w
  JOIN dim_date d ON w.date_id = d.date_id
  WHERE d.aggregation_level = 'daily'
    AND d.period_start BETWEEN '2015-01-01' AND '2022-12-31'
")

weather_daily$date <- as.Date(weather_daily$date)

# --- 3. Aggregate Weather Data ---

# 3.1 Average temperature per year
avg_temp_year <- weather_daily %>%
  mutate(year = year(date)) %>%
  group_by(year) %>%
  summarise(avg_temp = mean(avg_temp, na.rm = TRUE))

# 3.2 Total rainfall during harvest (May–Sept)
harvest_rain <- weather_daily %>%
  mutate(year = year(date), month = month(date)) %>%
  filter(month >= 5 & month <= 9) %>%
  group_by(year) %>%
  summarise(precip_harvest = sum(total_precip, na.rm = TRUE)) %>%
  ungroup()

# --- 4. Merge & Compute Yield ---

sugarcane_yield_df <- sugarcane_prod_df %>%
  left_join(sugarcane_area_df, by = "year") %>%
  mutate(sugarcane_yield = sugarcane_prod / area_harvested)

df <- bagasse_df %>%
  left_join(sugarcane_yield_df, by = "year") %>%
  left_join(harvest_rain, by = "year") %>%
  left_join(avg_temp_year, by = "year")

# --- 5. Rescale Data ---
df_scaled <- df %>%
  mutate(across(
    c(bagasse, sugarcane_yield, sugarcane_prod, avg_temp, precip_harvest, area_harvested),
    scale,
    .names = "{.col}_scaled"
  ))

# --- 6. Two-Stage Modeling ---

## Stage 1: Climate → Sugarcane Yield
model_stage1 <- lm(sugarcane_yield_scaled ~ avg_temp_scaled + precip_harvest_scaled, data = df_scaled)
cat("\n===== Stage 1: Climate → Sugarcane Yield =====\n")
summary(model_stage1)

## Stage 1b (alternative): Climate + Area → Sugarcane Production
model_stage1b <- lm(sugarcane_prod_scaled ~ avg_temp_scaled + precip_harvest_scaled + area_harvested_scaled, data = df_scaled)
cat("\n===== Stage 1b: Climate + Area → Sugarcane Production =====\n")
summary(model_stage1b)

## Stage 2: Sugarcane Yield → Bagasse (Energy Output)
model_stage2 <- lm(bagasse_scaled ~ poly(year, 2) + sugarcane_yield_scaled, data = df_scaled)
cat("\n===== Stage 2: Sugarcane Yield → Bagasse =====\n")
summary(model_stage2)

# --- 7. Diagnostics (optional)
par(mfrow = c(2, 2))
plot(model_stage1)
plot(model_stage2)

sink(file.path(analysis_outputs_dir, "model_stage1_summary.txt"))
cat("===== Stage 1: Climate → Sugarcane Yield =====\n")
print(summary(model_stage1))
sink()

sink(file.path(analysis_outputs_dir, "model_stage1b_summary.txt"))
cat("===== Stage 1b: Climate + Area → Sugarcane Production =====\n")
print(summary(model_stage1b))
sink()

sink(file.path(analysis_outputs_dir, "model_stage2_summary.txt"))
cat("===== Stage 2: Sugarcane Yield → Bagasse =====\n")
print(summary(model_stage2))
sink()

# -----------------------------
# 2. Save diagnostic plots in the same folder
# -----------------------------
png(file.path(analysis_outputs_dir, "Stage1_Climate_Sugarcane_Yield.png"), width = 1200, height = 800, res = 150)
par(mfrow = c(2,2))
plot(model_stage1)
dev.off()

png(file.path(analysis_outputs_dir, "Stage2_Sugarcane_Yield_Bagasse.png"), width = 1200, height = 800, res = 150)
par(mfrow = c(2,2))
plot(model_stage2)
dev.off()



source(file.path(current_r_dir, "06_studymodel_photovoltaic.R"))

