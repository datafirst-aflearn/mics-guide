*==============================================================================
* harmonize-mics-reading.do
*
* Build one cross-country dataset of MICS6 foundational reading outcomes from
* the per-survey fs.sav files produced by R/prepare-mics-fs.R.
*
* Run from the mics-guide project root:
*     do "do/harmonize-mics-reading.do"
*
* Input :  data/MICS_Datasets/<ISO>_<YEAR>_MICS6_v01_M/fs.sav
* Output:  data/mics6_reading_harmonized.dta
*
* Requires Stata 16 or later (import spss).
*==============================================================================

clear all
set more off
version 16

*------------------------------------------------------------------------------
* Settings
*------------------------------------------------------------------------------
local root    "data/MICS_Datasets"
local outpath "data"
local outfile "mics6_reading_harmonized"

* Surveys whose reading passage language and length are defined below. Any
* other survey folder is skipped instead of failing part-way through.
local supported "BEN CAF COD COM GHA GMB GNB LSO MDG MWI NGA SLE STP SWZ TCD TGO TUN ZWE"

* Variables the pipeline needs. Questionnaires differ, so any that a survey
* does not carry are created as missing rather than stopping the run.
local required ///
    age consent child_consent enrolled ever_attended likestory              ///
    lang_home lang_school interview_result words_att words_incorrect        ///
    practice_correct practice_question1 practice_question2                  ///
    read_comp_1 read_comp_2 read_comp_3 read_comp_4 read_comp_5

capture program drop ensure
program define ensure
    * Create each listed variable as system missing if it is not in the data.
    foreach v of local 0 {
        capture confirm variable `v'
        if _rc {
            quietly generate `v' = .
            display as text "    note: `v' not in this survey - created as missing"
        }
    }
end

*------------------------------------------------------------------------------
* Loop over survey folders
*------------------------------------------------------------------------------
local countries : dir "`root'" dirs "*"
local n = 0

