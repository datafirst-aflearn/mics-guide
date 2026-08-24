clear all
set more off

* ------------------------------------------------------------------
* SETTINGS - adjust these paths
* ------------------------------------------------------------------
local dofiles 	  "C:\Users\01371436\OneDrive - University of Cape Town\MICS6\dofiles"
local root    "C:\Users\01371436\Downloads\Test2\data\MICS_Datasets"   // top-level folder containing all country folders
local outpath "C:\Users\01371436\Downloads\Test2"   // where to save the .dta files

local countries : dir "`root'" dirs "*"

foreach c of local countries {

    * parse ISO3 code and year from folder name, e.g. BEN_2021_MICS6_v01_M
    if regexm("`c'", "^([A-Za-z]{3})_([0-9]{4})_") {
        local iso  = upper(regexs(1))
        local year = regexs(2)
    }
    else {
        di as error "Could not parse country/year from folder: `c' - skipping"
        continue
    }

    quietly import spss using "`root'/`c'/fs.sav", clear


	** Fix variable name issues **
		if "`iso'"=="ZWE" {
			rename FL22E FL22D
			rename FL22F FL22E		
		}
		if "`iso'"=="COM"{
			rename FL21BE FL21BD
			rename FL21BF FL21BE	
		}

	** Harmonize variable names **	
	cap rename CB3 age
	cap rename FL3 child_consent
	cap rename FL1 consent
	cap rename CB7 enrolled
	cap rename CB4 ever_attended
	cap rename FS17 interview_result 
	cap rename FL7 lang_home
	cap rename FL9 lang_school
	
	if "`iso'"=="TCD"{
		cap rename FL9A lang_school
		cap replace lang_school=FL9B if FL9B<.	
	}

	cap rename FL10 likestory
	cap rename FL14 practice_correct
	cap rename FL15 practice_question1
	cap rename FL17 practice_question2
	cap rename FL20A words_att
	cap rename FL20B words_incorrect
	
	if "`iso'"!="SWZ"&"`iso'"!="NGA"&"`iso'"!="ZWE"{
		cap rename FL22A read_comp_1
		cap rename FL22B read_comp_2
		cap rename FL22C read_comp_3
		cap rename FL22D read_comp_4
		cap rename FL22E read_comp_5	
	}
	
	if "`iso'"=="SWZ"|"`iso'"=="NGA"|"`iso'"=="ZWE"|"`iso'"=="COM"{
		cap rename FL21BA read_comp_1
		cap rename FL21BB read_comp_2
		cap rename FL21BC read_comp_3
		cap rename FL21BD read_comp_4
		cap rename FL21BE read_comp_5
		cap rename FL22A read_compB_1
		cap rename FL22B read_compB_2
		cap rename FL22C read_compB_3
		cap rename FL22D read_compB_4
		cap rename FL22E read_compB_5		
	}	
	
	cap rename FL122A read_compB_1
	cap rename FL122B read_compB_2
	cap rename FL122C read_compB_3
	cap rename FL122D read_compB_4
	cap rename FL122E read_compB_5
	cap rename FLB22A read_compB_1
	cap rename FLB22B read_compB_2
	cap rename FLB22C read_compB_3
	cap rename FLB22D read_compB_4
	cap rename FLB22E read_compB_5
	cap rename FL114 practiceB_correct
	cap rename FL115 practiceB_question1
	cap rename FL117 practiceB_question2
	cap rename FL21PA wordsB_att
	cap rename FL120A wordsB_att
	cap rename FLB20A wordsB_att
	cap rename FL21PB wordsB_incorrect
	cap rename FL120B wordsB_incorrect
	cap rename FLB20B wordsB_incorrect
	cap rename FL214 practiceC_correct
	cap rename FL21H practiceB_correct
	cap rename FL215 practiceC_question1
	cap rename FL21I practiceB_question1
	cap rename FL217 practiceC_question2
	cap rename FL21K practiceB_question2
	cap rename FL222A read_compC_1
	cap rename FL222B read_compC_2
	cap rename FL222C read_compC_3
	cap rename FL222D read_compC_4
	cap rename FL222E read_compC_5
	cap rename FL220A wordsC_att
	cap rename FL220B wordsC_incorrect


	******************** Data cleaning *****************************************************
	*there are some observations in Sierra Leone where attempted and incorrect are switched around
	if "`iso'"=="SLE"{
		gen tmp=words_att if words_att<words_incorrect&words_incorrect<=.
		gen tmp2=words_incorrect if words_att<words_incorrect&words_incorrect<=.
		replace words_att=tmp2 if tmp2<.
		replace words_incorrect=tmp if tmp<.
		drop tmp tmp2
	}

	*there are some countries where children who refused to read or failed the practice have nonmissing data on words attempted
	if "`iso'"=="STP"|"`iso'"=="MDG"|"`iso'"=="CAR"{
		replace words_att = . if likestory!=1 | (practice_correct!=1 & practice_correct<.)  
		replace words_incorrect = . if likestory!=1 | (practice_correct!=1 & practice_correct<.)  
	}	
	if "`iso'"=="MDG"{
		replace wordsB_att = . if FL110!=1 | (practiceB_correct!=1 & practiceB_correct<.) 
		replace wordsB_incorrect = . if FL110!=1 | (practiceB_correct!=1 & practiceB_correct<.) 		
		replace wordsC_att = . if FL210!=1 | (practiceC_correct!=1 & practiceC_correct<.) 
		replace wordsC_incorrect = . if FL210!=1 | (practiceC_correct!=1 & practiceC_correct<.) 		
	}

	

	********************** Passage language **********************
	if "`iso'"=="NGA" {
		recode lang1 (11=1010 "English") (12=3190 "Hausa") (13=4101 "Igbo") (14=4102 "Yoruba"), gen(passage_language)
		recode lang2 (11=1010 "English") (12=3190 "Hausa") (13=4101 "Igbo") (14=4102 "Yoruba"), gen(passageB_language)	
	}
	if "`iso'"=="SWZ"{
		recode langS1 (11=1010 "English") (12=3220 "Siswati"), gen(passage_language)
		recode langS2 (11=1010 "English") (12=3220 "Siswati"), gen(passageB_language)
	}
	if "`iso'"=="LSO"{
		recode FL100 (1=3080 "Sesotho") (2=1010 "English") (3=.), gen(passage_language)
		gen passageB_language=1010 if wordsB_att<.
		gen passageC_language=3080 if wordsC_att<.
	}
	if "`iso'"=="MDG"{
		recode FL100 (1=6020 "Malagasy") (2=1020 "French") (3=.), gen(passage_language)
		gen passageB_language=6020 if wordsB_att<.
		gen passageC_language=1020 if wordsC_att<.

	}
	if "`iso'"=="MWI"{
		gen passage_language=1010 if words_att<.
		gen passageB_language=3160 if wordsB_att<.
	}

	if "`iso'"=="ZWE"{
		recode lang_school (1=1010 "English") (2=3140 "Shona") (3=3150 "Ndebele") (7/9=.), gen(passage_language)
		replace passage_language=. if words_att>=.
		replace passage_language=1010 if lang_home==1&passage_language>=.&words_att<.
		replace passage_language=3140 if lang_home==2&passage_language>=.&words_att<.	
		replace passage_language=3150 if lang_home==3&passage_language>=.&words_att<.
		replace passage_language=1010 if FL10C==1&words_att<.
		replace passage_language=3140 if FL10C==2&words_att<.	
		replace passage_language=3150 if FL10C==3&words_att<.
		recode FL21D (1=1010 "English") (2=3140 "Shona") (3=3150 "Ndebele") (5=.), gen(passageB_language)
	}

	*English
	if "`iso'"=="GHA"|"`iso'"=="SLE"|"`iso'"=="GMB"{
		gen passage_language=1010 if words_att<.
	}
	*French
	if "`iso'"=="BEN"|"`iso'"=="CAR"|"`iso'"=="TCD"|"`iso'"=="COM"|"`iso'"=="COD"|"`iso'"=="TGO"{
		gen passage_language=1020 if words_att<.
	}
	*Portuguese
	if "`iso'"=="STP"|"`iso'"=="GNB"{
		gen passage_language=1040 if words_att<.
	}
	*Arabic
	if "`iso'"=="TUN"{
		gen passage_language=2010 if words_att<.
	}	
	
	************************ Passage length ****************************************
	egen passage_length=max(words_att), by(passage_language)
	capture confirm variable wordsB_att
	if _rc==0 egen passageB_length=max(wordsB_att), by(passageB_language)
	capture confirm variable wordsC_att
	if _rc==0 egen passageC_length=max(wordsC_att), by(passageC_language)
	
	****** For MWI Chichewa is always passageB. For children who only attempted Chichewa move "B" values to main variables ************
	if "`iso'"=="MWI"{
		gen tmp=words_att>=.&wordsB_att<.
		replace words_att=wordsB_att if tmp==1
		replace words_incorrect=wordsB_incorrect if tmp==1
		replace passage_language=passageB_language if tmp==1
		replace passage_length=passageB_length if tmp==1
		forvalues i=1(1)5{
			replace read_comp_`i'=read_compB_`i' if tmp==1			
		}
		foreach var of varlist wordsB_att wordsB_incorrect read_compB_? passageB_language passageB_length{
			replace `var'=. if tmp==1
		}
		drop tmp
	}	
	

	********************* Reading score *******************
	gen reading_score=words_att-words_incorrect // Passage 1: Number of words attempted - Number of incorrect or missed words

	*Use data from second passage where there is one
	capture confirm variable wordsB_att
	if _rc==0 {
		gen readingB_score=wordsB_att-wordsB_incorrect
	}
	*Use data from third passage where there is one
	capture confirm variable wordsC_att
	if _rc==0 {
		gen readingC_score=wordsC_att-wordsC_incorrect
	}

	****************************** Comprehension outcomes ************************
	gen read_comp_score=0 if read_comp_1<.
	foreach var of varlist read_comp_?{
		replace read_comp_score=read_comp_score+1 if `var'==1
	}
	*Use data from second passage where there is one
	capture confirm variable read_compB_1
	if _rc==0 {
		gen read_compB_score=0 if read_compB_1<.
		foreach var of varlist read_compB_?{
			replace read_compB_score=read_compB_score+1 if `var'==1
		}
	}
	*Use data from third passage where there is one
	capture confirm variable read_compC_1
	if _rc==0 {
		gen read_compC_score=0 if read_compC_1<.
		foreach var of varlist read_compC_?{
			replace read_compC_score=read_compC_score+1 if `var'==1
		}
	}

	****************************** Practice outcomes *************************************
	gen practice_outcome=practice_correct==1&practice_question1==1&practice_question2==1 if practice_correct<.

	gen fail_practice=1-practice_outcome
	capture confirm variable practiceB_correct
	if _rc==0 {
		gen practiceB_outcome=practiceB_correct==1&practiceB_question1==1&practiceB_question2==1 if practiceB_correct<.
		replace fail_practice=1 if practiceB_outcome==0
	}
	capture confirm variable practiceC_correct
	if _rc==0 {
		gen practiceC_outcome=practiceC_correct==1&practiceC_question1==1&practiceC_question2==1 if practiceC_correct<.
		replace fail_practice=1 if practiceC_outcome==0
	}
	
	************************** Reading skills **************************************
	gen reading_accuracy=reading_score/passage_length
	*work out cutoffs for 90% accuracy
	gen cutoff=int(0.9*passage_length)
	gen reading_skills=read_comp_score==5&(reading_score>=cutoff&reading_score<.) if (reading_score<.)
	capture confirm variable readingB_score
	if _rc==0{
		gen readingB_accuracy=readingB_score/passageB_length
		gen cutoffB=int(0.9*passageB_length)
		gen readingB_skills=read_compB_score==5&(readingB_score>=cutoffB&readingB_score<.) if (readingB_score<.)
	}
	capture confirm variable readingC_score
	if _rc==0{
		gen readingC_accuracy=readingC_score/passageC_length
		gen cutoffC=int(0.9*passageC_length)
		gen readingC_skills=read_compC_score==5&(readingC_score>=cutoffC&readingC_score<.) if (readingC_score<.)
	}

	*********************** Combine reading B and C for LSO and MDG ******************
	if "`iso'"=="LSO"|"`iso'"=="MDG"{
		replace wordsB_att=wordsC_att if wordsC_att<.
		replace wordsB_incorrect=wordsC_incorrect if wordsC_incorrect<.
		replace practiceB_outcome=practiceC_outcome if practiceC_outcome<.
		replace practiceB_correct=practiceC_correct if practiceC_correct<.
		replace practiceB_question1=practiceC_question1 if practiceC_question1<.
		replace practiceB_question2=practiceC_question2 if practiceC_question1<.
		replace readingB_score=readingC_score if readingC_score<.
		replace readingB_accuracy=readingC_accuracy if readingC_accuracy<.
		replace readingB_skills=readingC_skills if readingC_skills<.
		replace passageB_length=passageC_length if passageC_length<.
		replace passageB_language=passageC_language if passageC_language<.
		replace read_compB_score=read_compC_score if read_compC_score<.
		forvalues i=1(1)5{
			replace read_compB_`i'=read_compC_`i' if read_compC_`i'<.
		}
		replace cutoffB=cutoffC if cutoffC<.
		drop read_compC* passageC_* readingC_* wordsC_* cutoffC practiceC*
	}

		
	************************** Create variable for outcome of reading assessment *******************************
	gen lang_mismatch=child_consent==1&((ever_attended==1&likestory==.& lang_school<.)|((enrolled==2|ever_attended==2)&likestory==.& lang_home<.))

	gen child_refuses_read=likestory!=1&likestory<.

	if "`iso'"=="SWZ" replace child_refuses_read = 1 if ((FL10C==95)| (FL21D>=95&FL21D<.)) 
	if "`iso'"=="LSO" 	replace child_refuses_read = 1 if  (FL110!=1&FL110<.) | (FL210!=1&FL210<.) 
	if "`iso'"=="NGA" 	replace child_refuses_read = 1 if (FL10C==95) 
	if "`iso'"=="ZWE" 	replace child_refuses_read = 1 if ((FL10C==5)|(FL21D==5)) 
	if "`iso'"=="COM" 	replace child_refuses_read = 1 if (FL10C>=95&FL10C<=99) 
	if "`iso'"=="MDG"	replace child_refuses_read = 1 if (FL110!=1&FL110<.) | (FL210!=1&FL210<.) 

	*assign best outcome to child if they attempted more than one passage
	egen max_reading_score=rowmax(reading*_score)
	egen max_reading_accuracy=rowmax(reading*_accuracy)
	egen max_reading_skills=rowmax(reading*_skills)

	cap drop reading_status
	gen reading_status=0 if interview_result>1&interview_result<. // Child not interviewed
	replace reading_status=1 if age<7|(age>14&age<.) // Child less than 7 or older than 14 years old
	replace reading_status=2 if consent!=1&consent<.&reading_status>=. // Caregiver consent not given
	replace reading_status=3 if child_consent!=1&child_consent<.&reading_status>=. // Child consent not given
	replace reading_status=4 if lang_mismatch==1&reading_status>=. // Teacher teaches in other language for those enrolled in school or child speaks other language for those not enrolled
	replace reading_status=5 if child_refuses_read==1 // Child refuses to read story
	replace reading_status=6 if fail_practice==1  // Child failed practice 
	replace reading_status=7 if max_reading_score<. // Child attempted reading passage
	replace reading_status=8 if max_reading_skills==1 // Child got 90% of words and all comprehension questions correct
	replace reading_status=9 if reading_status>=. // Child who remain unclassified have inconsitent data (e.g. attempted comprehension questions but words attempted etc are all missing)


	*create variables for merging with MICS-IPUMS
	isid HH1 HH2 LN
	clonevar cluster=HH1
	clonevar hhno=HH2
	clonevar linech=LN
	
	gen country_iso3="`iso'"
	gen year=`year'
	keep country_iso3 year cluster hhno linech HH1 HH2 LN reading_status reading* read_comp* practice* passage* words*_att words*_incorrect
	order country_iso3 year cluster hhno linech HH1 HH2 LN reading_status practice* reading* passage* read_comp* words*_att words*_incorrect
	tempfile `c'
	save ``c''
}

* Flag to detect first merge
local first = 1

foreach c of local countries {
	if `first'==1{
		use ``c'', clear
		save "`outpath'/mics6_reading_harmonized.dta", replace
		local first=0
	}
	else {
		use "`outpath'/mics6_reading_harmonized.dta", clear
		append using ``c'', force
		save, replace
	}
}

