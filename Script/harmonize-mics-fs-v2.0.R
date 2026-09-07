# harmonize-mics-fs-v2.0.R
#
# Spec-driven MICS6 FS harmonisation. Reads
#   Data/AFLEARN Harmonised Data/mics6-crosswalk.xlsx
# and the raw UNICEF fs.sav / hl.sav files. Writes
#   Data/AFLEARN Harmonised Data/mics6-fs-harmonised-v{version}.dta
#
# No variable names or recode tables live in this script. If a mapping is not
# in the workbook, it is not applied.
#
# Run from the project root (or via Script/run-it.R):
#     source("Script/harmonize-mics-fs-v2.0.R")

if (!require(pacman)) install.packages("pacman")
pacman::p_load(tidyverse, haven, labelled, openxlsx)

root   <- "Data/UNICEF"
outdir <- "Data/AFLEARN Harmonised Data"

source("Script/mics6-spec-io.R")

is_token <- function(cell) {
  identical(cell, "(derived)") || identical(cell, "(folder)") ||
    identical(cell, "(repair)") || identical(cell, "(none)")
}

parse_sources <- function(cell) {
  if (is.null(cell) || length(cell) == 0 || is.na(cell)) return(character())
  cell <- trimws(as.character(cell))
  if (!nzchar(cell) || is_token(cell)) return(character())
  trimws(unlist(strsplit(cell, ">", fixed = TRUE)))
}

coalesce_sources <- function(d, srcs) {
  n <- nrow(d)
  out <- rep(NA_real_, n)
  have_any <- FALSE
  for (s in srcs) {
    if (!s %in% names(d)) next
    have_any <- TRUE
    v <- d[[s]]
    if (is.character(v) || is.factor(v)) {
      # Keep as character until later repairs (FL4 letters). Promote later.
      if (!is.character(out)) {
        if (all(is.na(out))) {
          out <- rep(NA_character_, n)
        } else {
          v <- to_num(v)
        }
      }
    }
    miss <- is.na(out)
    if (any(miss)) {
      out[miss] <- v[miss]
    }
  }
  if (!have_any) return(rep(NA_real_, n))
  out
}

fl4_ticked <- function(x, letter) {
  raw <- as.character(unclass(x))
  s <- toupper(trimws(raw))
  s[s %in% c("", "?", "NA")] <- NA_character_
  as.numeric(!is.na(s) & s == letter)
}

apply_repairs <- function(d, repairs, iso, year, when) {
  if (is.null(repairs) || nrow(repairs) == 0) return(d)
  rr <- repairs[repairs$when == when, , drop = FALSE]
  if (nrow(rr) == 0) return(d)
  rr <- rr[order(rr$step), , drop = FALSE]
  for (i in seq_len(nrow(rr))) {
    r <- rr[i, ]
    survey_ok <- is.na(r$country_iso3) ||
      (identical(as.character(r$country_iso3), iso) &&
         (is.na(r$year) || identical(as.integer(r$year), as.integer(year))))
    if (!isTRUE(survey_ok)) next
    if (identical(r$action, "note_only")) next
    if (identical(r$action, "fl4_letter")) {
      tgt <- r$target
      if (tgt %in% names(d) && !is.na(r$letter) && nzchar(r$letter)) {
        d[[tgt]] <- fl4_ticked(d[[tgt]], r$letter)
      }
    } else if (identical(r$action, "swap_if_lt")) {
      a <- r$target
      b <- r$source
      if (a %in% names(d) && b %in% names(d)) {
        va <- to_num(d[[a]])
        vb <- to_num(d[[b]])
        swap <- present(va) & present(vb) & va < vb
        d[[a]] <- if_else(swap, vb, va)
        d[[b]] <- if_else(swap, va, vb)
      }
    }
  }
  d
}

map_level <- function(x, mapping) {
  out <- rep(NA_real_, length(x))
  ok <- present(x)
  if (!any(ok)) return(out)
  keys <- as.character(as.integer(to_num(x[ok])))
  mapped <- unname(mapping[keys])
  out[ok] <- mapped
  out
}

