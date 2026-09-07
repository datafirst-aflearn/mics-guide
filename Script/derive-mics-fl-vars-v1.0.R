# derive-mics-fl-vars-v1.0.R
#
# Adds constructed FL/reading variables to the spec-driven harmonised file.
# Formulas are documented on the crosswalk `derived` sheet; this script is
# the reference implementation of those rows.
#
# Input/output (same path):
#   Data/AFLEARN Harmonised Data/mics6-fs-harmonised-v{version}.dta

if (!require(pacman)) install.packages("pacman")
pacman::p_load(tidyverse, haven, labelled, openxlsx)

outdir <- "Data/AFLEARN Harmonised Data"
source("Script/mics6-spec-io.R")

ensure <- function(df, vars) {
  gaps <- setdiff(vars, names(df))
  if (length(gaps) > 0) df[gaps] <- NA_real_
  df
}

comp_score <- function(df, prefix) {
  first <- paste0(prefix, "_1")
  if (!first %in% names(df)) return(NULL)
  items <- intersect(paste0(prefix, "_", 1:5), names(df))
  correct <- Reduce(`+`, lapply(items, function(v) as.integer(eq(df[[v]], 1))))
  if_else(is.na(df[[first]]), NA_real_, as.numeric(correct))
}

practice_outcome <- function(df, correct, q1, q2) {
  if (!correct %in% names(df)) return(NULL)
  df <- ensure(df, c(q1, q2))
  if_else(
    is.na(df[[correct]]),
    NA_real_,
    as.numeric(eq(df[[correct]], 1) & eq(df[[q1]], 1) & eq(df[[q2]], 1))
  )
}

row_max <- function(df, pattern) {
  cols <- grep(pattern, names(df), value = TRUE)
  if (length(cols) == 0) return(rep(NA_real_, nrow(df)))
  m <- as.matrix(df[cols])
  as.numeric(apply(m, 1, function(r) {
    if (all(is.na(r))) NA_real_ else max(r, na.rm = TRUE)
  }))
}

passage_len_by_lang <- function(words, lang) {
  out <- rep(NA_real_, length(words))
  ok <- !is.na(lang)
  if (!any(ok)) return(out)
  tmp <- tapply(words[ok], lang[ok], function(x) {
    if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
  })
  out[ok] <- unname(tmp[as.character(lang[ok])])
  out
}

assign_from_sheet <- function(d, spec, passage, dest, words_var) {
  pl <- spec$passage_language
  pl <- pl[pl$passage == passage, , drop = FALSE]
  if (nrow(pl) == 0 || !words_var %in% names(d)) return(d)
  d <- ensure(d, dest)
  for (i in seq_len(nrow(pl))) {
    iso <- pl$country_iso3[i]
    year <- as.integer(pl$year[i])
    code <- as.numeric(pl$code_h[i])
    hit <- d$country_iso3 == iso & as.integer(d$year) == year
    miss <- hit & is.na(d[[dest]]) & present(d[[words_var]])
    d[[dest]][miss] <- code
  }
  d
}

blank_refusal_words <- function(d) {
  # STP/MDG/CAF: blank word counts if child did not like the story or failed practice
  hit <- d$country_iso3 %in% c("STP", "MDG", "CAF")
  if (any(hit) && all(c("likestory", "practice_correct", "words_att") %in% names(d))) {
    drop1 <- hit & (!eq(d$likestory, 1) | ne_obs(d$practice_correct, 1))
    d$words_att[drop1] <- NA_real_
    if ("words_incorrect" %in% names(d)) d$words_incorrect[drop1] <- NA_real_
  }
  if (any(d$country_iso3 == "MDG")) {
    d <- ensure(d, c(
      "likestoryB", "likestoryC", "practiceB_correct", "practiceC_correct",
      "wordsB_att", "wordsB_incorrect", "wordsC_att", "wordsC_incorrect"
    ))
    mdg <- d$country_iso3 == "MDG"
    dropB <- mdg & (!eq(d$likestoryB, 1) | ne_obs(d$practiceB_correct, 1))
    dropC <- mdg & (!eq(d$likestoryC, 1) | ne_obs(d$practiceC_correct, 1))
    d$wordsB_att[dropB] <- NA_real_
    d$wordsB_incorrect[dropB] <- NA_real_
    d$wordsC_att[dropC] <- NA_real_
    d$wordsC_incorrect[dropC] <- NA_real_
  }
  d
}