foreach c of local countries {

    *--- Identify the survey from the folder name -----------------------------
    if !regexm("`c'", "^([A-Za-z]{3})_([0-9]{4})_") {
        display as text "skip `c': cannot read ISO3 code and year from folder name"
        continue
    }
    local iso  = upper(regexs(1))
    local year = regexs(2)

    if strpos(" `supported' ", " `iso' ") == 0 {
        display as text "skip `c': `iso' is not covered by the passage rules"
        continue
    }

    capture confirm file "`root'/`c'/fs.sav"
    if _rc {
        display as text "skip `c': fs.sav not found"
        continue
    }

    display as result _newline "== `c'  (`iso' `year')"
    import spss using "`root'/`c'/fs.sav", clear

    *--- Fix questionnaire numbering before harmonising -----------------------
    * These must succeed: a silent failure would misalign comprehension items.
    if "`iso'" == "ZWE" {
        rename FL22E  FL22D
        rename FL22F  FL22E
    }
    if "`iso'" == "COM" {
        rename FL21BE FL21BD
        rename FL21BF FL21BE
        rename FL21B? FL22?
    }

    *--- Harmonise variable names --------------------------------------------
    * capture: a survey that never asked a question simply keeps its own names.
    * Suffix B and C denote the second and third reading passages.
    capture rename CB3    age
    capture rename FL3    child_consent
    capture rename FS3    child_line_num
    capture rename FL1    consent
    capture rename CB8B   edgrade_curr
    capture rename CB8A   edlevel_curr
    capture rename CB7    enrolled
    capture rename CB4    ever_attended
    capture rename FS2    household_num
    capture rename FS7D   interview_day
    capture rename FS7M   interview_month
    capture rename FS17   interview_result
    capture rename FS7Y   interview_year
    capture rename FL7    lang_home
    capture rename FL9    lang_school
    capture rename FL9A   lang_school
    capture rename FL9B   lang_school_fl9b
    capture rename FL10   likestory
    capture rename FL14   practice_correct
    capture rename FL15   practice_question1
    capture rename FL17   practice_question2
    capture rename FL114  practiceB_correct
    capture rename FL115  practiceB_question1
    capture rename FL117  practiceB_question2
    capture rename FL214  practiceC_correct
    capture rename FL21H  practiceB_correct
    capture rename FL215  practiceC_question1
    capture rename FL21I  practiceB_question1
    capture rename FL217  practiceC_question2
    capture rename FL21K  practiceB_question2
    capture rename FL22A  read_comp_1
    capture rename FL22B  read_comp_2
    capture rename FL22C  read_comp_3
    capture rename FL22D  read_comp_4
    capture rename FL22E  read_comp_5
    capture rename FL122A read_compB_1
    capture rename FL122B read_compB_2
    capture rename FL122C read_compB_3
    capture rename FL122D read_compB_4
    capture rename FL122E read_compB_5
    capture rename FL222A read_compC_1
    capture rename FL222B read_compC_2
    capture rename FL222C read_compC_3
    capture rename FL222D read_compC_4
    capture rename FL222E read_compC_5
    capture rename FLB22A read_compB_1
    capture rename FLB22B read_compB_2
    capture rename FLB22C read_compB_3
    capture rename FLB22D read_compB_4
    capture rename FLB22E read_compB_5
    capture rename FL21BA read_compB_1
    capture rename FL21BB read_compB_2
    capture rename FL21BC read_compB_3
    capture rename FL21BD read_compB_4
    capture rename FL21BE read_compB_5
    capture rename FL20A  words_att
    capture rename FL20B  words_incorrect
    capture rename FL21PA wordsB_att
    capture rename FL120A wordsB_att
    capture rename FLB20A wordsB_att
    capture rename FL21PB wordsB_incorrect
    capture rename FL120B wordsB_incorrect
    capture rename FLB20B wordsB_incorrect
    capture rename FL220A wordsC_att
    capture rename FL220B wordsC_incorrect
    capture rename FL29   result

    ensure `required'

    *--- Sierra Leone: attempted and incorrect are swapped for some records ---
    * The guard is words_incorrect < . (non-missing). Writing <= . would always
    * be true and would copy words_att into words_incorrect for children whose
    * incorrect count is missing.
    if "`iso'" == "SLE" {
        generate tmp  = words_att       if words_att < words_incorrect & words_incorrect < .
        generate tmp2 = words_incorrect if words_att < words_incorrect & words_incorrect < .
        replace words_att       = tmp2 if tmp2 < .
        replace words_incorrect = tmp  if tmp  < .
        drop tmp tmp2
    }

    *--- Reading score: words attempted less words incorrect or missed -------
    generate reading_score = words_att - words_incorrect

    capture confirm variable wordsB_att
    if _rc == 0 generate readingB_score = wordsB_att - wordsB_incorrect

    capture confirm variable wordsC_att
    if _rc == 0 generate readingC_score = wordsC_att - wordsC_incorrect

    *--- Surveys where refusers and practice failures still have word counts --
    if "`iso'" == "STP" | "`iso'" == "CAF" {
        replace reading_score = . if likestory != 1 | (practice_correct != 1 & practice_correct < .)
        replace words_att       = . if reading_score == .
        replace words_incorrect = . if reading_score == .
    }
    if "`iso'" == "MDG" {
        replace reading_score = . if likestory != 1 | (practice_correct != 1 & practice_correct < .)
        replace words_att       = . if reading_score == .
        replace words_incorrect = . if reading_score == .

        ensure FL110 FL210
        replace readingB_score = . if FL110 != 1 | (practiceB_correct != 1 & practiceB_correct < .)
        replace wordsB_att       = . if readingB_score == .
        replace wordsB_incorrect = . if readingB_score == .

        replace readingC_score = . if FL210 != 1 | (practiceC_correct != 1 & practiceC_correct < .)
        replace wordsC_att       = . if readingC_score == .
        replace wordsC_incorrect = . if readingC_score == .
    }

    *--- Comprehension scores: number of the five items answered correctly ---
    generate read_comp_score = 0 if read_comp_1 < .
    foreach var of varlist read_comp_? {
        replace read_comp_score = read_comp_score + 1 if `var' == 1
    }

    capture confirm variable read_compB_1
    if _rc == 0 {
        generate read_compB_score = 0 if read_compB_1 < .
        foreach var of varlist read_compB_? {
            replace read_compB_score = read_compB_score + 1 if `var' == 1
        }
    }

    capture confirm variable read_compC_1
    if _rc == 0 {
        generate read_compC_score = 0 if read_compC_1 < .
        foreach var of varlist read_compC_? {
            replace read_compC_score = read_compC_score + 1 if `var' == 1
        }
    }

    *--- Practice outcomes ---------------------------------------------------
    generate practice_outcome = practice_correct == 1 &     ///
                                practice_question1 == 1 &   ///
                                practice_question2 == 1 if practice_correct < .

    generate fail_practice = 1 - practice_outcome

    capture confirm variable practiceB_correct
    if _rc == 0 {
        generate practiceB_outcome = practiceB_correct == 1 &    ///
                                     practiceB_question1 == 1 &  ///
                                     practiceB_question2 == 1 if practiceB_correct < .
        replace fail_practice = 1 if practiceB_outcome == 0
    }

    capture confirm variable practiceC_correct
    if _rc == 0 {
        generate practiceC_outcome = practiceC_correct == 1 &    ///
                                     practiceC_question1 == 1 &  ///
                                     practiceC_question2 == 1 if practiceC_correct < .
        replace fail_practice = 1 if practiceC_outcome == 0
    }

    *--- Passage language and length -----------------------------------------
    * Accuracy needs a denominator, so every survey needs passage_length.
    if "`iso'" == "NGA" {
        ensure lang1 lang2 FL10C
        recode lang1 (11 = 1010 "English") (12 = 3190 "Hausa") ///
                     (13 = 4101 "Igbo") (14 = 4102 "Yoruba"), gen(passage_language)
        recode lang2 (11 = 1010 "English") (12 = 3190 "Hausa") ///
                     (13 = 4101 "Igbo") (14 = 4102 "Yoruba"), gen(passageB_language)

        generate passage_length = 72 if passage_language == 1010 & words_att < .
        replace  passage_length = 76 if passage_language == 3190 & words_att < .
        replace  passage_length = 88 if passage_language == 4101 & words_att < .
        replace  passage_length = 81 if passage_language == 4102 & words_att < .

        generate passageB_length = 61 if passageB_language == 1010 & wordsB_att < .
        replace  passageB_length = 63 if (passageB_language == 3190 | passageB_language == 4102) & wordsB_att < .
        replace  passageB_length = 59 if passageB_language == 4101 & wordsB_att < .
    }
    if "`iso'" == "SWZ" {
        ensure langS1 langS2 FL10C FL21D
        recode langS1 (11 = 1010 "English") (12 = 3220 "Siswati"), gen(passage_language)
        recode langS2 (11 = 1010 "English") (12 = 3220 "Siswati"), gen(passageB_language)

        generate passage_length  = 74 if passage_language  == 1010 & words_att  < .
        replace  passage_length  = 41 if passage_language  == 3220 & words_att  < .
        generate passageB_length = 74 if passageB_language == 1010 & wordsB_att < .
        replace  passageB_length = 41 if passageB_language == 3220 & wordsB_att < .
    }
    if "`iso'" == "LSO" {
        ensure FL100 FL110 FL210
        recode FL100 (1 = 3080 "Sesotho") (2 = 1010 "English") (3 = .), gen(passage_language)

        generate passage_length = 64 if passage_language == 3080 & words_att < .
        replace  passage_length = 71 if passage_language == 1010 & words_att < .

        generate passageB_language = 1010 if wordsB_att < .
        generate passageC_language = 3080 if wordsC_att < .
        generate passageB_length   = 64   if wordsB_att < .
        generate passageC_length   = 71   if wordsC_att < .
    }
    if "`iso'" == "MDG" {
        ensure FL100
        recode FL100 (1 = 6020 "Malagasy") (2 = 1020 "French") (3 = .), gen(passage_language)

        generate passage_length = 84 if passage_language == 6020 & words_att < .
        replace  passage_length = 64 if passage_language == 1020 & words_att < .

        generate passageB_language = 6020 if wordsB_att < .
        generate passageB_length   = 84   if wordsB_att < .
        generate passageC_language = 1020 if wordsC_att < .
        generate passageC_length   = 64   if wordsC_att < .
    }
    if "`iso'" == "MWI" {
        generate passage_language  = 1010 if words_att  < .
        generate passageB_language = 3160 if wordsB_att < .
        generate passage_length    = 61   if words_att  < .
        generate passageB_length   = 74   if wordsB_att < .
    }
    if "`iso'" == "ZWE" {
        ensure FL10C FL21D
        recode lang_school (1 = 1010 "English") (2 = 3140 "Shona") ///
                           (3 = 3150 "Ndebele") (7/9 = .), gen(passage_language)

        replace passage_language = .    if words_att >= .
        replace passage_language = 1010 if lang_home == 1 & passage_language >= . & words_att < .
        replace passage_language = 3140 if lang_home == 2 & passage_language >= . & words_att < .
        replace passage_language = 3150 if lang_home == 3 & passage_language >= . & words_att < .
        replace passage_language = 1010 if FL10C == 1 & words_att < .
        replace passage_language = 3140 if FL10C == 2 & words_att < .
        replace passage_language = 3150 if FL10C == 3 & words_att < .

        recode FL21D (1 = 1010 "English") (2 = 3140 "Shona") ///
                     (3 = 3150 "Ndebele") (5 = .), gen(passageB_language)

        generate passage_length  = 72 if words_att  < .
        generate passageB_length = 62 if wordsB_att < .
    }

    * Single-language surveys: one passage length, one language.
    if inlist("`iso'", "TUN", "SLE", "GNB", "GMB") generate passage_length = 72 if words_att < .
    if inlist("`iso'", "BEN", "TCD", "COM", "TGO") generate passage_length = 81 if words_att < .
    if "`iso'" == "GHA" generate passage_length = 69 if words_att < .
    if "`iso'" == "CAF" generate passage_length = 87 if words_att < .
    if "`iso'" == "COD" generate passage_length = 85 if words_att < .
    if "`iso'" == "STP" generate passage_length = 76 if words_att < .

    * English
    if inlist("`iso'", "GHA", "SLE", "GMB") generate passage_language = 1010 if reading_score < .
    * French
    if inlist("`iso'", "BEN", "CAF", "TCD", "COM", "COD", "TGO") generate passage_language = 1020 if reading_score < .
    * Portuguese
    if inlist("`iso'", "STP", "GNB") generate passage_language = 1040 if reading_score < .

    * Tunisia has a passage length but no language code in this scheme.
    ensure passage_language passage_length

    *--- Accuracy and foundational reading skills ----------------------------
    generate reading_accuracy = reading_score / passage_length
    generate cutoff = int(0.9 * passage_length)
    generate reading_skills = read_comp_score == 5 &                    ///
                              (reading_score >= cutoff & reading_score < .) if reading_score < .

    capture confirm variable readingB_score
    if _rc == 0 {
        generate readingB_accuracy = readingB_score / passageB_length
        generate cutoffB = int(0.9 * passageB_length)
        generate readingB_skills = read_compB_score == 5 &                  ///
                                   (readingB_score >= cutoffB & readingB_score < .) if readingB_score < .
    }

    capture confirm variable readingC_score
    if _rc == 0 {
        generate readingC_accuracy = readingC_score / passageC_length
        generate cutoffC = int(0.9 * passageC_length)
        generate readingC_skills = read_compC_score == 5 &                  ///
                                   (readingC_score >= cutoffC & readingC_score < .) if readingC_score < .
    }

    *--- Lesotho and Madagascar: fold the third passage into the B slots -----
    if "`iso'" == "LSO" | "`iso'" == "MDG" {
        replace wordsB_att          = wordsC_att          if wordsC_att          < .
        replace wordsB_incorrect    = wordsC_incorrect    if wordsC_incorrect    < .
        replace practiceB_outcome   = practiceC_outcome   if practiceC_outcome   < .
        replace practiceB_correct   = practiceC_correct   if practiceC_correct   < .
        replace practiceB_question1 = practiceC_question1 if practiceC_question1 < .
        replace practiceB_question2 = practiceC_question2 if practiceC_question2 < .
        replace readingB_score      = readingC_score      if readingC_score      < .
        replace readingB_accuracy   = readingC_accuracy   if readingC_accuracy   < .
        replace readingB_skills     = readingC_skills     if readingC_skills     < .
        replace passageB_length     = passageC_length     if passageC_length     < .
        replace passageB_language   = passageC_language   if passageC_language   < .
        replace read_compB_score    = read_compC_score    if read_compC_score    < .
        forvalues i = 1/5 {
            replace read_compB_`i' = read_compC_`i' if read_compC_`i' < .
        }
        replace cutoffB = cutoffC if cutoffC < .
        drop read_compC* passageC_* readingC_* wordsC_* cutoffC practiceC*
    }

    *--- Outcome of the reading assessment -----------------------------------
    generate lang_mismatch = child_consent == 1 &                                       ///
        ((ever_attended == 1 & likestory == . & lang_school < .) |                       ///
         ((enrolled == 2 | ever_attended == 2) & likestory == . & lang_home < .))

    generate child_refuses_read = likestory != 1 & likestory < .

    if "`iso'" == "SWZ" replace child_refuses_read = 1 if FL10C == 95 | (FL21D >= 95 & FL21D < .)
    if "`iso'" == "LSO" replace child_refuses_read = 1 if (FL110 != 1 & FL110 < .) | (FL210 != 1 & FL210 < .)
    if "`iso'" == "NGA" replace child_refuses_read = 1 if FL10C == 95
    if "`iso'" == "ZWE" replace child_refuses_read = 1 if FL10C == 5 | FL21D == 5
    if "`iso'" == "COM" replace child_refuses_read = 1 if FL10C >= 95 & FL10C <= 99
    if "`iso'" == "MDG" replace child_refuses_read = 1 if (FL110 != 1 & FL110 < .) | (FL210 != 1 & FL210 < .)

    * Best result across the passages a child attempted.
    egen max_reading_score    = rowmax(reading*_score)
    egen max_reading_accuracy = rowmax(reading*_accuracy)
    egen max_reading_skills   = rowmax(reading*_skills)

    * Ordered classification. Codes 2 to 4 only fill gaps; 5 to 8 overwrite.
    generate reading_status = 0 if interview_result > 1 & interview_result < .
    replace  reading_status = 1 if age < 7 | (age > 14 & age < .)
    replace  reading_status = 2 if consent != 1 & consent < . & reading_status >= .
    replace  reading_status = 3 if child_consent != 1 & child_consent < . & reading_status >= .
    replace  reading_status = 4 if lang_mismatch == 1 & reading_status >= .
    replace  reading_status = 5 if child_refuses_read == 1
    replace  reading_status = 6 if fail_practice == 1
    replace  reading_status = 7 if max_reading_score < .
    replace  reading_status = 8 if max_reading_skills == 1

    *--- Keys for merging with IPUMS-MICS ------------------------------------
    isid HH1 HH2 LN
    clonevar cluster = HH1
    clonevar hhno    = HH2
    clonevar linech  = LN

    generate country_iso3 = "`iso'"
    generate year = `year'

    *--- Keep the analysis variables that this survey actually has -----------
    local wanted                                                            ///
        country_iso3 year cluster hhno linech HH1 HH2 LN                    ///
        age consent child_consent enrolled ever_attended                    ///
        lang_home lang_school lang_mismatch child_refuses_read              ///
        fail_practice words* cutoff* max_reading_*                          ///
        reading* read_comp* practice* passage*

    local tokeep ""
    foreach v of local wanted {
        capture unab match : `v'
        if _rc == 0 local tokeep "`tokeep' `match'"
    }
    keep `tokeep'
    order country_iso3 year cluster hhno linech HH1 HH2 LN reading_status

    local ++n
    tempfile part`n'
    save "`part`n''", replace
    display as text "    kept `=_N' children"
}

