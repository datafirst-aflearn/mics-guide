# harmonize-mics-fs-v1.0.R
#
# Growing MICS6 FS (5-17) harmonised file: HH geography/background core +
# Child's Background (CB) schooling + Child Labour (CL) + Parental Involvement
# (PR) + Child Functioning (FCF) + Child Discipline (FCD) + Foundational
# Learning (FL) numeracy/setup.
# Reading outcomes stay in harmonize-mics-reading-v1.1.R (not duplicated here).
#
# PR12 / school_closed_a-c: reason slot meanings differ by survey (see
# Excel sheet "notes"); not cross-country comparable as coded.
# FCF walking items: yards vs meters in labels only; codes treated as comparable.
# FCD: SLE has no FCD5; attitude item is FCD3 (mapped to phys_punish_needed).
# HH region: raw country codes (not a cross-country taxonomy).
#
# CB level_h defaults (v1.0):
#   - Tech/voc nested in secondary -> 3 (upper secondary)
#   - Standalone vocational tracks -> 4
#   - ZWE vocational/tertiary subtypes collapsed to 4 / 5
#   - TUN adult education / literacy -> 9
#   - Grades kept as raw country codes
#
# CL: rename + labels only (no derived child-labour indicators).
#
# Run from the mics-guide project root:
#     source("data/harmonize-mics-fs-v1.0.R")
#
# Input :  data/MICS_Datasets/<ISO>_<YEAR>_MICS6_v01_M/fs.sav
# Output:  data/mics6_fs_harmonized.{rds,dta}
#          data/mics6_fs_variable_crosswalk.xlsx
#            sheets: crosswalk (theme col), excluded, level_map

if (!require(pacman)) install.packages("pacman")
pacman::p_load(tidyverse, haven, labelled, openxlsx)

root    <- "data/MICS_Datasets"
outdir  <- "data"
outfile <- "mics6_fs_harmonized"

supported <- c(
  "BEN", "CAF", "COD", "COM", "GHA", "GMB", "GNB", "LSO", "MDG",
  "MWI", "NGA", "SLE", "STP", "SWZ", "TCD", "TGO", "TUN", "ZWE"
)

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

present <- function(x) !is.na(x)

ensure <- function(df, vars) {
  gaps <- setdiff(vars, names(df))
  if (length(gaps) > 0) {
    df[gaps] <- NA_real_
    message("    note: not in this survey, created as missing: ",
            paste(gaps, collapse = ", "))
  }
  df
}

cap_rename <- function(df, mapping) {
  for (i in seq_along(mapping)) {
    new <- names(mapping)[i]
    old <- unname(mapping[i])
    if (old %in% names(df) && !(new %in% names(df))) {
      names(df)[names(df) == old] <- new
    }
  }
  df
}

set_labels_if_present <- function(df, vars, labels) {
  for (v in intersect(vars, names(df))) {
    val_labels(df[[v]]) <- labels
  }
  df
}

yes_no_labels    <- c(Yes = 1, No = 2, "No response" = 9)
yes_no_dk_labels <- c(Yes = 1, No = 2, DK = 8, "No response" = 9)
hour_labels      <- c("No response" = 99)
books_labels     <- c(None = 0, "No response" = 99)

key_var_labels <- c(
  country_iso3 = "Country (ISO3 code)",
  year         = "Survey year",
  cluster      = "Cluster number",
  hhno         = "Household number",
  linech       = "Line number",
  HH1          = "Cluster number",
  HH2          = "Household number",
  LN           = "Line number"
)

# ---------------------------------------------------------------------------
# HH theme (area / region / household children 5-17)
# ---------------------------------------------------------------------------

core_hh_sources <- c("HH6", "HH7", "HH52")

hh_rename <- c(
  urban            = "HH6",
  region           = "HH7",
  n_children_5_17  = "HH52"
)

hh_var_labels <- c(
  urban = "Area of residence (urban/rural)",
  region = "Region / first administrative area (country codes)",
  n_children_5_17 = "Number of children age 5-17 in the household"
)

urban_labels <- c(Urban = 1, Rural = 2)

hh_crosswalk_notes <- c(
  region = "Country codes; see notes sheet"
)

hh_exclude_reason <- function(var) {
  if (grepl("^HH6A$", var)) {
    "Settlement type detail (country-specific; not in core)"
  } else if (grepl("^HH7[Aa]|^HH7Aux", var)) {
    "Finer region split (country-specific; not in core)"
  } else if (grepl("^HH3$|^HH4$", var)) {
    "Interviewer / supervisor identifier (not analysis core)"
  } else {
    "Outside core HH geography/background keep list"
  }
}

# ---------------------------------------------------------------------------
# CB theme
# ---------------------------------------------------------------------------

core_cb_sources <- c(
  "CB2M", "CB2Y", "CB3", "CB4", "CB5A", "CB5B", "CB6",
  "CB7", "CB8A", "CB8B", "CB9", "CB10A", "CB10B"
)

cb_rename <- c(
  birth_month       = "CB2M",
  birth_year        = "CB2Y",
  age               = "CB3",
  ever_attended     = "CB4",
  highest_level     = "CB5A",
  highest_grade     = "CB5B",
  highest_completed = "CB6",
  enrolled          = "CB7",
  current_level     = "CB8A",
  current_grade     = "CB8B",
  attended_previous = "CB9",
  previous_level    = "CB10A",
  previous_grade    = "CB10B"
)

cb_var_labels <- c(
  birth_month       = "Month of birth of child",
  birth_year        = "Year of birth of child",
  age               = "Age of child (completed years)",
  ever_attended     = "Ever attended school or early childhood programme",
  highest_level     = "Highest level of education attended (country codes)",
  highest_grade     = "Highest grade attended at that level (country codes)",
  highest_completed = "Ever completed that grade/year",
  enrolled          = "Attended school during current school year",
  current_level     = "Level of education attended current school year (country codes)",
  current_grade     = "Grade attended current school year (country codes)",
  attended_previous = "Attended school during previous school year",
  previous_level    = "Level of education attended previous school year (country codes)",
  previous_grade    = "Grade attended previous school year (country codes)",
  highest_level_h   = "Highest level attended (harmonised)",
  current_level_h   = "Current school year level (harmonised)",
  previous_level_h  = "Previous school year level (harmonised)"
)

level_h_labels <- c(
  "Early childhood / pre-primary (ECE)" = 0,
  "Primary"                             = 1,
  "Lower secondary"                     = 2,
  "Upper secondary"                     = 3,
  "Vocational / technical"              = 4,
  "Higher / tertiary"                   = 5,
  "Don't know"                          = 8,
  "No response / other special"         = 9
)

map_level <- function(x, mapping) {
  out <- rep(NA_real_, length(x))
  ok <- present(x)
  if (!any(ok)) return(out)
  keys <- as.character(as.integer(x[ok]))
  mapped <- unname(mapping[keys])
  out[ok] <- mapped
  out
}

