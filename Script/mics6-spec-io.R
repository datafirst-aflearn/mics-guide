# Shared loader for Data/AFLEARN Harmonised Data/mics6-crosswalk.xlsx
# Sourced by the harmonise and derive scripts. Does not write the workbook.

SPEC_DIR_DEFAULT  <- "Data/AFLEARN Harmonised Data"
SPEC_FILE_DEFAULT <- "mics6-crosswalk.xlsx"

spec_path <- function(outdir = SPEC_DIR_DEFAULT, file = SPEC_FILE_DEFAULT) {
  file.path(outdir, file)
}

read_spec_sheet <- function(path, sheet) {
  openxlsx::read.xlsx(path, sheet = sheet, detectDates = FALSE)
}

load_mics6_spec <- function(path = spec_path()) {
  if (!file.exists(path)) {
    stop(
      "Crosswalk spec not found:\n  ",
      normalizePath(path, winslash = "/", mustWork = FALSE),
      "\n\nThe workbook must sit next to the harmonised .dta, in:\n  ",
      "Data/AFLEARN Harmonised Data/mics6-crosswalk.xlsx\n\n",
      "On a first run, source Script/run-it.R (it copies Script/mics6-crosswalk.xlsx\n",
      "there if needed). Or copy that file in by hand, then re-run.",
      call. = FALSE
    )
  }
  sheets <- openxlsx::getSheetNames(path)
  needed <- c("how_to_read", "crosswalk", "level_map", "value_labels",
              "passage_language", "derived", "repairs", "surveys", "notes")
  missing <- setdiff(needed, sheets)
  if (length(missing) > 0) {
    stop("Spec is missing sheet(s): ", paste(missing, collapse = ", "))
  }

  how <- read_spec_sheet(path, "how_to_read")
  version <- as.character(how$value[match("version", how$item)])
  if (is.na(version) || !nzchar(version)) {
    stop("Spec how_to_read sheet has no version cell.")
  }

  surveys <- read_spec_sheet(path, "surveys")
  surveys$include <- as.logical(surveys$include)
  surveys$year <- as.integer(surveys$year)
  if ("ipums_sample" %in% names(surveys)) {
    surveys$ipums_sample <- as.numeric(surveys$ipums_sample)
  }

  list(
    path             = path,
    version          = version,
    how_to_read      = how,
    crosswalk        = read_spec_sheet(path, "crosswalk"),
    level_map        = read_spec_sheet(path, "level_map"),
    value_labels     = read_spec_sheet(path, "value_labels"),
    passage_language = read_spec_sheet(path, "passage_language"),
    derived          = read_spec_sheet(path, "derived"),
    repairs          = read_spec_sheet(path, "repairs"),
    surveys          = surveys,
    notes            = read_spec_sheet(path, "notes")
  )
}

included_surveys <- function(spec) {
  spec$surveys[isTRUE(spec$surveys$include) | spec$surveys$include %in% TRUE, , drop = FALSE]
}

survey_col <- function(iso, year) paste0(iso, "_", year)

harmonised_dta_path <- function(outdir, version) {
  file.path(outdir, paste0("mics6-fs-harmonised-v", version, ".dta"))
}

present <- function(x) !is.na(x)

eq <- function(x, v) !is.na(x) & x == v

ne_obs <- function(x, v) !is.na(x) & x != v

ge_obs <- function(x, y) !is.na(x) & !is.na(y) & x >= y

to_num <- function(x) {
  if (is.null(x)) return(NA_real_)
  as.numeric(unclass(x))
}

zap_value_labels_if_present <- function(df, vars) {
  for (v in intersect(vars, names(df))) {
    labelled::val_labels(df[[v]]) <- NULL
  }
  df
}

set_labels_if_present <- function(df, vars, labels) {
  for (v in intersect(vars, names(df))) {
    labelled::val_labels(df[[v]]) <- labels
  }
  df
}