zwe_passage_language <- function(d) {
  zwe <- d$country_iso3 == "ZWE"
  if (!any(zwe)) return(d)
  d <- ensure(d, c("lang_school_h", "lang_home_h", "anotherstory_h", "likestoryB_h",
                   "words_att", "passage_language", "passageB_language"))
  pl <- if_else(present(d$lang_school_h) & d$lang_school_h < 9000,
                d$lang_school_h, NA_real_)
  pl <- if_else(is.na(d$words_att), NA_real_, pl)
  pl <- if_else(
    is.na(pl) & present(d$words_att) & present(d$lang_home_h) & d$lang_home_h < 9000,
    d$lang_home_h, pl
  )
  pl <- if_else(
    present(d$words_att) & present(d$anotherstory_h) & d$anotherstory_h > 99,
    d$anotherstory_h, pl
  )
  pb <- if_else(
    present(d$likestoryB_h) & d$likestoryB_h != 95,
    d$likestoryB_h, NA_real_
  )
  d$passage_language[zwe] <- pl[zwe]
  d$passageB_language[zwe] <- pb[zwe]
  d
}

in_range <- function(x, lo, hi) present(x) & x >= lo & x <= hi

child_refuses <- function(d) {
  d <- ensure(d, c("likestory", "anotherstory", "anotherstory_h",
                   "likestoryB", "likestoryB_h", "likestoryC"))
  out <- as.numeric(ne_obs(d$likestory, 1))
  swz <- d$country_iso3 == "SWZ"
  out <- if_else(
    swz & (eq(d$anotherstory, 95) | eq(d$anotherstory_h, 95) |
             in_range(d$likestoryB, 95, 96) | in_range(d$likestoryB_h, 95, 96)),
    1, out
  )
  lm <- d$country_iso3 %in% c("LSO", "MDG")
  out <- if_else(lm & (ne_obs(d$likestoryB, 1) | ne_obs(d$likestoryC, 1)), 1, out)
  nga <- d$country_iso3 == "NGA"
  out <- if_else(
    nga & (eq(d$anotherstory, 95) | eq(d$anotherstory_h, 95) |
             eq(d$likestoryB, 95) | eq(d$likestoryB_h, 95)),
    1, out
  )
  zwe <- d$country_iso3 == "ZWE"
  out <- if_else(
    zwe & (eq(d$anotherstory, 95) | eq(d$anotherstory_h, 95) |
             eq(d$likestoryB, 95) | eq(d$likestoryB_h, 95)),
    1, out
  )
  com <- d$country_iso3 == "COM"
  out <- if_else(
    com & (in_range(d$anotherstory, 95, 96) | in_range(d$anotherstory_h, 95, 96)),
    1, out
  )
  out
}

apply_derived_labels <- function(df, spec) {
  vl <- spec$value_labels
  cw <- spec$crosswalk
  for (dn in c("pass_fail", "reading_status", "language_h", "yes_no",
               "numeracy_item", "ipums_sample")) {
    block <- vl[vl$dictionary == dn, ]
    if (nrow(block) == 0) next
    labs <- setNames(as.numeric(block$code), as.character(block$label))
    vars <- cw$harmonized_name[cw$dictionary == dn & cw$label_action == "impose"]
    df <- set_labels_if_present(df, vars, labs)
  }
  labs <- cw$variable_label
  names(labs) <- cw$harmonized_name
  labs <- labs[names(labs) %in% names(df)]
  labs <- labs[!is.na(labs) & nzchar(labs)]
  if (length(labs) > 0) labelled::var_label(df) <- as.list(labs)
  df
}

