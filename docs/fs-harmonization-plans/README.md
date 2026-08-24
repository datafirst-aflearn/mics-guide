# FS harmonization plans (archive)

Design notes from building the shared MICS6 FS (ages 5–17) harmonized file.

**Entry script:** `data/harmonize-mics-fs-v1.0.R`  
**Outputs:** `data/mics6_fs_harmonized.{rds,dta}`, `data/mics6_fs_variable_crosswalk.xlsx`  
**Guide chapter:** Harmonising MICS6 FS background themes (`06-harmonize-fs.Rmd`)

## Theme order

| Order | Theme | Plan file |
|------:|-------|-----------|
| 1 | CB — Child's Background (schooling) | `cb_schooling_harmonize_3bc9b39e.plan.md` |
| 2 | CL — Child Labour | `cl_core_harmonize_562cfb1e.plan.md` |
| 3 | PR — Parental Involvement | `pr_core_into_fs_dcaef807.plan.md` |
| 4 | FCF — Child Functioning | `fcf_core_into_fs_1ef770b2.plan.md` |
| 5 | FL — Foundational Learning (numeracy + setup) | `fl_numeracy_into_fs_9f813109.plan.md` |
| 6 | Inventory of leftovers | `remaining_fs_variables_9b9a421e.plan.md` |
| 7 | FCD — Child Discipline | `fcd_into_fs_09c1ed2a.plan.md` |
| 8 | BG — Parent education + school type | `parent_ed_and_school_type_01c748b6.plan.md` |

**HH** (urban / region / children 5–17) was added from the leftover inventory without a separate plan file.

Reading outcomes are **not** in this pipeline; see `data/harmonize-mics-reading-v1.1.R` and the reading harmonization chapter.
