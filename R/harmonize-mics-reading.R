# harmonize-mics-reading.R
#
# Build one cross-country dataset of MICS6 foundational reading outcomes from
# the per-survey fs.sav files produced by R/prepare-mics-fs.R.
#
# Run from the mics-guide project root:
#     source("R/harmonize-mics-reading.R")
#
# Input :  data/MICS_Datasets/<ISO>_<YEAR>_MICS6_v01_M/fs.sav
# Output:  data/mics6_reading_harmonized.dta and .rds


if (!require(pacman)) install.packages("pacman")
pacman::p_load(tidyverse, haven, labelled)

root    <- "data/MICS_Datasets"
outdir  <- "data"
outfile <- "mics6_reading_harmonized"

# Surveys whose reading passage language and length are defined below.
supported <- c(
  "BEN", "CAF", "COD", "COM", "GHA", "GMB", "GNB", "LSO", "MDG",
  "MWI", "NGA", "SLE", "STP", "SWZ", "TCD", "TGO", "TUN", "ZWE"
)

# Variables the pipeline needs. Questionnaires differ, so any that a survey
# does not carry are created as missing rather than stopping the run.
required_vars <- c(
  "age", "consent", "child_consent", "enrolled", "ever_attended", "likestory",
  "lang_home", "lang_school", "interview_result", "words_att", "words_incorrect",
  "practice_correct", "practice_question1", "practice_question2",
  paste0("read_comp_", 1:5)
)

# ---------------------------------------------------------------------------
# Stata missing-value rules, written out explicitly
#
# In Stata, missing sorts above every number, so `x < .` means "non-missing"
# and a comparison involving missing is usually FALSE rather than missing.
# These helpers keep the R translation faithful to that behaviour.
# ---------------------------------------------------------------------------

present <- function(x) !is.na(x)                       # Stata: x < .
eq      <- function(x, v) !is.na(x) & x == v           # Stata: x == v
ne_obs  <- function(x, v) !is.na(x) & x != v           # Stata: x != v & x < .
ge_obs  <- function(x, y) !is.na(x) & !is.na(y) & x >= y

# Create any listed variables that the survey does not have.
ensure <- function(df, vars) {
  gaps <- setdiff(vars, names(df))
  if (length(gaps) > 0) {
    df[gaps] <- NA_real_
    message("    note: not in this survey, created as missing: ",
            paste(gaps, collapse = ", "))
  }
  df
}

# Rename one variable only if the old name exists and the new one is still
# free. This reproduces Stata's `capture rename`: a survey that never asked a
# question simply keeps its own names, and the first matching alternative for
# a target name wins.
rename_map <- c(
  age                 = "CB3",
  child_consent       = "FL3",
  child_line_num      = "FS3",
  consent             = "FL1",
  edgrade_curr        = "CB8B",
  edlevel_curr        = "CB8A",
  enrolled            = "CB7",
  ever_attended       = "CB4",
  household_num       = "FS2",
  interview_day       = "FS7D",
  interview_month     = "FS7M",
  interview_result    = "FS17",
  interview_year      = "FS7Y",
  lang_home           = "FL7",
  lang_school         = "FL9",
  lang_school         = "FL9A",
  lang_school_fl9b    = "FL9B",
  likestory           = "FL10",
  practice_correct    = "FL14",
  practice_question1  = "FL15",
  practice_question2  = "FL17",
  practiceB_correct   = "FL114",
  practiceB_question1 = "FL115",
  practiceB_question2 = "FL117",
  practiceC_correct   = "FL214",
  practiceB_correct   = "FL21H",
  practiceC_question1 = "FL215",
  practiceB_question1 = "FL21I",
  practiceC_question2 = "FL217",
  practiceB_question2 = "FL21K",
  read_comp_1         = "FL22A",
  read_comp_2         = "FL22B",
  read_comp_3         = "FL22C",
  read_comp_4         = "FL22D",
  read_comp_5         = "FL22E",
  read_compB_1        = "FL122A",
  read_compB_2        = "FL122B",
  read_compB_3        = "FL122C",
  read_compB_4        = "FL122D",
  read_compB_5        = "FL122E",
  read_compC_1        = "FL222A",
  read_compC_2        = "FL222B",
  read_compC_3        = "FL222C",
  read_compC_4        = "FL222D",
  read_compC_5        = "FL222E",
  read_compB_1        = "FLB22A",
  read_compB_2        = "FLB22B",
  read_compB_3        = "FLB22C",
  read_compB_4        = "FLB22D",
  read_compB_5        = "FLB22E",
  read_compB_1        = "FL21BA",
  read_compB_2        = "FL21BB",
  read_compB_3        = "FL21BC",
  read_compB_4        = "FL21BD",
  read_compB_5        = "FL21BE",
  words_att           = "FL20A",
  words_incorrect     = "FL20B",
  wordsB_att          = "FL21PA",
  wordsB_att          = "FL120A",
  wordsB_att          = "FLB20A",
  wordsB_incorrect    = "FL21PB",
  wordsB_incorrect    = "FL120B",
  wordsB_incorrect    = "FLB20B",
  wordsC_att          = "FL220A",
  wordsC_incorrect    = "FL220B",
  result              = "FL29"
)

