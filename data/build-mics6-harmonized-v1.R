# Maintainer script: build analysis-ready merged MICS6 file for the R/Stata chapters.
# Not part of the public guide narrative.
#
# Inputs:
#   data/mics6_fs_harmonized.rds  (or mics6-fs-harmonized-v1.dta)
#   data/mics6_reading_harmonized.rds (or mics6-reading-harmonized-v1.dta)
#   data/MICS_Datasets/<SURVEY>/fs.sav  (HL4 = sex on the child row)
#
# Output:
#   data/mics6-harmonized-v1.dta

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
})

root <- if (file.exists("data/mics6_fs_harmonized.rds") ||
             file.exists("data/mics6-fs-harmonized-v1.dta")) {
  normalizePath(".", winslash = "/", mustWork = TRUE)
} else if (file.exists("../data/mics6_fs_harmonized.rds")) {
  normalizePath("..", winslash = "/", mustWork = TRUE)
} else {
  stop("Run from the mics-guide project root (folder that contains data/).")
}

data_dir <- file.path(root, "data")
mics_dir <- file.path(data_dir, "MICS_Datasets")

read_fs <- function() {
  rds <- file.path(data_dir, "mics6_fs_harmonized.rds")
  dta <- file.path(data_dir, "mics6-fs-harmonized-v1.dta")
  if (file.exists(rds)) return(readRDS(rds))
  if (file.exists(dta)) return(read_dta(dta))
  stop("FS harmonised file not found under data/.")
}

read_rd <- function() {
  rds <- file.path(data_dir, "mics6_reading_harmonized.rds")
  dta <- file.path(data_dir, "mics6-reading-harmonized-v1.dta")
  if (file.exists(rds)) return(readRDS(rds))
  if (file.exists(dta)) return(read_dta(dta))
  stop("Reading harmonised file not found under data/.")
}

numeracy_item_vars <- c(
  paste0("number_id_", 1:6),
  paste0("number_compare_", 1:5),
  paste0("number_add_", 1:5),
  paste0("number_pattern_", 1:5)
)

numeracy_score_from_items <- function(df, vars) {
  vars <- intersect(vars, names(df))
  if (!length(vars)) return(rep(NA_real_, nrow(df)))
  mat <- df[vars] %>%
    mutate(across(everything(), ~ {
      x <- suppressWarnings(as.integer(haven::zap_labels(.x)))
      if_else(!is.na(x) & x == 1L, 1, if_else(!is.na(x), 0, NA_real_))
    })) %>%
    as.matrix()
  n_nonmiss <- rowSums(!is.na(mat))
  score <- rowSums(mat, na.rm = TRUE)
  if_else(n_nonmiss > 0, as.numeric(score), NA_real_)
}

# Sex (HL4) from each survey's fs.sav (copied onto the child row in official MICS)
sex_from_fs <- function() {
  folders <- list.dirs(mics_dir, full.names = TRUE, recursive = FALSE)
  if (!length(folders)) {
    stop("No survey folders under ", mics_dir)
  }

  pieces <- list()
  for (folder in folders) {
    base <- basename(folder)
    m <- regexec("^([A-Z]{3})_([0-9]{4})", base)
    hit <- regmatches(base, m)[[1]]
    if (length(hit) < 3) next
    iso <- hit[[2]]
    year <- as.integer(hit[[3]])
    fs_path <- file.path(folder, "fs.sav")
    if (!file.exists(fs_path)) {
      message("Skip (no fs.sav): ", base)
      next
    }
    message("HL4 sex from fs.sav: ", base)
    d_fs <- read_sav(fs_path, col_select = any_of(c("HH1", "HH2", "LN", "HL4")))
    need <- c("HH1", "HH2", "LN", "HL4")
    if (!all(need %in% names(d_fs))) {
      message("  missing HL4 on fs.sav — skip")
      next
    }
    piece <- d_fs %>%
      transmute(
        country_iso3 = iso,
        year = year,
        HH1 = as.integer(haven::zap_labels(HH1)),
        HH2 = as.integer(haven::zap_labels(HH2)),
        LN = as.integer(haven::zap_labels(LN)),
        sex = as.integer(haven::zap_labels(HL4))
      ) %>%
      filter(!is.na(HH1), !is.na(HH2), !is.na(LN)) %>%
      distinct(country_iso3, year, HH1, HH2, LN, .keep_all = TRUE)
    pieces[[length(pieces) + 1L]] <- piece
  }
  bind_rows(pieces)
}

message("Reading FS + reading...")
fs <- read_fs()
rd <- read_rd() %>%
  select(
    any_of(c(
      "country_iso3", "year", "HH1", "HH2", "LN",
      "reading_status", "reading_score", "reading_accuracy", "reading_skills",
      "readingB_score", "readingB_accuracy", "readingB_skills",
      "read_comp_score", "passage_language", "passage_length"
    ))
  )

message("Collecting sex from fs.sav HL4...")
sex_tbl <- sex_from_fs()
message("Sex rows: ", nrow(sex_tbl))

# Align key types for joins
zap_key <- function(df) {
  df %>%
    mutate(
      HH1 = as.integer(haven::zap_labels(HH1)),
      HH2 = as.integer(haven::zap_labels(HH2)),
      LN = as.integer(haven::zap_labels(LN)),
      year = as.integer(year),
      country_iso3 = as.character(country_iso3)
    )
}

fs <- zap_key(fs)
rd <- zap_key(rd)

merged <- fs %>%
  left_join(rd, by = c("country_iso3", "year", "HH1", "HH2", "LN")) %>%
  left_join(sex_tbl, by = c("country_iso3", "year", "HH1", "HH2", "LN"))

merged$numeracy_score <- numeracy_score_from_items(merged, numeracy_item_vars)

# Private dummy: standard taxonomy public=1, religious=2, private=3
# (COD network codes differ — leave private NA there; chapter focuses on Ghana.)
merged <- merged %>%
  mutate(
    school_type_n = as.integer(haven::zap_labels(school_type)),
    private = case_when(
      country_iso3 == "COD" ~ NA_integer_,
      school_type_n == 3L ~ 1L,
      school_type_n %in% c(1L, 2L, 4L, 6L) ~ 0L,
      TRUE ~ NA_integer_
    )
  ) %>%
  select(-school_type_n)

# Light labels for analysis vars
merged$sex <- haven::labelled(
  merged$sex,
  labels = c(Male = 1, Female = 2)
)
merged$private <- haven::labelled(
  merged$private,
  labels = c("Non-private" = 0, Private = 1)
)

out_dta <- file.path(data_dir, "mics6-harmonized-v1.dta")
message("Writing ", out_dta, " ...")
write_dta(merged, out_dta)

cat(
  "Done.\n",
  "  rows: ", nrow(merged), "\n",
  "  cols: ", ncol(merged), "\n",
  "  sex non-missing: ", sum(!is.na(merged$sex)), "\n",
  "  private non-missing: ", sum(!is.na(merged$private)), "\n",
  "  numeracy_score non-missing: ", sum(!is.na(merged$numeracy_score)), "\n",
  "  reading_skills non-missing: ", sum(!is.na(merged$reading_skills)), "\n",
  sep = ""
)