level_map_for <- function(iso, year = NULL) {
  if (iso == "BEN") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5, "9" = 9)
  } else if (iso == "CAF") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 3, "5" = 5, "8" = 8, "9" = 9)
  } else if (iso == "COD") {
    c("0" = 0, "10" = 1, "20" = 2,
      "31" = 3, "32" = 3, "33" = 3, "34" = 3,
      "40" = 5, "98" = 8, "99" = 9)
  } else if (iso == "COM") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5, "8" = 8, "9" = 9)
  } else if (iso == "GHA") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 2, "4" = 3, "5" = 3, "6" = 5, "9" = 9)
  } else if (iso == "GMB") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 4, "5" = 5, "6" = 5,
      "8" = 8, "9" = 9)
  } else if (iso == "GNB") {
    c("0" = 0, "1" = 1, "2" = 3, "3" = 4, "4" = 4, "5" = 5, "8" = 8, "9" = 9)
  } else if (iso %in% c("LSO", "SWZ")) {
    c("0" = 0, "1" = 1, "2" = 3, "3" = 5, "4" = 4, "9" = 9)
  } else if (iso == "MDG") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5, "9" = 9)
  } else if (iso == "MWI") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5, "5" = 4, "9" = 9)
  } else if (iso == "NGA") {
    c("0" = 0, "11" = 1, "21" = 2, "22" = 3, "31" = 3, "32" = 3,
      "41" = 5, "99" = 9)
  } else if (iso == "SLE") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5, "5" = 4, "8" = 8, "9" = 9)
  } else if (iso == "STP") {
    c("0" = 0, "1" = 1, "2" = 3, "3" = 4, "4" = 5, "5" = 5, "8" = 8, "9" = 9)
  } else if (iso == "TCD") {
    c("0" = 0, "10" = 1, "20" = 2, "21" = 2, "30" = 3, "31" = 3,
      "40" = 5, "41" = 5, "98" = 8, "99" = 9)
  } else if (iso == "TGO") {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5, "7" = 9, "9" = 9)
  } else if (iso == "TUN" && identical(as.character(year), "2018")) {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5,
      "5" = 4, "6" = 4, "7" = 4, "8" = 4, "9" = 4, "10" = 9,
      "98" = 8, "99" = 9)
  } else if (iso == "TUN" && identical(as.character(year), "2023")) {
    c("0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 5,
      "5" = 4, "6" = 4, "7" = 4, "8" = 4, "9" = 4, "10" = 9,
      "98" = 8, "99" = 9)
  } else if (iso == "ZWE") {
    c("0" = 0, "1" = 1, "2" = 4, "3" = 2, "4" = 3,
      "5" = 4, "6" = 4, "7" = 5, "8" = 5, "98" = 8, "99" = 9)
  } else {
    stop("No level_h map defined for ", iso, " ", year)
  }
}

resolve_level_h_code <- function(iso, year, src, code, default_h) {
  code <- as.character(code)
  h <- default_h
  if (iso == "TUN" && identical(as.character(year), "2018") &&
      src == "highest_level") {
    if (code == "5") h <- 9
    if (code == "8") h <- 8
    if (code == "9") h <- 9
  }
  if (iso == "TUN" && identical(as.character(year), "2023") &&
      src == "highest_level") {
    if (code == "8") h <- 8
    if (code == "9") h <- 9
  }
  if (iso == "TUN" && src %in% c("current_level", "previous_level") &&
      code == "8") {
    h <- 5
  }
  h
}

apply_level_h <- function(d, iso, year) {
  mapping <- level_map_for(iso, year)
  for (pair in list(
    c("highest_level", "highest_level_h"),
    c("current_level", "current_level_h"),
    c("previous_level", "previous_level_h")
  )) {
    src <- pair[[1]]
    dst <- pair[[2]]
    raw <- d[[src]]
    mapped <- map_level(raw, mapping)
    ok <- present(raw)
    if (any(ok)) {
      keys <- as.character(as.integer(raw[ok]))
      mapped[ok] <- mapply(
        function(code, default_h) {
          resolve_level_h_code(iso, year, src, code, default_h)
        },
        keys,
        mapped[ok],
        USE.NAMES = FALSE
      )
    }
    d[[dst]] <- mapped
  }
  d
}

level_map_rows <- function(iso, year, raw_labels_by_var) {
  mapping <- level_map_for(iso, year)
  survey <- paste0(iso, "_", year)
  rows <- list()
  for (src in c("highest_level", "current_level", "previous_level")) {
    labs <- raw_labels_by_var[[src]]
    codes <- if (!is.null(labs) && length(labs) > 0) {
      as.character(unname(labs))
    } else {
      names(mapping)
    }
    for (code in codes) {
      code_num <- as.numeric(code)
      raw_lab <- if (!is.null(labs) && code_num %in% unname(labs)) {
        names(labs)[match(code_num, unname(labs))]
      } else {
        NA_character_
      }
      default_h <- unname(mapping[[code]])
      if (is.null(default_h) || length(default_h) == 0 || is.na(default_h)) next
      h <- resolve_level_h_code(iso, year, src, code, default_h)
      h_lab <- names(level_h_labels)[match(h, unname(level_h_labels))]
      rows[[length(rows) + 1]] <- tibble(
        survey = survey,
        country_iso3 = iso,
        year = as.integer(year),
        source_var = unname(cb_rename[src]),
        harmonized_raw = src,
        raw_code = code_num,
        raw_label = raw_lab,
        level_h = h,
        level_h_label = h_lab
      )
    }
  }
  bind_rows(rows)
}

cb_exclude_reason <- function(var) {
  if (grepl("^CB11$|^CB12|^CB13$|^CB14", var)) {
    "Health insurance / coverage (not core schooling)"
  } else if (grepl("^CB6B|^CB6C$", var)) {
    "Vocational pathway detail before vocational school (country-specific)"
  } else if (grepl("^CB8A{2}|^CB8B{2}|^CB8C|^CB8B_", var)) {
    "Country-specific current-year education detail"
  } else if (grepl("^CB12AB|^CB12AC", var)) {
    "School-leaving / first-entry reasons (country-specific)"
  } else {
    "Outside core schooling keep list"
  }
}

# ---------------------------------------------------------------------------
# CL theme
# ---------------------------------------------------------------------------

core_cl_sources <- c(
  "CL1A", "CL1B", "CL1C", "CL1X", "CL3", "CL4", "CL5",
  "CL6A", "CL6B", "CL6C", "CL6D", "CL6E", "CL6X",
  "CL7", "CL8", "CL9", "CL10",
  "CL11A", "CL11B", "CL11C", "CL11D", "CL11E", "CL11F", "CL11X", "CL13"
)

cl_rename <- c(
  work_farm              = "CL1A",
  work_family_business   = "CL1B",
  work_produce_sell      = "CL1C",
  work_other_income      = "CL1X",
  work_hours             = "CL3",
  hazard_heavy_loads     = "CL4",
  hazard_dangerous_tools = "CL5",
  hazard_dust_fumes      = "CL6A",
  hazard_extreme_temp    = "CL6B",
  hazard_noise           = "CL6C",
  hazard_heights         = "CL6D",
  hazard_chemicals       = "CL6E",
  hazard_other           = "CL6X",
  fetch_water            = "CL7",
  fetch_water_hours      = "CL8",
  collect_firewood       = "CL9",
  collect_firewood_hours = "CL10",
  chore_shopping         = "CL11A",
  chore_cooking          = "CL11B",
  chore_cleaning         = "CL11C",
  chore_laundry          = "CL11D",
  chore_care_children    = "CL11E",
  chore_care_elderly     = "CL11F",
  chore_other            = "CL11X",
  chore_hours            = "CL13"
)

