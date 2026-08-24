# Build school_year_start.csv from World Bank / UIS indicator
# UIS.YR.ST.MON.01T5 (start month, pre-primary to post-secondary non-tertiary).
library(jsonlite)
library(dplyr)
library(readr)

uis <- fromJSON("analysis/_uis_start.json", simplifyDataFrame = TRUE)[[2]] %>%
  as_tibble() %>%
  transmute(
    country_iso3 = countryiso3code,
    uis_year = as.integer(date),
    school_start_month = as.integer(value)
  ) %>%
  filter(!is.na(school_start_month))

surveys <- tibble::tribble(
  ~country_iso3, ~year, ~country_name,
  "BEN", 2021L, "Benin",
  "CAF", 2018L, "Central African Republic",
  "COD", 2017L, "Congo, Dem. Rep.",
  "COM", 2022L, "Comoros",
  "GHA", 2017L, "Ghana",
  "GMB", 2018L, "Gambia",
  "GNB", 2018L, "Guinea-Bissau",
  "LSO", 2018L, "Lesotho",
  "MDG", 2018L, "Madagascar",
  "MWI", 2019L, "Malawi",
  "NGA", 2021L, "Nigeria",
  "SLE", 2017L, "Sierra Leone",
  "STP", 2019L, "Sao Tome and Principe",
  "SWZ", 2021L, "Eswatini",
  "TCD", 2019L, "Chad",
  "TGO", 2017L, "Togo",
  "TUN", 2018L, "Tunisia",
  "TUN", 2023L, "Tunisia",
  "ZWE", 2019L, "Zimbabwe"
)

pick_uis <- function(iso, yr) {
  cand <- uis %>% filter(country_iso3 == iso)
  if (nrow(cand) == 0) return(tibble(uis_year = NA_integer_, school_start_month = NA_integer_))
  exact <- cand %>% filter(uis_year == yr)
  if (nrow(exact) == 1) return(exact %>% select(uis_year, school_start_month))
  # Prefer nearest prior year, else nearest any year
  prior <- cand %>% filter(uis_year <= yr) %>% slice_max(uis_year, n = 1)
  if (nrow(prior) == 1) return(prior %>% select(uis_year, school_start_month))
  cand %>% mutate(abs_diff = abs(uis_year - yr)) %>%
    slice_min(abs_diff, n = 1) %>%
    select(uis_year, school_start_month)
}

out <- surveys %>%
  rowwise() %>%
  mutate(pick = list(pick_uis(country_iso3, year))) %>%
  tidyr::unnest(pick) %>%
  ungroup() %>%
  mutate(
    school_start_day = 1L,
    source = "World Bank EdStats / UNESCO UIS indicator UIS.YR.ST.MON.01T5",
    notes = case_when(
      uis_year == year ~ sprintf("UIS start month for calendar year %d", uis_year),
      !is.na(uis_year) ~ sprintf(
        "No UIS value for survey year %d; used nearest available UIS year %d",
        year, uis_year
      ),
      TRUE ~ "Missing UIS value"
    )
  ) %>%
  select(
    country_iso3, year, country_name, school_start_month, school_start_day,
    uis_year, source, notes
  )

stopifnot(!any(is.na(out$school_start_month)))
write_csv(out, "analysis/school_year_start.csv")
print(out, n = Inf)