apply_rename_map <- function(df, map = rename_map) {
  for (i in seq_along(map)) {
    new <- names(map)[i]
    old <- unname(map[i])
    if (old %in% names(df) && !(new %in% names(df))) {
      names(df)[names(df) == old] <- new
    }
  }
  df
}

# Number of the five comprehension items answered correctly. Missing when the
# first item was not asked.
comp_score <- function(df, prefix) {
  first <- paste0(prefix, "_1")
  if (!first %in% names(df)) return(NULL)
  items <- intersect(paste0(prefix, "_", 1:5), names(df))
  correct <- Reduce(`+`, lapply(items, function(v) as.integer(eq(df[[v]], 1))))
  if_else(is.na(df[[first]]), NA_real_, as.numeric(correct))
}

# Passed the practice sentence and both practice questions.
practice_outcome <- function(df, correct, q1, q2) {
  if (!correct %in% names(df)) return(NULL)
  if_else(
    is.na(df[[correct]]),
    NA_real_,
    as.numeric(eq(df[[correct]], 1) & eq(df[[q1]], 1) & eq(df[[q2]], 1))
  )
}

# Row-wise maximum across the passages a child attempted.
row_max <- function(df, pattern) {
  cols <- grep(pattern, names(df), value = TRUE)
  if (length(cols) == 0) return(rep(NA_real_, nrow(df)))
  m <- as.matrix(df[cols])
  as.numeric(apply(m, 1, function(r) {
    if (all(is.na(r))) NA_real_ else max(r, na.rm = TRUE)
  }))
}

# ---------------------------------------------------------------------------
# Harmonise a single survey
# ---------------------------------------------------------------------------