cl_var_labels <- c(
  work_farm              = "Worked or helped on farm/garden in past week",
  work_family_business   = "Helped in family business in past week",
  work_produce_sell      = "Produced or sold articles in past week",
  work_other_income      = "Engaged in any other activity for income in past week",
  work_hours             = "Hours worked in past week (economic activities)",
  hazard_heavy_loads     = "Activities required carrying heavy loads",
  hazard_dangerous_tools = "Activities required dangerous tools or heavy machinery",
  hazard_dust_fumes      = "Work exposed to dust, fumes, or gas",
  hazard_extreme_temp    = "Work exposed to extreme temperatures or humidity",
  hazard_noise           = "Work exposed to loud noise or vibration",
  hazard_heights         = "Work required working at heights",
  hazard_chemicals       = "Work required working with chemicals",
  hazard_other           = "Work exposed to other hazardous conditions",
  fetch_water            = "Fetched water in past week",
  fetch_water_hours      = "Hours spent fetching water in past week",
  collect_firewood       = "Collected firewood in past week",
  collect_firewood_hours = "Hours spent collecting firewood in past week",
  chore_shopping         = "Household chores: shopping",
  chore_cooking          = "Household chores: cooking",
  chore_cleaning         = "Household chores: washing dishes or cleaning house",
  chore_laundry          = "Household chores: washing clothes",
  chore_care_children    = "Household chores: caring for children",
  chore_care_elderly     = "Household chores: caring for old or sick",
  chore_other            = "Household chores: other household tasks",
  chore_hours            = "Hours engaged in household chores in past week"
)

cl_yes_no_vars <- c(
  "work_farm", "work_family_business", "work_produce_sell", "work_other_income",
  "hazard_heavy_loads", "hazard_dangerous_tools",
  "hazard_dust_fumes", "hazard_extreme_temp", "hazard_noise",
  "hazard_heights", "hazard_chemicals", "hazard_other",
  "fetch_water", "collect_firewood",
  "chore_shopping", "chore_cooking", "chore_cleaning", "chore_laundry",
  "chore_care_children", "chore_care_elderly", "chore_other"
)

cl_hour_vars <- c(
  "work_hours", "fetch_water_hours", "collect_firewood_hours", "chore_hours"
)

cl_exclude_reason <- function(var) {
  if (grepl("^CL6F$", var)) {
    "Night work hazard (country-specific; not in core keep list)"
  } else if (grepl("^CL10A$|^CL10B$", var)) {
    "Herding animals (country-specific; not in core keep list)"
  } else if (grepl("^CL11G$", var)) {
    "Extra household chore item (country-specific)"
  } else if (grepl("^CL6AA$|^CL6BA$", var)) {
    "Country-specific work activity (apprentice / fishing etc.)"
  } else if (grepl("^CL1D$|^CL1E$", var)) {
    "Extra economic activity item (country-specific)"
  } else if (grepl("^CL2$|^CL12$", var)) {
    "Questionnaire check/filter (not an analysis variable)"
  } else {
    "Outside core child labour keep list"
  }
}

# ---------------------------------------------------------------------------
# PR theme (Parental Involvement)
# ---------------------------------------------------------------------------

core_pr_sources <- c(
  "PR3", "PR5", "PR6", "PR7", "PR8", "PR9A", "PR9B", "PR10",
  "PR11A", "PR11B", "PR12A", "PR12B", "PR12C", "PR12X", "PR13", "PR15"
)

pr_rename <- c(
  child_books                  = "PR3",
  had_homework                 = "PR5",
  homework_help                = "PR6",
  school_governing_body        = "PR7",
  attended_pta_meeting         = "PR8",
  meeting_discussed_plan       = "PR9A",
  meeting_discussed_budget     = "PR9B",
  received_report_card         = "PR10",
  visited_school_event         = "PR11A",
  discussed_progress_teachers  = "PR11B",
  school_closed_a              = "PR12A",
  school_closed_b              = "PR12B",
  school_closed_c              = "PR12C",
  school_closed_other          = "PR12X",
  missed_class_teacher_absent  = "PR13",
  contacted_school_officials   = "PR15"
)

pr_var_labels <- c(
  child_books = "Number of children's books or picture books for child",
  had_homework = "Child ever had homework",
  homework_help = "Anyone helps child with homework",
  school_governing_body = "School has a governing body in which parents can participate",
  attended_pta_meeting = "Adult from household attended PTA/SMC meeting in last 12 months",
  meeting_discussed_plan = "At meeting discussed plan for key education issues",
  meeting_discussed_budget = "At meeting discussed school budget or use of funds",
  received_report_card = "Received a student report card in last 12 months",
  visited_school_event = "Gone to school for assembly, celebration or sport event (last 12 months)",
  discussed_progress_teachers = "Gone to school to discuss child's progress with teachers (last 12 months)",
  school_closed_a = "School closed in last 12 months — reason slot A (country-specific meaning; see notes)",
  school_closed_b = "School closed in last 12 months — reason slot B (country-specific meaning; see notes)",
  school_closed_c = "School closed in last 12 months — reason slot C (country-specific meaning; see notes)",
  school_closed_other = "School closed in last 12 months due to any other reason",
  missed_class_teacher_absent = "Child unable to attend class due to teacher absence (last 12 months)",
  contacted_school_officials = "Contacted school officials/governing body about strike or teacher absence"
)

pr_yes_no_dk_vars <- c(
  "had_homework", "homework_help", "school_governing_body",
  "attended_pta_meeting", "meeting_discussed_plan", "meeting_discussed_budget",
  "received_report_card", "visited_school_event", "discussed_progress_teachers",
  "school_closed_a", "school_closed_b", "school_closed_c", "school_closed_other",
  "missed_class_teacher_absent", "contacted_school_officials"
)

pr_crosswalk_notes <- c(
  school_closed_a = "See sheet notes",
  school_closed_b = "See sheet notes",
  school_closed_c = "See sheet notes"
)

fs_notes <- tibble(
  theme = c("HH", "PR", "PR", "PR", "FCF", "FCD", "FL"),
  topic = c(
    "region (HH7)",
    "school_closed_a/b/c (PR12A/B/C)",
    "school_closed_a/b/c (PR12A/B/C)",
    "school_closed_a/b/c (PR12A/B/C)",
    "walk_100_* / walk_500_* (FCF10–FCF15)",
    "phys_punish_needed (FCD5 / SLE FCD3)",
    "Reading vs numeracy/setup"
  ),
  note = c(
    paste(
      "region keeps raw country codes from HH7 (province/département/district/island/etc.).",
      "Codes and SPSS value labels are NOT a cross-country taxonomy;",
      "interpret within country_iso3. urban is HH6 (1=Urban, 2=Rural).",
      "n_children_5_17 is HH52 (missing in TUN 2018).",
      "HH6A / HH7A / HH3 / HH4 and other HH* extras are excluded."
    ),
    paste(
      "Reason slots A–C are NOT cross-country comparable as coded.",
      "Most surveys: A = natural disasters, B = man-made disasters,",
      "C = teacher strike / absenteeism. Check each survey's SPSS value labels."
    ),
    paste(
      "NGA example: A = COVID-19; B = natural disasters / epidemics other than COVID-19;",
      "C = man-made disasters; teacher strike is PR12D (excluded from core).",
      "COD/SWZ also have an extra PR12D (excluded)."
    ),
    paste(
      "Use school_closed_other (PR12X) for 'any other reason'.",
      "For analysis across countries, do not pool school_closed_a/b/c without",
      "re-mapping to a common taxonomy from country questionnaires."
    ),
    paste(
      "Walking distance wording is 'yards' in some surveys and 'meters' in others;",
      "codes are treated as comparable for cross-country pooling."
    ),
    paste(
      "Attitude item uses FCD5 when present; SLE has no FCD5 and stores the same",
      "question in FCD3 (mapped to phys_punish_needed).",
      "No derived violent-discipline composites in this pass (rename + labels only).",
      "FCD3/FCD4 filters and country extras FCD2L–N are on the excluded sheet."
    ),
    paste(
      "Reading outcomes are NOT in mics6_fs_harmonized; use mics6_reading_harmonized",
      "and merge on country_iso3, year, HH1, HH2, LN.",
      "This FL block is numeracy items + setup/eligibility only (rename + labels).",
      "lang_school uses FL9 when present, else FL9A with FL9B fill (e.g. TCD)."
    )
  )
)