apply_level_map <- function(d, lm, iso, year) {
  if (is.null(lm) || nrow(lm) == 0) return(list(data = d, unmapped = NULL))
  sub <- lm[lm$country_iso3 == iso & as.integer(lm$year) == as.integer(year), ,
            drop = FALSE]
  if (nrow(sub) == 0) return(list(data = d, unmapped = NULL))

  unmapped <- list()
  keys <- unique(paste(sub$harmonized_raw, sub$target_var, sep = "\t"))
  for (k in keys) {
    parts <- strsplit(k, "\t", fixed = TRUE)[[1]]
    raw_name <- parts[[1]]
    tgt <- parts[[2]]
    if (!nzchar(tgt) || is.na(tgt)) tgt <- paste0(raw_name, "_h")
    if (!raw_name %in% names(d)) {
      if (!tgt %in% names(d)) d[[tgt]] <- NA_real_
      next
    }
    block <- sub[sub$harmonized_raw == raw_name & sub$target_var == tgt, ]
    mapping <- setNames(as.numeric(block$level_h), as.character(as.integer(block$raw_code)))
    mapped <- map_level(d[[raw_name]], mapping)

    raw_num <- to_num(d[[raw_name]])
    seen <- unique(as.integer(raw_num[present(raw_num)]))
    known <- as.integer(block$raw_code)
    extra <- setdiff(seen, known)
    if (length(extra) > 0) {
      unmapped[[length(unmapped) + 1]] <- tibble(
        country_iso3 = iso,
        year = as.integer(year),
        variable = raw_name,
        target_var = tgt,
        raw_code = extra
      )
    }
    d[[tgt]] <- mapped
  }
  um <- if (length(unmapped) == 0) NULL else bind_rows(unmapped)
  list(data = d, unmapped = um)
}

apply_value_labels <- function(df, spec) {
  vl <- spec$value_labels
  cw <- spec$crosswalk
  dicts <- unique(vl$dictionary)
  for (dn in dicts) {
    block <- vl[vl$dictionary == dn, ]
    labs <- setNames(as.numeric(block$code), as.character(block$label))
    vars <- cw$harmonized_name[cw$dictionary == dn & cw$label_action == "impose"]
    df <- set_labels_if_present(df, vars, labs)
  }
  remove_vars <- cw$harmonized_name[cw$label_action == "remove"]
  df <- zap_value_labels_if_present(df, remove_vars)

  labs <- cw$variable_label
  names(labs) <- cw$harmonized_name
  labs <- labs[names(labs) %in% names(df)]
  labs <- labs[!is.na(labs) & nzchar(labs)]
  if (length(labs) > 0) {
    labelled::var_label(df) <- as.list(labs)
  }
  df
}

merge_hl <- function(d_fs, d_hl, spec, col) {
  cw <- spec$crosswalk
  hl_rows <- cw[cw$source_file == "hl", , drop = FALSE]
  if (nrow(hl_rows) == 0) return(d_fs)
  srcs <- unique(unlist(lapply(hl_rows[[col]], parse_sources)))
  srcs <- srcs[nzchar(srcs)]
  if (!all(c("HH1", "HH2") %in% names(d_hl))) {
    stop("hl.sav is missing HH1/HH2")
  }
  ln_hl <- if ("HL3" %in% names(d_hl)) "HL3" else if ("LN" %in% names(d_hl)) "LN" else {
    stop("hl.sav is missing HL3/LN")
  }
  keep <- unique(c("HH1", "HH2", ln_hl, intersect(srcs, names(d_hl))))
  hl <- d_hl[keep]
  names(hl)[names(hl) == ln_hl] <- "LN"
  if (anyDuplicated(hl[c("HH1", "HH2", "LN")]) > 0) {
    hl <- dplyr::distinct(hl, HH1, HH2, LN, .keep_all = TRUE)
  }
  drop_from_fs <- setdiff(intersect(srcs, names(d_fs)), c("HH1", "HH2", "LN"))
  if (length(drop_from_fs) > 0) {
    d_fs <- d_fs[setdiff(names(d_fs), drop_from_fs)]
  }
  dplyr::left_join(d_fs, hl, by = c("HH1", "HH2", "LN"))
}