harmonize_survey <- function(path, iso, year) {

  # zap_labels keeps the underlying numeric codes, so every comparison below
  d <- read_sav(path) %>% zap_labels()

  # 1. Fix questionnaire numbering before harmonising -----------------------
  if (iso == "ZWE") {
    d <- d %>% rename(FL22D = "FL22E", FL22E = "FL22F")
  }
  if (iso == "COM") {
    d <- d %>% rename(FL21BD = "FL21BE", FL21BE = "FL21BF")
    b_cols <- grep("^FL21B[A-Z]$", names(d), value = TRUE)
    names(d)[match(b_cols, names(d))] <- sub("^FL21B", "FL22", b_cols)
  }

  # 2. Harmonise variable names --------------------------------------------
  d <- d %>% apply_rename_map() %>% ensure(required_vars)

  # 3. Sierra Leone: attempted and incorrect are swapped for some records ---
  # The guard is words_incorrect non-missing. Allowing missing here would copy
  # words_att into words_incorrect and turn a missing score into a zero.
  if (iso == "SLE") {
    swap <- present(d$words_incorrect) & present(d$words_att) &
      d$words_att < d$words_incorrect
    d <- d %>% mutate(
      words_att       = if_else(swap, d$words_incorrect, words_att),
      words_incorrect = if_else(swap, d$words_att, words_incorrect)
    )
  }

  # 4. Reading score: words attempted less words incorrect or missed --------
  d <- d %>% mutate(reading_score = words_att - words_incorrect)

  if ("wordsB_att" %in% names(d)) {
    d <- d %>% ensure("wordsB_incorrect") %>%
      mutate(readingB_score = wordsB_att - wordsB_incorrect)
  }
  if ("wordsC_att" %in% names(d)) {
    d <- d %>% ensure("wordsC_incorrect") %>%
      mutate(readingC_score = wordsC_att - wordsC_incorrect)
  }

  # 5. Surveys where refusers and practice failures still have word counts --
  if (iso %in% c("STP", "CAF", "MDG")) {
    drop1 <- !eq(d$likestory, 1) | ne_obs(d$practice_correct, 1)
    d <- d %>% mutate(
      reading_score   = if_else(drop1, NA_real_, reading_score),
      words_att       = if_else(drop1, NA_real_, words_att),
      words_incorrect = if_else(drop1, NA_real_, words_incorrect)
    )
  }
  if (iso == "MDG") {
    d <- d %>% ensure(c("FL110", "FL210", "practiceB_correct", "practiceC_correct"))
    dropB <- !eq(d$FL110, 1) | ne_obs(d$practiceB_correct, 1)
    dropC <- !eq(d$FL210, 1) | ne_obs(d$practiceC_correct, 1)
    d <- d %>% mutate(
      readingB_score   = if_else(dropB, NA_real_, readingB_score),
      wordsB_att       = if_else(dropB, NA_real_, wordsB_att),
      wordsB_incorrect = if_else(dropB, NA_real_, wordsB_incorrect),
      readingC_score   = if_else(dropC, NA_real_, readingC_score),
      wordsC_att       = if_else(dropC, NA_real_, wordsC_att),
      wordsC_incorrect = if_else(dropC, NA_real_, wordsC_incorrect)
    )
  }

  # 6. Comprehension scores ------------------------------------------------
  d$read_comp_score <- comp_score(d, "read_comp")

  scoreB <- comp_score(d, "read_compB")
  if (!is.null(scoreB)) d$read_compB_score <- scoreB

  scoreC <- comp_score(d, "read_compC")
  if (!is.null(scoreC)) d$read_compC_score <- scoreC

  # 7. Practice outcomes ---------------------------------------------------
  d$practice_outcome <- practice_outcome(d, "practice_correct",
                                         "practice_question1", "practice_question2")
  d$fail_practice <- 1 - d$practice_outcome

  if ("practiceB_correct" %in% names(d)) {
    d <- d %>% ensure(c("practiceB_question1", "practiceB_question2"))
    d$practiceB_outcome <- practice_outcome(d, "practiceB_correct",
                                            "practiceB_question1", "practiceB_question2")
    d$fail_practice <- if_else(eq(d$practiceB_outcome, 0), 1, d$fail_practice)
  }
  if ("practiceC_correct" %in% names(d)) {
    d <- d %>% ensure(c("practiceC_question1", "practiceC_question2"))
    d$practiceC_outcome <- practice_outcome(d, "practiceC_correct",
                                            "practiceC_question1", "practiceC_question2")
    d$fail_practice <- if_else(eq(d$practiceC_outcome, 0), 1, d$fail_practice)
  }

  # 8. Passage language and length -----------------------------------------
  # Accuracy needs a denominator, so every survey needs passage_length.
  if (iso == "NGA") {
    d <- d %>% ensure(c("lang1", "lang2", "FL10C", "wordsB_att")) %>% mutate(
      passage_language = case_when(
        eq(lang1, 11) ~ 1010, eq(lang1, 12) ~ 3190,
        eq(lang1, 13) ~ 4101, eq(lang1, 14) ~ 4102,
        TRUE ~ as.numeric(lang1)
      ),
      passageB_language = case_when(
        eq(lang2, 11) ~ 1010, eq(lang2, 12) ~ 3190,
        eq(lang2, 13) ~ 4101, eq(lang2, 14) ~ 4102,
        TRUE ~ as.numeric(lang2)
      ),
      passage_length = case_when(
        eq(passage_language, 1010) & present(words_att) ~ 72,
        eq(passage_language, 3190) & present(words_att) ~ 76,
        eq(passage_language, 4101) & present(words_att) ~ 88,
        eq(passage_language, 4102) & present(words_att) ~ 81,
        TRUE ~ NA_real_
      ),
      passageB_length = case_when(
        eq(passageB_language, 1010) & present(wordsB_att) ~ 61,
        (eq(passageB_language, 3190) | eq(passageB_language, 4102)) &
          present(wordsB_att) ~ 63,
        eq(passageB_language, 4101) & present(wordsB_att) ~ 59,
        TRUE ~ NA_real_
      )
    )
  }
  if (iso == "SWZ") {
    d <- d %>% ensure(c("langS1", "langS2", "FL10C", "FL21D", "wordsB_att")) %>% mutate(
      passage_language = case_when(
        eq(langS1, 11) ~ 1010, eq(langS1, 12) ~ 3220, TRUE ~ as.numeric(langS1)
      ),
      passageB_language = case_when(
        eq(langS2, 11) ~ 1010, eq(langS2, 12) ~ 3220, TRUE ~ as.numeric(langS2)
      ),
      passage_length = case_when(
        eq(passage_language, 1010) & present(words_att) ~ 74,
        eq(passage_language, 3220) & present(words_att) ~ 41,
        TRUE ~ NA_real_
      ),
      passageB_length = case_when(
        eq(passageB_language, 1010) & present(wordsB_att) ~ 74,
        eq(passageB_language, 3220) & present(wordsB_att) ~ 41,
        TRUE ~ NA_real_
      )
    )
  }
  if (iso == "LSO") {
    d <- d %>% ensure(c("FL100", "FL110", "FL210", "wordsB_att", "wordsC_att")) %>% mutate(
      passage_language = case_when(
        eq(FL100, 1) ~ 3080, eq(FL100, 2) ~ 1010, eq(FL100, 3) ~ NA_real_,
        TRUE ~ as.numeric(FL100)
      ),
      passage_length = case_when(
        eq(passage_language, 3080) & present(words_att) ~ 64,
        eq(passage_language, 1010) & present(words_att) ~ 71,
        TRUE ~ NA_real_
      ),
      passageB_language = if_else(present(wordsB_att), 1010, NA_real_),
      passageC_language = if_else(present(wordsC_att), 3080, NA_real_),
      passageB_length   = if_else(present(wordsB_att), 64, NA_real_),
      passageC_length   = if_else(present(wordsC_att), 71, NA_real_)
    )
  }
  if (iso == "MDG") {
    d <- d %>% ensure(c("FL100", "wordsB_att", "wordsC_att")) %>% mutate(
      passage_language = case_when(
        eq(FL100, 1) ~ 6020, eq(FL100, 2) ~ 1020, eq(FL100, 3) ~ NA_real_,
        TRUE ~ as.numeric(FL100)
      ),
      passage_length = case_when(
        eq(passage_language, 6020) & present(words_att) ~ 84,
        eq(passage_language, 1020) & present(words_att) ~ 64,
        TRUE ~ NA_real_
      ),
      passageB_language = if_else(present(wordsB_att), 6020, NA_real_),
      passageB_length   = if_else(present(wordsB_att), 84, NA_real_),
      passageC_language = if_else(present(wordsC_att), 1020, NA_real_),
      passageC_length   = if_else(present(wordsC_att), 64, NA_real_)
    )
  }
  if (iso == "MWI") {
    d <- d %>% ensure("wordsB_att") %>% mutate(
      passage_language  = if_else(present(words_att), 1010, NA_real_),
      passageB_language = if_else(present(wordsB_att), 3160, NA_real_),
      passage_length    = if_else(present(words_att), 61, NA_real_),
      passageB_length   = if_else(present(wordsB_att), 74, NA_real_)
    )
  }
  if (iso == "ZWE") {
    d <- d %>% ensure(c("FL10C", "FL21D", "wordsB_att")) %>% mutate(
      passage_language = case_when(
        eq(lang_school, 1) ~ 1010,
        eq(lang_school, 2) ~ 3140,
        eq(lang_school, 3) ~ 3150,
        present(lang_school) & lang_school >= 7 & lang_school <= 9 ~ NA_real_,
        TRUE ~ as.numeric(lang_school)
      ),
      passage_language = if_else(is.na(words_att), NA_real_, passage_language),
      passage_language = case_when(
        eq(lang_home, 1) & is.na(passage_language) & present(words_att) ~ 1010,
        eq(lang_home, 2) & is.na(passage_language) & present(words_att) ~ 3140,
        eq(lang_home, 3) & is.na(passage_language) & present(words_att) ~ 3150,
        TRUE ~ passage_language
      ),
      passage_language = case_when(
        eq(FL10C, 1) & present(words_att) ~ 1010,
        eq(FL10C, 2) & present(words_att) ~ 3140,
        eq(FL10C, 3) & present(words_att) ~ 3150,
        TRUE ~ passage_language
      ),
      passageB_language = case_when(
        eq(FL21D, 1) ~ 1010, eq(FL21D, 2) ~ 3140, eq(FL21D, 3) ~ 3150,
        eq(FL21D, 5) ~ NA_real_, TRUE ~ as.numeric(FL21D)
      ),
      passage_length  = if_else(present(words_att), 72, NA_real_),
      passageB_length = if_else(present(wordsB_att), 62, NA_real_)
    )
  }

  # Single-language surveys: one passage length, one language.
  one_length <- c(TUN = 72, SLE = 72, GNB = 72, GMB = 72,
                  BEN = 81, TCD = 81, COM = 81, TGO = 81,
                  GHA = 69, CAF = 87, COD = 85, STP = 76)
  if (iso %in% names(one_length)) {
    len <- unname(one_length[iso])
    d <- d %>% mutate(passage_length = if_else(present(words_att), len, NA_real_))
  }

  one_language <- c(GHA = 1010, SLE = 1010, GMB = 1010,
                    BEN = 1020, CAF = 1020, TCD = 1020,
                    COM = 1020, COD = 1020, TGO = 1020,
                    STP = 1040, GNB = 1040)
  if (iso %in% names(one_language)) {
    lng <- unname(one_language[iso])
    d <- d %>% mutate(
      passage_language = if_else(present(reading_score), lng, NA_real_)
    )
  }

  # Tunisia has a passage length but no language code in this scheme.
  d <- d %>% ensure(c("passage_language", "passage_length"))

  # 9. Accuracy and foundational reading skills -----------------------------
  d <- d %>% mutate(
    reading_accuracy = reading_score / passage_length,
    cutoff = trunc(0.9 * passage_length),
    reading_skills = if_else(
      present(reading_score),
      as.numeric(eq(read_comp_score, 5) & ge_obs(reading_score, cutoff)),
      NA_real_
    )
  )

  if ("readingB_score" %in% names(d)) {
    d <- d %>% ensure(c("passageB_length", "read_compB_score")) %>% mutate(
      readingB_accuracy = readingB_score / passageB_length,
      cutoffB = trunc(0.9 * passageB_length),
      readingB_skills = if_else(
        present(readingB_score),
        as.numeric(eq(read_compB_score, 5) & ge_obs(readingB_score, cutoffB)),
        NA_real_
      )
    )
  }
  if ("readingC_score" %in% names(d)) {
    d <- d %>% ensure(c("passageC_length", "read_compC_score")) %>% mutate(
      readingC_accuracy = readingC_score / passageC_length,
      cutoffC = trunc(0.9 * passageC_length),
      readingC_skills = if_else(
        present(readingC_score),
        as.numeric(eq(read_compC_score, 5) & ge_obs(readingC_score, cutoffC)),
        NA_real_
      )
    )
  }

  # 10. Lesotho and Madagascar: fold the third passage into the B slots -----
  if (iso %in% c("LSO", "MDG")) {
    pairs <- c(
      wordsB_att = "wordsC_att", wordsB_incorrect = "wordsC_incorrect",
      practiceB_outcome = "practiceC_outcome", practiceB_correct = "practiceC_correct",
      practiceB_question1 = "practiceC_question1",
      practiceB_question2 = "practiceC_question2",
      readingB_score = "readingC_score", readingB_accuracy = "readingC_accuracy",
      readingB_skills = "readingC_skills", passageB_length = "passageC_length",
      passageB_language = "passageC_language", read_compB_score = "read_compC_score",
      read_compB_1 = "read_compC_1", read_compB_2 = "read_compC_2",
      read_compB_3 = "read_compC_3", read_compB_4 = "read_compC_4",
      read_compB_5 = "read_compC_5", cutoffB = "cutoffC"
    )
    for (i in seq_along(pairs)) {
      b <- names(pairs)[i]
      cc <- unname(pairs[i])
      if (b %in% names(d) && cc %in% names(d)) {
        d[[b]] <- if_else(present(d[[cc]]), d[[cc]], d[[b]])
      }
    }
    d <- d %>% select(-matches("^(read_compC|passageC_|readingC_|wordsC_|practiceC)"),
                      -any_of("cutoffC"))
  }

  # 11. Outcome of the reading assessment ----------------------------------
  d <- d %>% mutate(
    lang_mismatch = as.numeric(
      eq(child_consent, 1) &
        ((eq(ever_attended, 1) & is.na(likestory) & present(lang_school)) |
           ((eq(enrolled, 2) | eq(ever_attended, 2)) &
              is.na(likestory) & present(lang_home)))
    ),
    child_refuses_read = as.numeric(ne_obs(likestory, 1))
  )

  if (iso == "SWZ") {
    d <- d %>% mutate(child_refuses_read = if_else(
      eq(FL10C, 95) | (present(FL21D) & FL21D >= 95), 1, child_refuses_read))
  }
  if (iso %in% c("LSO", "MDG")) {
    d <- d %>% mutate(child_refuses_read = if_else(
      ne_obs(FL110, 1) | ne_obs(FL210, 1), 1, child_refuses_read))
  }
  if (iso == "NGA") {
    d <- d %>% mutate(child_refuses_read = if_else(
      eq(FL10C, 95), 1, child_refuses_read))
  }
  if (iso == "ZWE") {
    d <- d %>% mutate(child_refuses_read = if_else(
      eq(FL10C, 5) | eq(FL21D, 5), 1, child_refuses_read))
  }
  if (iso == "COM") {
    d <- d %>% mutate(child_refuses_read = if_else(
      present(FL10C) & FL10C >= 95 & FL10C <= 99, 1, child_refuses_read))
  }

  # Best result across the passages a child attempted.
  d$max_reading_score    <- row_max(d, "^reading[A-Za-z]*_score$")
  d$max_reading_accuracy <- row_max(d, "^reading[A-Za-z]*_accuracy$")
  d$max_reading_skills   <- row_max(d, "^reading[A-Za-z]*_skills$")

  # Ordered classification. Codes 2 to 4 only fill gaps; 5 to 8 overwrite.
  d <- d %>% mutate(
    reading_status = if_else(present(interview_result) & interview_result > 1,
                             0, NA_real_),
    reading_status = if_else(present(age) & (age < 7 | age > 14),
                             1, reading_status),
    reading_status = if_else(ne_obs(consent, 1) & is.na(reading_status),
                             2, reading_status),
    reading_status = if_else(ne_obs(child_consent, 1) & is.na(reading_status),
                             3, reading_status),
    reading_status = if_else(eq(lang_mismatch, 1) & is.na(reading_status),
                             4, reading_status),
    reading_status = if_else(eq(child_refuses_read, 1), 5, reading_status),
    reading_status = if_else(eq(fail_practice, 1), 6, reading_status),
    reading_status = if_else(present(max_reading_score), 7, reading_status),
    reading_status = if_else(eq(max_reading_skills, 1), 8, reading_status)
  )

  # 12. Keys for merging with IPUMS-MICS -----------------------------------
  keys <- c("HH1", "HH2", "LN")
  if (!all(keys %in% names(d))) {
    stop("Missing identifier columns in ", path)
  }
  if (anyDuplicated(d[keys]) > 0) {
    stop("HH1 HH2 LN do not uniquely identify children in ", path)
  }

  d <- d %>% mutate(
    cluster       = HH1,
    hhno          = HH2,
    linech        = LN,
    country_iso3  = iso,
    year          = as.numeric(year)
  )

  # 13. Keep the analysis variables that this survey actually has ----------
  d %>% select(
    any_of(c("country_iso3", "year", "cluster", "hhno", "linech",
             "HH1", "HH2", "LN", "reading_status",
             "age", "consent", "child_consent", "enrolled", "ever_attended",
             "lang_home", "lang_school", "lang_mismatch", "child_refuses_read",
             "fail_practice")),
    matches("^words"), matches("^cutoff"), matches("^max_reading_"),
    matches("^reading"), matches("^read_comp"), matches("^practice"),
    matches("^passage")
  )
}