pr_exclude_reason <- function(var) {
  if (grepl("^PR17|^PR18|^PR20$", var)) {
    "School absence reasons (country-specific; not in core keep list)"
  } else if (grepl("^PR12D$", var)) {
    "Extra school-closure reason slot (country-specific; not in core)"
  } else if (grepl("^PR11C$", var)) {
    "Extra school-visit item (country-specific)"
  } else if (grepl("^PR4A$|^PR4$", var)) {
    "School attendance check detail (not core analysis variable)"
  } else if (grepl("^PR2$", var)) {
    "Country-specific PR item (not in core keep list)"
  } else if (grepl("^PR1$|^PR14$|^PR16$|^PR19$", var)) {
    "Questionnaire check/filter (not an analysis variable)"
  } else {
    "Outside core parental involvement keep list"
  }
}

# ---------------------------------------------------------------------------
# FCF theme (Child Functioning)
# ---------------------------------------------------------------------------

core_fcf_sources <- c(
  "FCF1", "FCF2", "FCF3", "FCF6", "FCF8",
  "FCF10", "FCF11", "FCF12", "FCF13", "FCF14", "FCF15",
  "FCF16", "FCF17", "FCF18", "FCF19", "FCF20", "FCF21",
  "FCF22", "FCF23", "FCF24", "FCF25", "FCF26"
)

fcf_rename <- c(
  uses_glasses                     = "FCF1",
  uses_hearing_aid                 = "FCF2",
  uses_walking_aid                 = "FCF3",
  difficulty_seeing                = "FCF6",
  difficulty_hearing               = "FCF8",
  walk_100_no_aid                  = "FCF10",
  walk_500_no_aid                  = "FCF11",
  walk_100_with_aid                = "FCF12",
  walk_500_with_aid                = "FCF13",
  walk_100_vs_peers                = "FCF14",
  walk_500_vs_peers                = "FCF15",
  difficulty_self_care             = "FCF16",
  understood_inside_hh             = "FCF17",
  understood_outside_hh            = "FCF18",
  difficulty_learning              = "FCF19",
  difficulty_remembering           = "FCF20",
  difficulty_concentrating         = "FCF21",
  difficulty_accepting_change      = "FCF22",
  difficulty_controlling_behaviour = "FCF23",
  difficulty_making_friends        = "FCF24",
  anxious_nervous_freq             = "FCF25",
  sad_depressed_freq               = "FCF26"
)

fcf_var_labels <- c(
  uses_glasses = "Child wears glasses or contact lenses",
  uses_hearing_aid = "Child uses a hearing aid",
  uses_walking_aid = "Child uses equipment or receives assistance for walking",
  difficulty_seeing = "Child has difficulty seeing",
  difficulty_hearing = "Child has difficulty hearing sounds like people voices or music",
  walk_100_no_aid = "Without equipment/assistance, difficulty walking 100 yards/meters",
  walk_500_no_aid = "Without equipment/assistance, difficulty walking 500 yards/meters",
  walk_100_with_aid = "With equipment/assistance, difficulty walking 100 yards/meters",
  walk_500_with_aid = "With equipment/assistance, difficulty walking 500 yards/meters",
  walk_100_vs_peers = "Compared with same-age children, difficulty walking 100 yards/meters",
  walk_500_vs_peers = "Compared with same-age children, difficulty walking 500 yards/meters",
  difficulty_self_care = "Difficulty with self-care such as feeding or dressing",
  understood_inside_hh = "Difficulty being understood by people inside this household",
  understood_outside_hh = "Difficulty being understood by people outside this household",
  difficulty_learning = "Compared with same-age children, difficulty learning things",
  difficulty_remembering = "Compared with same-age children, difficulty remembering things",
  difficulty_concentrating = "Difficulty concentrating on an activity that he/she enjoys",
  difficulty_accepting_change = "Difficulty accepting changes in his/her routine",
  difficulty_controlling_behaviour = "Compared with same-age children, difficulty controlling behaviour",
  difficulty_making_friends = "Difficulty making friends",
  anxious_nervous_freq = "How often child seems very anxious, nervous or worried",
  sad_depressed_freq = "How often child seems very sad or depressed"
)

fcf_aid_vars <- c("uses_glasses", "uses_hearing_aid", "uses_walking_aid")

fcf_difficulty_vars <- c(
  "difficulty_seeing", "difficulty_hearing",
  "walk_100_no_aid", "walk_500_no_aid", "walk_100_with_aid", "walk_500_with_aid",
  "walk_100_vs_peers", "walk_500_vs_peers",
  "difficulty_self_care", "understood_inside_hh", "understood_outside_hh",
  "difficulty_learning", "difficulty_remembering", "difficulty_concentrating",
  "difficulty_accepting_change", "difficulty_controlling_behaviour",
  "difficulty_making_friends"
)

fcf_freq_vars <- c("anxious_nervous_freq", "sad_depressed_freq")

difficulty_labels <- c(
  "No difficulty" = 1,
  "Some difficulty" = 2,
  "A lot of difficulty" = 3,
  "Cannot at all" = 4,
  "No response" = 9
)

freq_labels <- c(
  Daily = 1,
  Weekly = 2,
  Monthly = 3,
  "A few times a year" = 4,
  Never = 5,
  "No response" = 9
)

fcf_exclude_reason <- function(var) {
  if (grepl("^FCF4$|^FCF5$|^FCF7$|^FCF9$", var)) {
    "Questionnaire check/filter (not an analysis variable)"
  } else if (grepl("^FCF6A$|^FCF6B$|^FCF8A$|^FCF8B$", var)) {
    "Seeing/hearing branched item (country layout); core uses FCF6/FCF8"
  } else {
    "Outside core child functioning keep list"
  }
}

# ---------------------------------------------------------------------------
# FCD theme (Child Discipline — core methods + attitude)
# ---------------------------------------------------------------------------

core_fcd_sources <- c(
  paste0("FCD2", LETTERS[1:11]),  # FCD2A–K
  "FCD5", "FCD3"                  # FCD3 kept available for SLE attitude map
)

fcd_rename <- c(
  disc_took_privileges = "FCD2A",
  disc_explained_wrong = "FCD2B",
  disc_shook           = "FCD2C",
  disc_shouted         = "FCD2D",
  disc_gave_other_task = "FCD2E",
  disc_spanked_hand    = "FCD2F",
  disc_hit_object      = "FCD2G",
  disc_called_names    = "FCD2H",
  disc_hit_face        = "FCD2I",
  disc_hit_limb        = "FCD2J",
  disc_beat_hard       = "FCD2K",
  phys_punish_needed   = "FCD5"
)