*------------------------------------------------------------------------------
* Append the surveys
*------------------------------------------------------------------------------
if `n' == 0 {
    display as error "No surveys were prepared. Check the root path: `root'"
    exit 601
}

use "`part1'", clear
forvalues i = 2/`n' {
    append using "`part`i''"
}

*------------------------------------------------------------------------------
* Value labels
*------------------------------------------------------------------------------
label define reading_status                             ///
    0 "Not interviewed"                                 ///
    1 "Age <7 or >14"                                   ///
    2 "Caregiver refused"                               ///
    3 "Child refused"                                   ///
    4 "Language does not match"                         ///
    5 "Child does not want to read story"               ///
    6 "Failed practice sentence and questions"          ///
    7 "Attempted passage"                               ///
    8 "90% of words and all comp. questions correct"
label values reading_status reading_status

label define passage_lang                               ///
    1010 "English"  1020 "French"   1040 "Portuguese"   ///
    3080 "Sesotho"  3140 "Shona"    3150 "Ndebele"      ///
    3160 "Chichewa" 3190 "Hausa"    3220 "Siswati"      ///
    4101 "Igbo"     4102 "Yoruba"   6020 "Malagasy"
label values passage_language passage_lang
capture label values passageB_language passage_lang

label define yesno 1 "Yes" 2 "No" 9 "No response"
label values practice_correct yesno
capture label values practiceB_correct yesno

label define pass 0 "Failed" 1 "Passed"
label values practice_outcome pass
capture label values practiceB_outcome pass

label define skills 0 "No" 1 "Yes"
label values reading_skills skills
capture label values readingB_skills skills

label define compq 1 "Correct" 2 "Incorrect" ///
    3 "No response/says I dont know" 9 "No response"
foreach var of varlist read_comp*_? {
    label values `var' compq
}