# ---------------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------------

set_labels_if_present <- function(df, vars, labels) {
  for (v in intersect(vars, names(df))) {
    val_labels(df[[v]]) <- labels
  }
  df
}

apply_labels <- function(df) {
  df <- df %>%
    set_labels_if_present("reading_status", c(
      "Not interviewed"                              = 0,
      "Age <7 or >14"                                = 1,
      "Caregiver refused"                            = 2,
      "Child refused"                                = 3,
      "Language does not match"                      = 4,
      "Child does not want to read story"            = 5,
      "Failed practice sentence and questions"       = 6,
      "Attempted passage"                            = 7,
      "90% of words and all comp. questions correct" = 8
    )) %>%
    set_labels_if_present(c("passage_language", "passageB_language"), c(
      English = 1010, French = 1020, Portuguese = 1040, Sesotho = 3080,
      Shona = 3140, Ndebele = 3150, Chichewa = 3160, Hausa = 3190,
      Siswati = 3220, Igbo = 4101, Yoruba = 4102, Malagasy = 6020
    )) %>%
    set_labels_if_present(c("practice_correct", "practiceB_correct"), c(
      Yes = 1, No = 2, "No response" = 9
    )) %>%
    set_labels_if_present(c("practice_outcome", "practiceB_outcome"), c(
      Failed = 0, Passed = 1
    )) %>%
    set_labels_if_present(c("reading_skills", "readingB_skills"), c(
      No = 0, Yes = 1
    )) %>%
    set_labels_if_present(
      grep("^read_comp[A-Z]?_[1-5]$", names(df), value = TRUE),
      c("Correct" = 1, "Incorrect" = 2,
        "No response/says I dont know" = 3, "No response" = 9)
    ) %>%
    set_labels_if_present(
      grep("^practice[A-Z]?_question[12]$", names(df), value = TRUE),
      c("Correct" = 1, "Other answers" = 2, "No answer after 5 seconds" = 3,
        "Inconsistent" = 7, "No response" = 9)
    )

  var_labels <- c(
    country_iso3       = "Country (ISO3 code)",
    year               = "Survey year",
    cluster            = "Cluster number",
    hhno               = "Household number",
    linech             = "Line number",
    reading_status     = "Reading assessment outcome",
    practice_correct   = "Practice 1: Child read every word correctly",
    practice_question1 = "Practice 1: Comprehension question 1",
    practice_question2 = "Practice 1: Comprehension question 2",
    practice_outcome   = "Practice 1: Passed",
    read_comp_1        = "Story 1: Comprehension question 1",
    read_comp_2        = "Story 1: Comprehension question 2",
    read_comp_3        = "Story 1: Comprehension question 3",
    read_comp_4        = "Story 1: Comprehension question 4",
    read_comp_5        = "Story 1: Comprehension question 5",
    read_comp_score    = "Story 1: Reading comprehension score",
    words_att          = "Story 1: Number of words attempted",
    words_incorrect    = "Story 1: Number of words incorrect or missed",
    reading_score      = "Story 1: Number of words correctly read",
    reading_accuracy   = "Story 1: Proportion of total words correct",
    reading_skills     = "Story 1: Has foundational reading skills",
    passage_language   = "Story 1: Language",
    passage_length     = "Story 1: Total number of words",
    practiceB_correct   = "Practice 2: Child read every word correctly",
    practiceB_question1 = "Practice 2: Comprehension question 1",
    practiceB_question2 = "Practice 2: Comprehension question 2",
    practiceB_outcome   = "Practice 2: Passed",
    read_compB_1        = "Story 2: Comprehension question 1",
    read_compB_2        = "Story 2: Comprehension question 2",
    read_compB_3        = "Story 2: Comprehension question 3",
    read_compB_4        = "Story 2: Comprehension question 4",
    read_compB_5        = "Story 2: Comprehension question 5",
    read_compB_score    = "Story 2: Reading comprehension score",
    wordsB_att          = "Story 2: Number of words attempted",
    wordsB_incorrect    = "Story 2: Number of words incorrect or missed",
    readingB_score      = "Story 2: Number of words correctly read",
    readingB_accuracy   = "Story 2: Proportion of total words correct",
    readingB_skills     = "Story 2: Has foundational reading skills",
    passageB_language   = "Story 2: Language",
    passageB_length     = "Story 2: Total number of words"
  )
  var_labels <- var_labels[names(var_labels) %in% names(df)]
  set_variable_labels(df, .labels = as.list(var_labels))
}