fcd_var_labels <- c(
  disc_took_privileges = "Took away privileges (last month)",
  disc_explained_wrong = "Explained why behaviour was wrong (last month)",
  disc_shook = "Shook child (last month)",
  disc_shouted = "Shouted, yelled or screamed at child (last month)",
  disc_gave_other_task = "Gave child something else to do (last month)",
  disc_spanked_hand = "Spanked, hit or slapped child on bottom with bare hand (last month)",
  disc_hit_object = "Hit child on bottom or elsewhere with belt, brush, stick, etc. (last month)",
  disc_called_names = "Called child dumb, lazy or another name (last month)",
  disc_hit_face = "Hit or slapped child on the face, head or ears (last month)",
  disc_hit_limb = "Hit or slapped child on the hand, arm or leg (last month)",
  disc_beat_hard = "Beat child up as hard as one could (last month)",
  phys_punish_needed = "Believes child needs to be physically punished to be brought up properly"
)

fcd_method_vars <- names(fcd_rename)[names(fcd_rename) != "phys_punish_needed"]

fcd_crosswalk_notes <- c(
  phys_punish_needed = "FCD5, or FCD3 in SLE (see notes sheet)"
)

fcd_exclude_reason <- function(var) {
  if (grepl("^FCD3$|^FCD4$", var)) {
    "Questionnaire check/filter (not an analysis variable)"
  } else if (grepl("^FCD2[LMN]$", var)) {
    "Country-specific discipline method (not in core keep list)"
  } else {
    "Outside core child discipline keep list"
  }
}

# ---------------------------------------------------------------------------
# FL theme (Foundational Learning — numeracy + setup; not reading outcomes)
# ---------------------------------------------------------------------------

core_fl_sources <- c(
  "FL1", "FL3", "FL6A", "FL6B", "FL7", "FL9", "FL9A", "FL9B", "FL28",
  paste0("FL23", LETTERS[1:6]),
  paste0("FL24", LETTERS[1:5]),
  paste0("FL25", LETTERS[1:5]),
  paste0("FL27", LETTERS[1:5])
)

fl_rename <- c(
  fl_consent        = "FL1",
  child_consent     = "FL3",
  child_reads_books = "FL6A",
  read_to_child     = "FL6B",
  lang_home         = "FL7",
  lang_school       = "FL9",
  fl_child_result   = "FL28",
  number_id_1       = "FL23A",
  number_id_2       = "FL23B",
  number_id_3       = "FL23C",
  number_id_4       = "FL23D",
  number_id_5       = "FL23E",
  number_id_6       = "FL23F",
  number_compare_1  = "FL24A",
  number_compare_2  = "FL24B",
  number_compare_3  = "FL24C",
  number_compare_4  = "FL24D",
  number_compare_5  = "FL24E",
  number_add_1      = "FL25A",
  number_add_2      = "FL25B",
  number_add_3      = "FL25C",
  number_add_4      = "FL25D",
  number_add_5      = "FL25E",
  number_pattern_1  = "FL27A",
  number_pattern_2  = "FL27B",
  number_pattern_3  = "FL27C",
  number_pattern_4  = "FL27D",
  number_pattern_5  = "FL27E"
)

fl_var_labels <- c(
  fl_consent = "Caregiver consent for foundational learning assessment",
  child_consent = "Child consent / assent for FL activities",
  child_reads_books = "Child reads books",
  read_to_child = "Someone reads books to the child",
  lang_home = "Language child speaks most of the time at home (country codes)",
  lang_school = "Language teacher uses most when teaching child (country codes)",
  fl_child_result = "Result of interview with selected child (ages 7-14)",
  number_id_1 = "Number recognition item 1",
  number_id_2 = "Number recognition item 2",
  number_id_3 = "Number recognition item 3",
  number_id_4 = "Number recognition item 4",
  number_id_5 = "Number recognition item 5",
  number_id_6 = "Number recognition item 6",
  number_compare_1 = "Number discrimination item 1 (which is bigger)",
  number_compare_2 = "Number discrimination item 2 (which is bigger)",
  number_compare_3 = "Number discrimination item 3 (which is bigger)",
  number_compare_4 = "Number discrimination item 4 (which is bigger)",
  number_compare_5 = "Number discrimination item 5 (which is bigger)",
  number_add_1 = "Addition item 1",
  number_add_2 = "Addition item 2",
  number_add_3 = "Addition item 3",
  number_add_4 = "Addition item 4",
  number_add_5 = "Addition item 5",
  number_pattern_1 = "Missing-number / pattern item 1",
  number_pattern_2 = "Missing-number / pattern item 2",
  number_pattern_3 = "Missing-number / pattern item 3",
  number_pattern_4 = "Missing-number / pattern item 4",
  number_pattern_5 = "Missing-number / pattern item 5"
)

fl_yes_no_vars <- c("fl_consent", "child_consent", "child_reads_books", "read_to_child")

fl_numeracy_vars <- c(
  paste0("number_id_", 1:6),
  paste0("number_compare_", 1:5),
  paste0("number_add_", 1:5),
  paste0("number_pattern_", 1:5)
)

numeracy_item_labels <- c(
  Correct = 1,
  Incorrect = 2,
  "No attempt" = 3,
  "No response" = 9
)

fl_is_reading_var <- function(var) {
  grepl(
    paste0(
      "^FL(10|13|14|15|16|17|18|19|20|21|22|100|110|11[3-9]|12[0-2]|",
      "21[0-9]|22[0-2])|^FL19|^FL119|^FL219|^FLB|^FL21W|^FL21O|^FL21P|",
      "^FL21B|^FLINTRO|^FLB_"
    ),
    var
  )
}

fl_exclude_reason <- function(var) {
  if (fl_is_reading_var(var)) {
    "Reading outcome (see mics6_reading_harmonized)"
  } else {
    "Outside FL numeracy/setup keep list"
  }
}

# ---------------------------------------------------------------------------
# Per-survey: read once, apply HH + CB + CL + PR + FCF + FCD + FL
# ---------------------------------------------------------------------------

harmonize_hh_from <- function(d_full, iso, year) {
  all_names <- names(d_full)
  # HH1/HH2 are keys (theme KEY); do not treat as HH-theme excluded leftovers
  hh_all <- setdiff(grep("^HH", all_names, value = TRUE), c("HH1", "HH2"))
  excluded_hh <- setdiff(hh_all, core_hh_sources)

  keep <- unique(c("HH1", "HH2", "LN", intersect(core_hh_sources, all_names)))
  d <- d_full[keep]

  # Preserve country value labels on region (HH7) through rename
  region_labels <- if ("HH7" %in% names(d)) val_labels(d[["HH7"]]) else NULL

  d <- cap_rename(d, hh_rename)
  d <- ensure(d, names(hh_rename))

  if (!is.null(region_labels) && "region" %in% names(d)) {
    val_labels(d[["region"]]) <- region_labels
  }

  meta <- list(
    theme = "HH",
    survey = paste0(iso, "_", year),
    iso = iso,
    year = year,
    source_map = setNames(
      vapply(names(hh_rename), function(new) {
        old <- unname(hh_rename[[new]])
        if (old %in% all_names) old else NA_character_
      }, character(1)),
      names(hh_rename)
    ),
    excluded = tibble(
      theme = "HH",
      survey = paste0(iso, "_", year),
      country_iso3 = iso,
      year = as.integer(year),
      source_var = excluded_hh,
      reason = if (length(excluded_hh) == 0) {
        character(0)
      } else {
        vapply(excluded_hh, hh_exclude_reason, character(1))
      }
    )
  )

  d <- d %>% select(HH1, HH2, LN, all_of(names(hh_rename)))
  list(data = d, meta = meta)
}

