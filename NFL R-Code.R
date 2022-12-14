#Install Packages
install.packages("tidyverse", type = "binary")
install.packages("ggrepel", type = "binary")
install.packages("ggimage", type = "binary")
install.packages("gt")

#Load Packages
library(tidyverse)
library(ggrepel)
library(ggimage)
library(ggplot2)
library(nflreadr)
library(caret)
library(gt)

#Round
options(scipen = 9999)

#Clear cache
nflreadr::.clear_cache()

#Read play by play data from nflfastR
pbp <- load_pbp(2016:2021)
pstat <- load_player_stats(2016:2021)
roster <- load_rosters(2016:2021) %>%
  filter(!is.na(gsis_id)) %>% 
  mutate(
    team = case_when(
      team == 'STL' ~ 'LA',
      team == 'SD' ~ 'LAC',
      team == 'OAK' ~ 'LV',
      TRUE ~ team
    )
  )

#Filter Roster data
nfl_ros <- roster %>%
  filter(!is.na(gsis_id)) %>%
  select(gsis_id, team, season, position)

#Filter Player Stats data
stats <- pstat %>%
  filter(!is.na(player_id)) %>%
  select(player_id, passing_yards, rushing_yards, receiving_yards, week)

#Filter by Regular Season Games and modify variables relating to temperature
Reg_data <- pbp %>%
  filter(season_type == "REG") %>%
  mutate(
    RoadTeam = as.factor(if_else(posteam == away_team, "Yes", "No")),
    Indoors = as.factor(if_else(roof == "closed" | roof == "dome", "Yes", "No")),
    HighAltitude = as.factor(if_else(home_team == "DEN", "Yes", "No")),
    NaturalGrass = as.factor(if_else(grepl("grass", surface, ignore.case = TRUE), "Yes", "No")),
    Precip = as.factor(case_when(
      grepl("closed", roof, ignore.case = TRUE) ~ "No",
      grepl("dome", roof, ignore.case = TRUE) ~ "No",
      grepl("snow", weather, ignore.case = TRUE) ~ "Yes",
      grepl("showers", weather, ignore.case = TRUE) ~ "Yes",
      grepl("0% Chance of Rain", weather, ignore.case = TRUE) ~ "No",
      grepl("Cloudy, chance of rain increasing up to 75%", weather, ignore.case = TRUE) ~ "Yes",
      grepl("Cloudy, chance of rain", weather, ignore.case = TRUE) ~ "No",
      grepl("Zero Percent Chance of Rain", weather, ignore.case = TRUE) ~ "No",
      grepl("Rain Chance 40", weather, ignore.case = TRUE) ~ "No",
      grepl("30% Chance of Rain", weather, ignore.case = TRUE) ~ "No",
      grepl("No chance of rain", weather, ignore.case = TRUE) ~ "No",
      grepl("Cloudy, Humid, Chance of Rain", weather, ignore.case = TRUE) ~ "No",
      grepl("rain", weather, ignore.case = TRUE) ~ "Yes",
      TRUE ~ "No"
    )),
    wind = case_when(
      is.na(wind) & roof != "outdoors" ~ 0,
      is.na(wind) & roof == "outdoors" ~ mean(wind),
      !is.na(wind) ~ as.numeric(wind),
      TRUE ~ 0
    ),
    temp = case_when(
      is.na(temp) & roof != "outdoors" ~ 70,
      is.na(temp) & roof == "outdoors" ~ mean(temp),
      !is.na(temp) ~ as.numeric(temp),
      TRUE ~ 0
    ),
    player_id = coalesce(
      rusher_player_id, passer_player_id
    )
  )
head(Reg_data)

nfl <- Reg_data

#####Filter by rush and pass plays
nfl_yds <- nfl %>%
  filter(rush == 1 | pass == 1, !is.na(posteam), !is.na(player_id)) %>%
  select(player_id, yards_gained, play_type, wind, Precip, temp, passing_yards, receiving_yards, rushing_yards, posteam, name, passer, rusher, receiver)
  

#####Join Roster Data
nfl_df <- nfl_yds %>%
  left_join(nfl_ros, by = c("player_id" = "gsis_id"))

####Join Stats data
nfl_stat <- stats %>%
  inner_join(nfl_ydss, by = c("player_id" = "player_id", "week" = "week"))

#####Filter by games with precipitation
nfl_yds_precip <- nfl %>%
  filter(rush == 1 | pass == 1, !is.na(posteam), Precip == "Yes") %>%
  select(yards_gained, game_id, season, div_game, name, passer, rusher, receiver, temp, Precip, passing_yards, receiving_yards, rushing_yards)

#####Filter by games without precipitation
nfl_yds_no_precip <- nfl %>%
  filter(rush == 1 | pass == 1, !is.na(posteam), Precip == "No") %>%
  select(yards_gained, game_id, season, div_game, name, passer, rusher, receiver, temp, Precip, passing_yards, receiving_yards, rushing_yards)


#Summary Statistics
summary (nfl_yds)

#scatter plot precip/no precip
nfl %>%
  ggplot(aes(x = yards_gained, y = temp, color = Precip)) +
  geom_point() +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(10, 95, by = 15), limits = c(10, 100), name = "Temperature") +
  theme(legend.position = "top") 
  
  