harmonize_survey <- function(path, iso, year, spec) {
  col <- survey_col(iso, year)
  cw <- spec$crosswalk
  if (!col %in% names(cw)) {
    stop("Spec crosswalk has no column ", col)
  }

  d <- haven::read_sav(path)
  id_vars <- c("HH1", "HH2", "LN")
  if (!all(id_vars %in% names(d))) {
    stop("Missing identifier columns in ", path)
  }
  if (anyDuplicated(d[id_vars]) > 0) {
    stop("HH1 HH2 LN do not uniquely identify children in ", path)
  }

  hl_path <- file.path(dirname(path), "hl.sav")
  if (!file.exists(hl_path)) stop("hl.sav not found next to ", path)
  d_hl <- haven::read_sav(hl_path)
  d <- merge_hl(d, d_hl, spec, col)

  d <- apply_repairs(d, spec$repairs, iso, year, "before_rename")

  out <- tibble::tibble(.dummy = rep(1, nrow(d)))
  for (i in seq_len(nrow(cw))) {
    hname <- cw$harmonized_name[i]
    cell <- cw[[col]][i]
    cell <- if (is.null(cell) || length(cell) == 0) NA_character_ else as.character(cell)
    if (identical(cell, "(folder)")) {
      if (identical(hname, "country_iso3")) {
        out[[hname]] <- iso
      } else if (identical(hname, "year")) {
        out[[hname]] <- as.numeric(year)
      } else if (identical(hname, "sample")) {
        sv <- spec$surveys
        hit <- sv$country_iso3 == iso & as.integer(sv$year) == as.integer(year)
        val <- sv$ipums_sample[hit]
        out[[hname]] <- if (length(val) >= 1) as.numeric(val[[1]]) else NA_real_
      } else {
        out[[hname]] <- NA_character_
      }
      next
    }
    srcs <- parse_sources(cell)
    if (length(srcs) == 0) {
      out[[hname]] <- NA_real_
      next
    }
    out[[hname]] <- coalesce_sources(d, srcs)
  }
  out$.dummy <- NULL

  out <- apply_repairs(out, spec$repairs, iso, year, "after_rename")

  mapped <- apply_level_map(out, spec$level_map, iso, year)
  out <- mapped$data

  # Numeric stack hygiene (FL26 and similar mixed types)
  skip_chr <- "country_iso3"
  for (nm in setdiff(names(out), skip_chr)) {
    if (is.character(out[[nm]])) {
      # leave FL4 until after letter recode; if still character, try numeric
      nums <- suppressWarnings(to_num(out[[nm]]))
      if (all(is.na(out[[nm]]) | !is.na(nums) | out[[nm]] %in% c("", "NA"))) {
        out[[nm]] <- nums
      }
    } else {
      out[[nm]] <- to_num(out[[nm]])
    }
  }

  list(data = out, unmapped = mapped$unmapped)
}

find_survey_path <- function(root, iso, year) {
  folders <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  pat <- paste0("^", iso, "_", year, "_MICS")
  hit <- folders[grepl(pat, basename(folders), ignore.case = TRUE)]
  if (length(hit) == 0) return(NA_character_)
  file.path(hit[[1]], "fs.sav")
}

harmonize_mics_fs <- function(root = "Data/UNICEF",
                              outdir = "Data/AFLEARN Harmonised Data") {
  spec <- load_mics6_spec(spec_path(outdir))
  inc <- included_surveys(spec)
  if (nrow(inc) == 0) stop("No surveys with include=TRUE in the spec.")

  parts <- list()
  um_all <- list()
  for (i in seq_len(nrow(inc))) {
    iso <- inc$country_iso3[i]
    year <- inc$year[i]
    path <- find_survey_path(root, iso, year)
    message("Harmonising ", iso, " ", year, " ...")
    if (is.na(path) || !file.exists(path)) {
      stop("fs.sav not found for ", iso, " ", year, " under ", root)
    }
    got <- harmonize_survey(path, iso, year, spec)
    parts[[length(parts) + 1]] <- got$data
    if (!is.null(got$unmapped)) um_all[[length(um_all) + 1]] <- got$unmapped
  }

  if (length(um_all) > 0) {
    um <- bind_rows(um_all)
    msg <- paste0(
      "Unmapped raw codes (spec is incomplete):\n",
      paste(capture.output(print(um, n = 50)), collapse = "\n")
    )
    stop(msg, call. = FALSE)
  }

  df <- bind_rows(parts)
  df <- apply_value_labels(df, spec)

  # Column order follows the spec
  ord <- intersect(spec$crosswalk$harmonized_name, names(df))
  df <- df[ord]

  dta <- harmonised_dta_path(outdir, spec$version)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  haven::write_dta(df, dta)
  message("Wrote ", dta, " (", nrow(df), " rows, ", ncol(df), " cols)")
  invisible(df)
}

mics6_fs <- harmonize_mics_fs(root, outdir)