harmonize_cb_from <- function(d_full, iso, year) {
  all_names <- names(d_full)
  cb_all <- grep("^CB", all_names, value = TRUE)
  excluded_cb <- setdiff(cb_all, core_cb_sources)

  keep <- unique(c("HH1", "HH2", "LN", intersect(core_cb_sources, all_names)))
  d <- d_full[keep]

  raw_labels_by_var <- list()
  for (new in names(cb_rename)) {
    old <- unname(cb_rename[[new]])
    if (old %in% names(d)) raw_labels_by_var[[new]] <- val_labels(d[[old]])
  }

  d <- cap_rename(d, cb_rename)
  d <- ensure(d, names(cb_rename))
  d <- apply_level_h(d, iso, year)

  for (v in c("ever_attended", "highest_completed", "enrolled",
              "attended_previous")) {
    if (v %in% names(d) && is.null(val_labels(d[[v]]))) {
      val_labels(d[[v]]) <- yes_no_labels[c("Yes", "No")]
    }
  }

  meta <- list(
    theme = "CB",
    survey = paste0(iso, "_", year),
    iso = iso,
    year = year,
    source_map = setNames(
      vapply(names(cb_rename), function(new) {
        old <- unname(cb_rename[[new]])
        if (old %in% all_names) old else NA_character_
      }, character(1)),
      names(cb_rename)
    ),
    excluded = tibble(
      theme = "CB",
      survey = paste0(iso, "_", year),
      country_iso3 = iso,
      year = as.integer(year),
      source_var = excluded_cb,
      reason = vapply(excluded_cb, cb_exclude_reason, character(1))
    ),
    level_map = level_map_rows(iso, year, raw_labels_by_var)
  )

  d <- d %>% select(
    HH1, HH2, LN,
    birth_month, birth_year, age,
    ever_attended, highest_level, highest_grade, highest_completed,
    enrolled, current_level, current_grade,
    attended_previous, previous_level, previous_grade,
    highest_level_h, current_level_h, previous_level_h
  )

  list(data = d, meta = meta)
}

harmonize_cl_from <- function(d_full, iso, year) {
  all_names <- names(d_full)
  cl_all <- grep("^CL", all_names, value = TRUE)
  excluded_cl <- setdiff(cl_all, core_cl_sources)

  keep <- unique(c("HH1", "HH2", "LN", intersect(core_cl_sources, all_names)))
  d <- d_full[keep]

  d <- cap_rename(d, cl_rename)
  d <- ensure(d, names(cl_rename))

  meta <- list(
    theme = "CL",
    survey = paste0(iso, "_", year),
    iso = iso,
    year = year,
    source_map = setNames(
      vapply(names(cl_rename), function(new) {
        old <- unname(cl_rename[[new]])
        if (old %in% all_names) old else NA_character_
      }, character(1)),
      names(cl_rename)
    ),
    excluded = tibble(
      theme = "CL",
      survey = paste0(iso, "_", year),
      country_iso3 = iso,
      year = as.integer(year),
      source_var = excluded_cl,
      reason = if (length(excluded_cl) == 0) {
        character(0)
      } else {
        vapply(excluded_cl, cl_exclude_reason, character(1))
      }
    )
  )

  d <- d %>% select(HH1, HH2, LN, all_of(names(cl_rename)))
  list(data = d, meta = meta)
}

harmonize_pr_from <- function(d_full, iso, year) {
  all_names <- names(d_full)
  pr_all <- grep("^PR", all_names, value = TRUE)
  excluded_pr <- setdiff(pr_all, core_pr_sources)

  keep <- unique(c("HH1", "HH2", "LN", intersect(core_pr_sources, all_names)))
  d <- d_full[keep]

  d <- cap_rename(d, pr_rename)
  d <- ensure(d, names(pr_rename))

  meta <- list(
    theme = "PR",
    survey = paste0(iso, "_", year),
    iso = iso,
    year = year,
    source_map = setNames(
      vapply(names(pr_rename), function(new) {
        old <- unname(pr_rename[[new]])
        if (old %in% all_names) old else NA_character_
      }, character(1)),
      names(pr_rename)
    ),
    excluded = tibble(
      theme = "PR",
      survey = paste0(iso, "_", year),
      country_iso3 = iso,
      year = as.integer(year),
      source_var = excluded_pr,
      reason = if (length(excluded_pr) == 0) {
        character(0)
      } else {
        vapply(excluded_pr, pr_exclude_reason, character(1))
      }
    )
  )

  d <- d %>% select(HH1, HH2, LN, all_of(names(pr_rename)))
  list(data = d, meta = meta)
}

harmonize_fcf_from <- function(d_full, iso, year) {
  all_names <- names(d_full)
  fcf_all <- grep("^FCF", all_names, value = TRUE)
  excluded_fcf <- setdiff(fcf_all, core_fcf_sources)

  keep <- unique(c("HH1", "HH2", "LN", intersect(core_fcf_sources, all_names)))
  d <- d_full[keep]

  d <- cap_rename(d, fcf_rename)
  d <- ensure(d, names(fcf_rename))

  meta <- list(
    theme = "FCF",
    survey = paste0(iso, "_", year),
    iso = iso,
    year = year,
    source_map = setNames(
      vapply(names(fcf_rename), function(new) {
        old <- unname(fcf_rename[[new]])
        if (old %in% all_names) old else NA_character_
      }, character(1)),
      names(fcf_rename)
    ),
    excluded = tibble(
      theme = "FCF",
      survey = paste0(iso, "_", year),
      country_iso3 = iso,
      year = as.integer(year),
      source_var = excluded_fcf,
      reason = if (length(excluded_fcf) == 0) {
        character(0)
      } else {
        vapply(excluded_fcf, fcf_exclude_reason, character(1))
      }
    )
  )

  d <- d %>% select(HH1, HH2, LN, all_of(names(fcf_rename)))
  list(data = d, meta = meta)
}

harmonize_fcd_from <- function(d_full, iso, year) {
  all_names <- names(d_full)
  fcd_all <- grep("^FCD", all_names, value = TRUE)

  # Prefer FCD5 for attitude; SLE stores the same item as FCD3
  attitude_from_fcd3 <- !("FCD5" %in% all_names) && ("FCD3" %in% all_names)
  consumed <- c(paste0("FCD2", LETTERS[1:11]), "FCD5")
  if (attitude_from_fcd3) {
    consumed <- c(consumed, "FCD3")
  }
  excluded_fcd <- setdiff(fcd_all, consumed)

  keep_src <- intersect(c(consumed, "FCD3", "FCD5"), all_names)
  keep <- unique(c("HH1", "HH2", "LN", keep_src))
  d <- d_full[keep]

  d <- cap_rename(d, fcd_rename)
  # If FCD5 absent, rename FCD3 -> phys_punish_needed (cap_rename skips if already present)
  d <- cap_rename(d, c(phys_punish_needed = "FCD3"))
  d <- d %>% select(-any_of("FCD3"))
  d <- ensure(d, names(fcd_rename))

  attitude_src <- if ("FCD5" %in% all_names) {
    "FCD5"
  } else if (attitude_from_fcd3) {
    "FCD3"
  } else {
    NA_character_
  }

  source_map <- setNames(
    vapply(names(fcd_rename), function(new) {
      if (new == "phys_punish_needed") return(attitude_src)
      old <- unname(fcd_rename[[new]])
      if (old %in% all_names) old else NA_character_
    }, character(1)),
    names(fcd_rename)
  )

  meta <- list(
    theme = "FCD",
    survey = paste0(iso, "_", year),
    iso = iso,
    year = year,
    source_map = source_map,
    excluded = tibble(
      theme = "FCD",
      survey = paste0(iso, "_", year),
      country_iso3 = iso,
      year = as.integer(year),
      source_var = excluded_fcd,
      reason = if (length(excluded_fcd) == 0) {
        character(0)
      } else {
        vapply(excluded_fcd, fcd_exclude_reason, character(1))
      }
    )
  )

  d <- d %>% select(HH1, HH2, LN, all_of(names(fcd_rename)))
  list(data = d, meta = meta)
}