label define pracq 1 "Correct" 2 "Other answers" ///
    3 "No answer after 5 seconds" 7 "Inconsistent" 9 "No response"
foreach var of varlist prac*question* {
    label values `var' pracq
}

*------------------------------------------------------------------------------
* Variable labels
*------------------------------------------------------------------------------
label variable country_iso3   "Country (ISO3 code)"
label variable year           "Survey year"
label variable cluster        "Cluster number"
label variable hhno           "Household number"
label variable linech         "Line number"
label variable reading_status "Reading assessment outcome"

label variable practice_correct   "Practice 1: Child read every word correctly"
label variable practice_question1 "Practice 1: Comprehension question 1"
label variable practice_question2 "Practice 1: Comprehension question 2"
label variable practice_outcome   "Practice 1: Passed"

label variable read_comp_1     "Story 1: Comprehension question 1"
label variable read_comp_2     "Story 1: Comprehension question 2"
label variable read_comp_3     "Story 1: Comprehension question 3"
label variable read_comp_4     "Story 1: Comprehension question 4"
label variable read_comp_5     "Story 1: Comprehension question 5"
label variable read_comp_score "Story 1: Reading comprehension score"

label variable words_att        "Story 1: Number of words attempted"
label variable words_incorrect  "Story 1: Number of words incorrect or missed"
label variable reading_score    "Story 1: Number of words correctly read"
label variable reading_accuracy "Story 1: Proportion of total words correct"
label variable reading_skills   "Story 1: Has foundational reading skills"
label variable passage_language "Story 1: Language"
label variable passage_length   "Story 1: Total number of words"

capture label variable practiceB_correct   "Practice 2: Child read every word correctly"
capture label variable practiceB_question1 "Practice 2: Comprehension question 1"
capture label variable practiceB_question2 "Practice 2: Comprehension question 2"
capture label variable practiceB_outcome   "Practice 2: Passed"

capture label variable read_compB_1     "Story 2: Comprehension question 1"
capture label variable read_compB_2     "Story 2: Comprehension question 2"
capture label variable read_compB_3     "Story 2: Comprehension question 3"
capture label variable read_compB_4     "Story 2: Comprehension question 4"
capture label variable read_compB_5     "Story 2: Comprehension question 5"
capture label variable read_compB_score "Story 2: Reading comprehension score"

capture label variable wordsB_att        "Story 2: Number of words attempted"
capture label variable wordsB_incorrect  "Story 2: Number of words incorrect or missed"
capture label variable readingB_score    "Story 2: Number of words correctly read"
capture label variable readingB_accuracy "Story 2: Proportion of total words correct"
capture label variable readingB_skills   "Story 2: Has foundational reading skills"
capture label variable passageB_language "Story 2: Language"
capture label variable passageB_length   "Story 2: Total number of words"

*------------------------------------------------------------------------------
* Save
*------------------------------------------------------------------------------
compress
save "`outpath'/`outfile'.dta", replace

display as result _newline "Saved `outpath'/`outfile'.dta"
display as text "Surveys appended: `n'"
tabulate country_iso3 year
tabulate reading_status, missing