************* Label values ******************************
label define reading_status 0 "Not interviewed" 1 "Age <7 or >14" 2 "Caregiver refused" 3 "Child refused" 4 "Language does not match" 5 "Child does not want to read story" 6 "Failed practice sentence and questions" 7 "Attempted passage" 8 "90% of words and all comp. questions correct" 9 "Not classified - data inconsistent"
label values reading_status reading_status

label define passage_lang 1010 "English" 1020 "French" 1040 "Portuguese" 3140 "Shona" 3150 "Ndebele" 6020 "Malagasy" 3080 "Sesotho" 3220 "Siswati" 3190 "Hausa" 4101 "Igbo" 4102 "Yoruba" 3160 "Chichewa" 2010 "Arabic"
label values passage_language passage_lang
cap label values passageB_language passage_lang

label define yesno 1 "Yes" 2 "No" 9 "No response"
label values practice_correct yesno
label values practiceB_correct yesno

label define pass 1 "Passed" 0 "Failed"
label values practice_outcome pass
label values practiceB_outcome pass

label define skills 1 "Yes" 0 "No"
label values reading_skills skills
label values readingB_skills skills

label define compq 1 "Correct" 2 "Incorrect" 3 "No response/says I dont know" 9 "No response"
foreach var of varlist read_comp*_?{
	label values `var' compq
}
label define pracq 1 "Correct" 2 "Other answers" 3 "No answer after 5 seconds" 7 "Inconsistent" 9 "No response"
foreach var of varlist prac*question*{
	label values `var' pracq
}