harmonize_fl_from <- function(d_full, iso, year) {
  all_names <- names(d_full)
  fl_all <- grep("^FL", all_names, value = TRUE)
  excluded_fl <- setdiff(fl_all, core_fl_sources)

  keep <- unique(c("HH1", "HH2", "LN", intersect(core_fl_sources, all_names)))
  d <- d_full[keep]

  # Prefer FL9; else FL9A with FL9B fill (TCD), matching reading pipeline
  d <- cap_rename(d, fl_rename)
  d <- cap_rename(d, c(lang_school = "FL9A"))
  if ("FL9B" %in% names(d) && "lang_school" %in% names(d)) {
    d <- d %>% mutate(
      lang_school = if_else(present(FL9B), FL9B, lang_school)
    )
  }
  # Drop leftover language helpers if still present
  d <- d %>% select(-any_of(c("FL9A", "FL9B")))

  d <- ensure(d, names(fl_rename))

  lang_src <- if ("FL9" %in% all_names) {
    "FL9"
  } else if ("FL9A" %in% all_names && "FL9B" %in% all_names) {
    "FL9A/FL9B"
  } else if ("FL9A" %in% all_names) {
    "FL9A"
  } else {
    NA_character_
  }

  source_map <- setNames(
    vapply(names(fl_rename), function(new) {
      if (new == "lang_school") return(lang_src)
      old <- unname(fl_rename[[new]])
      if (old %in% all_names) old else NA_character_
    }, character(1)),
    names(fl_rename)
  )

  meta <- list(
    theme = "FL",
    survey = paste0(iso, "_", year),
    iso = iso,
    year = year,
    source_map = source_map,
    excluded = tibble(
      theme = "FL",
      survey = paste0(iso, "_", year),
      country_iso3 = iso,
      year = as.integer(year),
      source_var = excluded_fl,
      reason = if (length(excluded_fl) == 0) {
        character(0)
      } else {
        vapply(excluded_fl, fl_exclude_reason, character(1))
      }
    )
  )

  d <- d %>% select(HH1, HH2, LN, all_of(names(fl_rename)))
  list(data = d, meta = meta)
}

harmonize_survey <- function(path, iso, year) {
  d_full <- read_sav(path)
  id_vars <- c("HH1", "HH2", "LN")
  if (!all(id_vars %in% names(d_full))) {
    stop("Missing identifier columns in ", path)
  }
  if (anyDuplicated(d_full[id_vars]) > 0) {
    stop("HH1 HH2 LN do not uniquely identify children in ", path)
  }

  hh  <- harmonize_hh_from(d_full, iso, year)
  cb  <- harmonize_cb_from(d_full, iso, year)
  cl  <- harmonize_cl_from(d_full, iso, year)
  pr  <- harmonize_pr_from(d_full, iso, year)
  fcf <- harmonize_fcf_from(d_full, iso, year)
  fcd <- harmonize_fcd_from(d_full, iso, year)
  fl  <- harmonize_fl_from(d_full, iso, year)

  d <- hh$data %>%
    left_join(cb$data, by = id_vars) %>%
    left_join(cl$data, by = id_vars) %>%
    left_join(pr$data, by = id_vars) %>%
    left_join(fcf$data, by = id_vars) %>%
    left_join(fcd$data, by = id_vars) %>%
    left_join(fl$data, by = id_vars)

  d <- d %>% mutate(
    cluster      = HH1,
    hhno         = HH2,
    linech       = LN,
    country_iso3 = iso,
    year         = as.numeric(year)
  )

  d <- d %>% select(
    country_iso3, year, cluster, hhno, linech, HH1, HH2, LN,
    all_of(names(hh_rename)),
    all_of(names(cb_rename)),
    highest_level_h, current_level_h, previous_level_h,
    all_of(names(cl_rename)),
    all_of(names(pr_rename)),
    all_of(names(fcf_rename)),
    all_of(names(fcd_rename)),
    all_of(names(fl_rename))
  )

  list(
    data = d,
    hh_meta = hh$meta,
    cb_meta = cb$meta,
    cl_meta = cl$meta,
    pr_meta = pr$meta,
    fcf_meta = fcf$meta,
    fcd_meta = fcd$meta,
    fl_meta = fl$meta
  )
}

# ---------------------------------------------------------------------------
# Labels + documentation
# ---------------------------------------------------------------------------

apply_fs_labels <- function(df) {
  df <- set_labels_if_present(df, "urban", urban_labels)
  df <- set_labels_if_present(
    df,
    c("highest_level_h", "current_level_h", "previous_level_h"),
    level_h_labels
  )
  df <- set_labels_if_present(
    df,
    c("ever_attended", "highest_completed", "enrolled", "attended_previous",
      cl_yes_no_vars),
    yes_no_labels
  )
  df <- set_labels_if_present(df, cl_hour_vars, hour_labels)
  df <- set_labels_if_present(df, pr_yes_no_dk_vars, yes_no_dk_labels)
  df <- set_labels_if_present(df, "child_books", books_labels)
  df <- set_labels_if_present(df, fcf_aid_vars, yes_no_labels)
  df <- set_labels_if_present(df, fcf_difficulty_vars, difficulty_labels)
  df <- set_labels_if_present(df, fcf_freq_vars, freq_labels)
  df <- set_labels_if_present(df, fcd_method_vars, yes_no_labels)
  df <- set_labels_if_present(df, "phys_punish_needed", yes_no_dk_labels)
  df <- set_labels_if_present(df, fl_yes_no_vars, yes_no_labels)
  df <- set_labels_if_present(df, fl_numeracy_vars, numeracy_item_labels)

  labs <- c(key_var_labels, hh_var_labels, cb_var_labels, cl_var_labels,
            pr_var_labels, fcf_var_labels, fcd_var_labels, fl_var_labels)
  labs <- labs[names(labs) %in% names(df)]
  set_variable_labels(df, .labels = as.list(labs))
}

build_theme_crosswalk <- function(metas, theme, rename_map, var_labels,
                                  derived = NULL, notes_map = NULL) {
  rows <- lapply(names(rename_map), function(hname) {
    row <- list(
      theme = theme,
      harmonized_name = hname,
      variable_label = unname(var_labels[[hname]]),
      notes = if (!is.null(notes_map) && hname %in% names(notes_map)) {
        unname(notes_map[[hname]])
      } else {
        NA_character_
      }
    )
    for (m in metas) {
      row[[m$survey]] <- unname(m$source_map[[hname]])
    }
    as_tibble(row)
  })

  if (!is.null(derived)) {
    for (hname in names(derived)) {
      row <- list(
        theme = theme,
        harmonized_name = hname,
        variable_label = unname(var_labels[[hname]]),
        notes = NA_character_
      )
      src_raw <- derived[[hname]]
      for (m in metas) {
        src <- unname(m$source_map[[src_raw]])
        row[[m$survey]] <- if (is.na(src)) NA_character_ else paste0(src, "->level_h")
      }
      rows[[length(rows) + 1]] <- as_tibble(row)
    }
  }

  bind_rows(rows)
}