# ---------------------------------------------------------------------------
# Driver: loop over survey folders and append
# ---------------------------------------------------------------------------

harmonize_mics_reading <- function(root = "data/MICS_Datasets",
                                   outdir = "data",
                                   outfile = "mics6_reading_harmonized") {

  if (!dir.exists(root)) {
    stop("Input folder not found: ", root,
         "\nRun R/prepare-mics-fs.R first (see the download chapter).")
  }

  folders <- list.dirs(root, recursive = FALSE, full.names = FALSE)
  parts <- list()

  for (folder in folders) {
    m <- regmatches(folder, regexec("^([A-Za-z]{3})_([0-9]{4})_", folder))[[1]]
    if (length(m) == 0) {
      message("skip ", folder, ": cannot read ISO3 code and year from folder name")
      next
    }
    iso  <- toupper(m[2])
    year <- m[3]

    if (!iso %in% supported) {
      message("skip ", folder, ": ", iso, " is not covered by the passage rules")
      next
    }

    path <- file.path(root, folder, "fs.sav")
    if (!file.exists(path)) {
      message("skip ", folder, ": fs.sav not found")
      next
    }

    message("== ", folder, "  (", iso, " ", year, ")")
    part <- harmonize_survey(path, iso, year)
    message("    kept ", nrow(part), " children")
    parts[[folder]] <- part
  }

  if (length(parts) == 0) {
    stop("No surveys were prepared. Check the root path: ", root)
  }

  harmonized <- bind_rows(parts) %>% apply_labels()

  if (!dir.exists(outdir)) dir.create(outdir, recursive = TRUE)
  write_dta(harmonized, file.path(outdir, paste0(outfile, ".dta")))

  message("")
  message("Saved ", file.path(outdir, paste0(outfile, ".dta")))
  message("Surveys appended: ", length(parts))
  message("Children: ", nrow(harmonized))

  invisible(harmonized)
}

mics6_reading <- harmonize_mics_reading(root, outdir, outfile)