derive_mics_fl_vars <- function(outdir = "Data/AFLEARN Harmonised Data") {
  spec <- load_mics6_spec(spec_path(outdir))
  dta <- harmonised_dta_path(outdir, spec$version)
  if (!file.exists(dta)) stop("Harmonised file not found: ", dta)
  d <- haven::read_dta(dta)

  d <- blank_refusal_words(d)
  d <- zwe_passage_language(d)
  d <- assign_from_sheet(d, spec, "A", "passage_language", "words_att")
  d <- assign_from_sheet(d, spec, "B", "passageB_language", "wordsB_att")
  d <- assign_from_sheet(d, spec, "C", "passageC_language", "wordsC_att")
  d <- ensure(d, c("passage_language", "passageB_language", "passageC_language"))

  d <- ensure(d, c("words_att", "words_incorrect", "wordsB_att", "wordsB_incorrect",
                   "wordsC_att", "wordsC_incorrect"))
  d$passage_length <- passage_len_by_lang(d$words_att, d$passage_language)
  d$passageB_length <- passage_len_by_lang(d$wordsB_att, d$passageB_language)
  d$passageC_length <- passage_len_by_lang(d$wordsC_att, d$passageC_language)

  d$reading_score <- d$words_att - d$words_incorrect
  d$readingB_score <- d$wordsB_att - d$wordsB_incorrect
  d$readingC_score <- d$wordsC_att - d$wordsC_incorrect

  d$read_comp_score <- comp_score(d, "read_comp")
  sb <- comp_score(d, "read_compB")
  if (!is.null(sb)) d$read_compB_score <- sb else d <- ensure(d, "read_compB_score")
  sc <- comp_score(d, "read_compC")
  if (!is.null(sc)) d$read_compC_score <- sc else d <- ensure(d, "read_compC_score")

  d$practice_outcome <- practice_outcome(
    d, "practice_correct", "practice_question1", "practice_question2"
  )
  d$practiceB_outcome <- practice_outcome(
    d, "practiceB_correct", "practiceB_question1", "practiceB_question2"
  )
  d$practiceC_outcome <- practice_outcome(
    d, "practiceC_correct", "practiceC_question1", "practiceC_question2"
  )
  d <- ensure(d, c("practice_outcome", "practiceB_outcome", "practiceC_outcome"))
  d$fail_practice <- 1 - d$practice_outcome
  d$fail_practice <- if_else(eq(d$practiceB_outcome, 0), 1, d$fail_practice)
  d$fail_practice <- if_else(eq(d$practiceC_outcome, 0), 1, d$fail_practice)

  skills_one <- function(score, comp, length) {
    cutoff <- trunc(0.9 * length)
    if_else(
      present(score),
      as.numeric(eq(comp, 5) & ge_obs(score, cutoff)),
      NA_real_
    )
  }
  pct_one <- function(score, length) {
    cutoff <- trunc(0.9 * length)
    if_else(present(score), as.numeric(ge_obs(score, cutoff)), NA_real_)
  }
  d <- ensure(d, c("read_comp_score", "read_compB_score", "read_compC_score"))
  d$reading_accuracy <- d$reading_score / d$passage_length
  d$readingB_accuracy <- d$readingB_score / d$passageB_length
  d$readingC_accuracy <- d$readingC_score / d$passageC_length
  d$reading_skills <- skills_one(d$reading_score, d$read_comp_score, d$passage_length)
  d$readingB_skills <- skills_one(d$readingB_score, d$read_compB_score, d$passageB_length)
  d$readingC_skills <- skills_one(d$readingC_score, d$read_compC_score, d$passageC_length)
  d$reading_90pct <- pct_one(d$reading_score, d$passage_length)
  d$readingB_90pct <- pct_one(d$readingB_score, d$passageB_length)
  d$readingC_90pct <- pct_one(d$readingC_score, d$passageC_length)

  d <- ensure(d, c("child_consent", "ever_attended", "enrolled", "likestory",
                   "lang_school", "lang_home", "fl_consent", "interview_result", "age"))
  d$lang_mismatch <- as.numeric(
    eq(d$child_consent, 1) &
      ((eq(d$ever_attended, 1) & is.na(d$likestory) & present(d$lang_school)) |
         ((eq(d$enrolled, 2) | eq(d$ever_attended, 2)) &
            is.na(d$likestory) & present(d$lang_home)))
  )
  d$child_refuses_read <- child_refuses(d)

  d$max_reading_score <- row_max(d, "^reading(_|B_|C_)score$")
  d$max_reading_accuracy <- row_max(d, "^reading(_|B_|C_)accuracy$")
  d$max_reading_90pct <- row_max(d, "^reading(_|B_|C_)90pct$")
  d$max_reading_skills <- row_max(d, "^reading(_|B_|C_)skills$")

  d$reading_status <- if_else(present(d$interview_result) & d$interview_result > 1,
                              0, NA_real_)
  d$reading_status <- if_else(present(d$age) & (d$age < 7 | d$age > 14),
                              1, d$reading_status)
  d$reading_status <- if_else(ne_obs(d$fl_consent, 1) & is.na(d$reading_status),
                              2, d$reading_status)
  d$reading_status <- if_else(ne_obs(d$child_consent, 1) & is.na(d$reading_status),
                              3, d$reading_status)
  d$reading_status <- if_else(eq(d$lang_mismatch, 1) & is.na(d$reading_status),
                              4, d$reading_status)
  d$reading_status <- if_else(eq(d$child_refuses_read, 1), 5, d$reading_status)
  d$reading_status <- if_else(eq(d$fail_practice, 1), 6, d$reading_status)
  d$reading_status <- if_else(present(d$max_reading_score), 7, d$reading_status)
  d$reading_status <- if_else(eq(d$max_reading_90pct, 1), 8, d$reading_status)
  d$reading_status <- if_else(eq(d$max_reading_skills, 1), 9, d$reading_status)
  d$reading_status <- if_else(is.na(d$reading_status), 10, d$reading_status)

  d <- apply_derived_labels(d, spec)

  ord <- intersect(spec$crosswalk$harmonized_name, names(d))
  extra <- setdiff(names(d), ord)
  d <- d[c(ord, extra)]

  haven::write_dta(d, dta)
  message("Wrote ", dta, " (", nrow(d), " rows, ", ncol(d), " cols) with derived variables")
  invisible(d)
}

mics6_fs <- derive_mics_fl_vars(outdir)