build_key_crosswalk <- function(metas) {
  key_sources <- list(
    country_iso3 = "(folder name)",
    year         = "(folder name)",
    cluster      = "HH1",
    hhno         = "HH2",
    linech       = "LN",
    HH1          = "HH1",
    HH2          = "HH2",
    LN           = "LN"
  )
  rows <- lapply(names(key_sources), function(hname) {
    row <- list(
      theme = "KEY",
      harmonized_name = hname,
      variable_label = unname(key_var_labels[[hname]]),
      notes = NA_character_
    )
    for (m in metas) {
      row[[m$survey]] <- key_sources[[hname]]
    }
    as_tibble(row)
  })
  bind_rows(rows)
}

write_fs_workbook <- function(crosswalk, level_maps, excluded, notes, path) {
  wb <- createWorkbook()
  addWorksheet(wb, "crosswalk")
  addWorksheet(wb, "level_map")
  addWorksheet(wb, "excluded")
  addWorksheet(wb, "notes")
  writeData(wb, "crosswalk", crosswalk)
  writeData(wb, "level_map", level_maps)
  writeData(wb, "excluded", excluded)
  writeData(wb, "notes", notes)
  freezePane(wb, "crosswalk", firstRow = TRUE)
  freezePane(wb, "level_map", firstRow = TRUE)
  freezePane(wb, "excluded", firstRow = TRUE)
  freezePane(wb, "notes", firstRow = TRUE)
  setColWidths(wb, "crosswalk", cols = 1:4, widths = c(8, 28, 55, 18))
  setColWidths(wb, "level_map", cols = 1:9, widths = "auto")
  setColWidths(wb, "excluded", cols = 1:6, widths = "auto")
  setColWidths(wb, "notes", cols = 1:3, widths = c(8, 32, 80))
  # Write via temp file so a locked destination does not silently keep the old workbook
  tmp <- paste0(path, ".tmp.xlsx")
  saveWorkbook(wb, tmp, overwrite = TRUE)
  if (file.exists(path) && !file.remove(path)) {
    fallback <- sub("\\.xlsx$", "_updated.xlsx", path)
    file.copy(tmp, fallback, overwrite = TRUE)
    warning("Could not replace locked workbook: ", path,
            "\nWrote updated copy to: ", tmp,
            "\nand also: ", fallback)
  } else {
    file.rename(tmp, path)
  }
}

# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

harmonize_mics_fs <- function(root = "data/MICS_Datasets",
                              outdir = "data",
                              outfile = "mics6_fs_harmonized") {

  if (!dir.exists(root)) {
    stop("Input folder not found: ", root,
         "\nRun prepare-mics-fs.R first (see the download chapter).")
  }

  folders <- list.dirs(root, recursive = FALSE, full.names = FALSE)
  parts <- list()
  hh_metas <- list()
  cb_metas <- list()
  cl_metas <- list()
  pr_metas <- list()
  fcf_metas <- list()
  fcd_metas <- list()
  fl_metas <- list()

  for (folder in folders) {
    m <- regmatches(folder, regexec("^([A-Za-z]{3})_([0-9]{4})_", folder))[[1]]
    if (length(m) == 0) {
      message("skip ", folder, ": cannot read ISO3 code and year from folder name")
      next
    }
    iso  <- toupper(m[2])
    year <- m[3]

    if (!iso %in% supported) {
      message("skip ", folder, ": ", iso, " is not in the supported list")
      next
    }

    path <- file.path(root, folder, "fs.sav")
    if (!file.exists(path)) {
      message("skip ", folder, ": fs.sav not found")
      next
    }

    message("== ", folder, "  (", iso, " ", year, ")")
    part <- harmonize_survey(path, iso, year)
    message("    kept ", nrow(part$data), " children; excluded HH=",
            nrow(part$hh_meta$excluded),
            " CB=", nrow(part$cb_meta$excluded),
            " CL=", nrow(part$cl_meta$excluded),
            " PR=", nrow(part$pr_meta$excluded),
            " FCF=", nrow(part$fcf_meta$excluded),
            " FCD=", nrow(part$fcd_meta$excluded),
            " FL=", nrow(part$fl_meta$excluded))
    parts[[folder]] <- part$data
    hh_metas[[folder]] <- part$hh_meta
    cb_metas[[folder]] <- part$cb_meta
    cl_metas[[folder]] <- part$cl_meta
    pr_metas[[folder]] <- part$pr_meta
    fcf_metas[[folder]] <- part$fcf_meta
    fcd_metas[[folder]] <- part$fcd_meta
    fl_metas[[folder]] <- part$fl_meta
  }

  if (length(parts) == 0) {
    stop("No surveys were prepared. Check the root path: ", root)
  }

  harmonized <- bind_rows(parts) %>% apply_fs_labels()

  crosswalk <- bind_rows(
    build_key_crosswalk(cb_metas),
    build_theme_crosswalk(
      hh_metas, "HH", hh_rename, hh_var_labels,
      notes_map = hh_crosswalk_notes
    ),
    build_theme_crosswalk(
      cb_metas, "CB", cb_rename, cb_var_labels,
      derived = c(
        highest_level_h = "highest_level",
        current_level_h = "current_level",
        previous_level_h = "previous_level"
      )
    ),
    build_theme_crosswalk(cl_metas, "CL", cl_rename, cl_var_labels),
    build_theme_crosswalk(
      pr_metas, "PR", pr_rename, pr_var_labels,
      notes_map = pr_crosswalk_notes
    ),
    build_theme_crosswalk(fcf_metas, "FCF", fcf_rename, fcf_var_labels),
    build_theme_crosswalk(
      fcd_metas, "FCD", fcd_rename, fcd_var_labels,
      notes_map = fcd_crosswalk_notes
    ),
    build_theme_crosswalk(fl_metas, "FL", fl_rename, fl_var_labels)
  ) %>% relocate(theme, harmonized_name, variable_label, notes)

  level_maps <- bind_rows(lapply(cb_metas, `[[`, "level_map"))
  excluded <- bind_rows(
    bind_rows(lapply(hh_metas, `[[`, "excluded")),
    bind_rows(lapply(cb_metas, `[[`, "excluded")),
    bind_rows(lapply(cl_metas, `[[`, "excluded")),
    bind_rows(lapply(pr_metas, `[[`, "excluded")),
    bind_rows(lapply(fcf_metas, `[[`, "excluded")),
    bind_rows(lapply(fcd_metas, `[[`, "excluded")),
    bind_rows(lapply(fl_metas, `[[`, "excluded"))
  ) %>% arrange(theme, survey, source_var)

  if (!dir.exists(outdir)) dir.create(outdir, recursive = TRUE)

  rds_path  <- file.path(outdir, paste0(outfile, ".rds"))
  dta_path  <- file.path(outdir, paste0(outfile, ".dta"))
  xlsx_path <- file.path(outdir, "mics6_fs_variable_crosswalk.xlsx")

  write_rds(harmonized, rds_path)
  write_dta(harmonized, dta_path)
  write_fs_workbook(crosswalk, level_maps, excluded, fs_notes, xlsx_path)

  message("")
  message("Saved ", rds_path)
  message("Saved ", dta_path)
  message("Saved ", xlsx_path)
  message("Surveys appended: ", length(parts))
  message("Children: ", nrow(harmonized))
  message("Variables: ", ncol(harmonized))

  invisible(harmonized)
}

mics6_fs <- harmonize_mics_fs(root, outdir, outfile)