*********** Label variables *****************************
label var practice_correct "Practice 1: Child read every word correctly"
label var practice_question1 "Practice 1: Comprehension question 1"
label var practice_question2 "Practice 1: Comprehension question 2"
label var read_compB_1 "Story 2: Comprehension question 1"
label var read_compB_2 "Story 2: Comprehension question 2"
label var read_compB_3 "Story 2: Comprehension question 3"
label var read_compB_4 "Story 2: Comprehension question 4"
label var read_compB_5 "Story 2: Comprehension question 5"
label var practiceB_correct "Practice 2: Child read every word correctly"
label var practiceB_question1 "Practice 2: Comprehension question 1"
label var practiceB_question2 "Practice 2: Comprehension question 2"
label var read_comp_1 "Story 1: Comprehension question 1"
label var read_comp_2 "Story 1: Comprehension question 2"
label var read_comp_3 "Story 1: Comprehension question 3"
label var read_comp_4 "Story 1: Comprehension question 4"
label var read_comp_5 "Story 1: Comprehension question 5"
label var reading_score "Story 1: Number of words correctly read"
label var readingB_score "Story 2: Number of words correctly read"
label var read_comp_score "Story 1: Reading comprehension score"
label var read_compB_score "Story 2: Reading comprehension score"
label var passage_language "Story 1: Language"
label var passageB_language "Story 2: Language"
label var passage_length "Story 1: Total number of words"
label var passageB_length "Story 2: Total number of words"
label var reading_accuracy "Story 1: Proportion of total words correct"
label var reading_skills "Story 1: Has foundational reading skills"
label var readingB_accuracy "Story 2: Proportion of total words correct"
label var readingB_skills "Story 2: Has foundational reading skills"
label var reading_status "Reading assessment outcome"
label var practice_outcome "Practice 1: Passed"
label var practiceB_outcome "Practice 2: Passed"
label var cluster "Cluster number"
label var hhno "Household number"
label var linech "Line number"
label var year "Yes"
label var country "Country"
label var HH1 "Cluster number"
label var HH2 "Household number"
label var LN "Line number"

save, replace