#Scatter plot wind
nfl_yds %>%
  ggplot(aes(x = yards_gained, y = wind)) +
  geom_point(color="darkslategray") +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(0, 140, by = 5), limits = c(0, 40), name = "Wind") +
  theme(legend.position = "top") +
  coord_flip()

#Histogram
nfl_yds %>%
  ggplot(aes(x = temp)) +
  geom_histogram(color="darkslategray") +
  theme(legend.position = "top")

#Scatter plot wind/Play Type
nfl_yds %>%
  ggplot(aes(x = yards_gained, y = wind, color = play_type)) +
  geom_point() +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(0, 140, by = 5), limits = c(10, 40), name = "Wind") +
  theme(legend.position = "top") +
  coord_flip()


#Scatter plot temp
nfl_yds %>%
  ggplot(aes(x = yards_gained, y = temp)) +
  geom_point(color="darkslategray") +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(10, 95, by = 15), limits = c(10, 100), name = "Temperature") +
  theme(legend.position = "top") +
  coord_flip()

#Scatter temp/play type
nfl_yds %>%
  ggplot(aes(x = yards_gained, y = temp, color =  play_type)) +
  geom_point() +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(10, 95, by = 15), limits = c(10, 100), name = "Temperature") +
  theme(legend.position = "top") +
  coord_flip()

#Scatter plot total w/o rain
nfl_yds_no_precip %>%
  ggplot(aes(x = yards_gained, y = temp)) +
  geom_point(color="darkorange3") +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(10, 95, by = 15), limits = c(10, 100), name = "Temperature") +
  theme(legend.position = "top") +
  coord_flip()

#Yards by Week
nfl %>%
  ggplot(aes(x = temp)) +
  geom_bar() +
  scale_x_continuous(breaks = seq(0, 100, by = 10), limits = c(0, 110), name = "Temp") +
  theme(legend.position = "top") 
  
#Yards by precip
nfl %>%
  select(yards_gained, Precip, week) %>%
  ggplot(aes(x = week, y = yards_gained, color = Precip)) +
  geom_bar() +
  theme(legend.position = "top")

#Scatter plot total w/ rain
nfl_yds_precip %>%
  ggplot(aes(x = yards_gained, y = temp)) +
  geom_point(color="darkblue") +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(10, 95, by = 15), limits = c(10, 100), name = "Temperature") +
  theme(legend.position = "top") +
  coord_flip()

#Box Plot Temp
nfl_yds %>%
  ggplot(aes(x = play_type, y = temp)) +
  geom_boxplot()

#Bar Play Type
nfl_yds %>%
  ggplot(aes(x = play_type)) +
  geom_bar()

#Rushing Yards
nfl_yds %>%
  ggplot(aes(x = rushing_yards, y = temp)) +
  geom_point(color="deepskyblue") +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(10, 95, by = 15), limits = c(10, 100), name = "Temperature") +
  theme(legend.position = "top") +
  coord_flip()

#Receiving Yards
nfl_yds %>%
  ggplot(aes(x = receiving_yards, y = temp)) +
  geom_point(color="darkblue") +
  scale_x_continuous(breaks = seq(10, 130, by = 10), limits = c(10, 130), name = "Distance") +
  scale_y_continuous(breaks = seq(10, 95, by = 15), limits = c(10, 100), name = "Temperature") +
  theme(legend.position = "top") +
  coord_flip()

#Field Goals Made/Missed Wind
nfl %>%
  ggplot(aes(x = kick_distance, y = wind, group = field_goal_result, color = field_goal_result)) +
  geom_point() +
  scale_x_continuous(breaks = seq(15, 60, by = 5), limits = c(15, 65), name = "Distance") +
  theme(legend.position = "top") +
  coord_flip()
    
#Field Goals Made/Missed Temp
nfl %>%
  ggplot(aes(x = kick_distance, y = temp, group = field_goal_result, color = field_goal_result)) +
  geom_point() +
  scale_x_continuous(breaks = seq(15, 60, by = 5), limits = c(15, 65), name = "Distance") +
  theme(legend.position = "top") +
  coord_flip()


######Creating Expected Yards Model

#Create Train and Test Data Split
set.seed(111)
train <- nfl_yds %>% sample_frac(.6)
test <- setdiff(nfl_yds, train)

#Create linear model using all variables
ttl_yds_model_all <- lm(yards_gained ~ play_type + wind + Precip + temp, data = train)
summary(ttl_yds_model_all)

#Predict using test set
pred_yards <- predict(ttl_yds_model_all, newdata = test)

#RMSE
rmse <- sqrt(sum((exp(pred_yards) - test$yards_gained)^2, na.rm = TRUE)/length(test$yards_gained))


c(RMSE = rmse, R2=summary(ttl_yds_model_all)$r.squared)

par(mfrow=c(1,1))
plot(test$yards_gained, exp(pred_yards))

#Model Fit to data
ggplot(data = train, aes(x = wind, y = yards_gained)) +
  geom_point() +
  stat_smooth(method = "lm", col = "dodgerblue3") +
  theme(panel.background = element_rect(fill = "white"),
        axis.line.x=element_line(),
        axis.line.y=element_line()) +
  ggtitle("Linear Model Fitted to Data")

plot(ttl_yds_model_all)


