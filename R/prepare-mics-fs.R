# Prepare MICS SPSS datasets for this guide.
#
# Simplest use — put this script and MICS_Datasets.zip in the same folder,
# set that folder as the working directory, then:
#
#   source("prepare-mics-fs.R")
#
# That works anywhere on the computer (Downloads, Desktop, a USB drive, etc.).
# Organised files are written to:
#
#   <that folder>/data/MICS_Datasets/{SURVEY}/
#
# If you run from inside the mics-guide project, the same layout is used under
# the project root. The script also searches for the zip in:
#   1. zip= argument (prepare_mics_data(zip = "..."))
#   2. the current working directory
#   3. the project data/ folder and project root (when a guide project is found)
#   4. your user Downloads folder
#
# Nested *_Datasets/ folders and inner zips are removed. The original bulk
# zip is kept by default (set remove_zip = TRUE to delete it after success).
#
# Base R only — no extra packages.

ZIP_NAME_REGEX <- "(?i)^MICS_Datasets?\\.zip$"

find_script_path <- function() {
  ofile <- NULL
  n <- sys.nframe()
  if (n >= 1L) {
    for (i in seq_len(n)) {
      if (!is.null(sys.frame(i)$ofile)) {
        ofile <- sys.frame(i)$ofile
      }
    }
  }
  if (is.null(ofile) || !nzchar(ofile)) {
    return(NA_character_)
  }
  normalizePath(ofile, winslash = "/", mustWork = FALSE)
}

walk_for_project_root <- function(start_dir) {
  if (is.na(start_dir) || !nzchar(start_dir) || !dir.exists(start_dir)) {
    return(NA_character_)
  }
  cur <- normalizePath(start_dir, winslash = "/", mustWork = TRUE)
  for (i in seq_len(30)) {
    if (file.exists(file.path(cur, "_bookdown.yml")) ||
          file.exists(file.path(cur, "index.Rmd"))) {
      return(cur)
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) {
      break
    }
    cur <- parent
  }
  NA_character_
}

find_project_root <- function(prefer_wd = TRUE) {
  # Prefer an actual mics-guide project if we can find one, but never require it.
  starts <- c(getwd(), dirname(find_script_path()))
  for (s in starts) {
    root <- walk_for_project_root(s)
    if (!is.na(root)) {
      return(root)
    }
  }
  # Standalone mode: use the working directory (expected to contain the zip
  # and/or this script).
  if (isTRUE(prefer_wd)) {
    message(
      "No mics-guide project found nearby; ",
      "using working directory as output root:\n  ", getwd()
    )
    return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
  }
  stop("Could not determine an output root directory.")
}

find_zip_in_dir <- function(dir) {
  if (is.na(dir) || !nzchar(dir) || !dir.exists(dir)) {
    return(NA_character_)
  }
  hits <- list.files(dir, full.names = TRUE, all.files = FALSE)
  hits <- hits[grepl(ZIP_NAME_REGEX, basename(hits), perl = TRUE)]
  hits <- hits[file.info(hits)$isdir %in% FALSE]
  if (length(hits) == 0L) {
    return(NA_character_)
  }
  normalizePath(hits[[1]], winslash = "/", mustWork = TRUE)
}

user_downloads_dir <- function() {
  candidates <- c(
    file.path(path.expand("~"), "Downloads"),
    file.path(Sys.getenv("USERPROFILE"), "Downloads"),
    file.path(Sys.getenv("HOME"), "Downloads")
  )
  candidates <- unique(candidates[nzchar(candidates) & dir.exists(candidates)])
  if (length(candidates) == 0L) {
    return(NA_character_)
  }
  candidates[[1]]
}

resolve_bulk_zip <- function(root, data_dir, zip = NULL) {
  if (!is.null(zip) && !is.na(zip) && nzchar(zip)) {
    if (!file.exists(zip)) {
      stop("zip not found: ", zip)
    }
    found <- normalizePath(zip, winslash = "/", mustWork = TRUE)
    message("Using zip: ", found)
    return(found)
  }

  search_dirs <- unique(c(
    getwd(),
    data_dir,
    root,
    user_downloads_dir()
  ))
  search_dirs <- search_dirs[!is.na(search_dirs) & nzchar(search_dirs)]

  for (d in search_dirs) {
    hit <- find_zip_in_dir(d)
    if (!is.na(hit)) {
      message("Found bulk zip in ", d, ":\n  ", hit)
      return(hit)
    }
  }

  NA_character_
}

is_keep_entry <- function(entry_name) {
  base <- basename(entry_name)
  if (!nzchar(base) || grepl("/$", entry_name)) {
    return(FALSE)
  }
  grepl("\\.sav$", base, ignore.case = TRUE) ||
    grepl("(?i)read\\s*\\.?\\s*me", base, perl = TRUE)
}

find_keep_entries <- function(zip_path) {
  info <- utils::unzip(zip_path, list = TRUE)
  info$Name[vapply(info$Name, is_keep_entry, logical(1))]
}

find_nested_zips <- function(survey_dir) {
  list.files(
    survey_dir,
    pattern = "\\.zip$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )
}

list_survey_dirs <- function(mics_root) {
  dirs <- list.dirs(mics_root, recursive = FALSE, full.names = TRUE)
  dirs[grepl("^[A-Za-z]{3}_[0-9]{4}_MICS", basename(dirs))]
}

clear_dir_contents <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    return(invisible(NULL))
  }
  items <- list.files(path, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  if (length(items) > 0L) {
    unlink(items, recursive = TRUE, force = TRUE)
  }
  invisible(NULL)
}

extract_survey_files <- function(zip_path, dest_dir) {
  entries <- find_keep_entries(zip_path)
  if (length(entries) == 0L) {
    return(character())
  }

  tmpdir <- tempfile("mics_survey_")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE, force = TRUE), add = TRUE)

  utils::unzip(zip_path, files = entries, exdir = tmpdir, junkpaths = TRUE)

  extracted <- list.files(tmpdir, full.names = TRUE, recursive = TRUE)
  extracted <- extracted[file.info(extracted)$isdir %in% FALSE]
  keep <- extracted[vapply(basename(extracted), function(b) {
    grepl("\\.sav$", b, ignore.case = TRUE) ||
      grepl("(?i)read\\s*\\.?\\s*me", b, perl = TRUE)
  }, logical(1))]

  if (length(keep) == 0L) {
    return(character())
  }

  clear_dir_contents(dest_dir)
  ok <- file.copy(keep, file.path(dest_dir, basename(keep)), overwrite = TRUE)
  if (!all(ok)) {
    warning("Some files failed to copy into ", dest_dir)
  }
  basename(keep)[ok]
}

resolve_mics_root <- function(root, data_dir, zip = NULL) {
  bulk_zip <- resolve_bulk_zip(root, data_dir, zip = zip)
  mics_root <- file.path(data_dir, "MICS_Datasets")

  if (!is.na(bulk_zip)) {
    message("Unzipping ", bulk_zip, " ...")
    if (dir.exists(mics_root)) {
      unlink(mics_root, recursive = TRUE, force = TRUE)
    }
    utils::unzip(bulk_zip, exdir = data_dir)

    # Bulk zip may unpack as data/MICS_Datasets/... or as survey folders
    # directly under data/.
    if (!dir.exists(mics_root)) {
      survey_like <- list_survey_dirs(data_dir)
      if (length(survey_like) > 0L) {
        dir.create(mics_root, recursive = TRUE)
        for (d in survey_like) {
          file.rename(d, file.path(mics_root, basename(d)))
        }
      }
    }
  }

  if (dir.exists(mics_root) && length(list_survey_dirs(mics_root)) > 0L) {
    return(list(mics_root = mics_root, bulk_zip = bulk_zip))
  }

  stop(
    "Could not find MICS_Datasets.zip (or MICS_Dataset.zip).\n",
    "Put the bulk download in your working directory, Downloads, or the\n",
    "guide data/ folder, then re-run — or pass the path explicitly:\n",
    "  prepare_mics_data(zip = \"C:/path/to/MICS_Datasets.zip\")"
  )
}

remove_nested_wrappers <- function(survey_dir) {
  children <- list.files(survey_dir, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  for (child in children) {
    base <- basename(child)
    is_sav <- grepl("\\.sav$", base, ignore.case = TRUE)
    is_readme <- grepl("(?i)read\\s*\\.?\\s*me", base, perl = TRUE)
    if (!(is_sav || is_readme)) {
      unlink(child, recursive = TRUE, force = TRUE)
    }
  }
  invisible(NULL)
}

clean_old_flat_fs <- function(data_dir) {
  old <- list.files(
    data_dir,
    pattern = "^[A-Za-z]{3}_[0-9]{4}_fs\\.sav$",
    full.names = TRUE
  )
  if (length(old) > 0L) {
    message("Removing ", length(old), " old flat *_fs.sav file(s) from data/ ...")
    unlink(old, force = TRUE)
  }
  invisible(NULL)
}

#' Prepare MICS survey SPSS files under data/MICS_Datasets/
#'
#' @param zip Optional path to MICS_Datasets.zip. If NULL, the zip is
#'   searched for in getwd(), the project data/ folder, project root, and
#'   the user Downloads folder.
#' @param root Output root (guide project or any folder). Detected
#'   automatically: mics-guide project if present, otherwise getwd().
#' @param remove_zip If TRUE, delete the bulk zip after a successful run.
#'   Default FALSE so a zip in Downloads is left alone.
prepare_mics_data <- function(zip = NULL,
                              root = find_project_root(),
                              remove_zip = FALSE) {
  data_dir <- file.path(root, "data")
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE)
  }

  resolved <- resolve_mics_root(root, data_dir, zip = zip)
  mics_root <- resolved$mics_root
  bulk_zip <- resolved$bulk_zip

  survey_dirs <- list_survey_dirs(mics_root)
  if (length(survey_dirs) == 0L) {
    stop("No survey folders matching ISO_YEAR_MICS* were found under ", mics_root)
  }

  results <- list()
  skipped <- character()

  message(
    "Found ", length(survey_dirs),
    " survey folder(s). Extracting .sav files and readmes ..."
  )

  for (survey_dir in survey_dirs) {
    survey_name <- basename(survey_dir)
    zips <- find_nested_zips(survey_dir)

    if (length(zips) == 0L) {
      existing <- list.files(survey_dir, pattern = "\\.sav$", ignore.case = TRUE)
      if (length(existing) > 0L) {
        message(
          "  ", survey_name, ": already has ", length(existing),
          " .sav file(s); leaving as-is"
        )
        results[[survey_name]] <- existing
      } else {
        skipped <- c(skipped, paste0(survey_name, " (no nested zip)"))
        message("  skipped ", survey_name, " — no nested zip")
      }
      next
    }

    written <- character()
    for (zip_path in zips) {
      got <- extract_survey_files(zip_path, survey_dir)
      if (length(got) > 0L) {
        written <- got
        break
      }
    }

    if (length(written) == 0L) {
      skipped <- c(skipped, paste0(survey_name, " (no .sav/readme in nested zip)"))
      message("  skipped ", survey_name, " — no .sav/readme found")
      next
    }

    remove_nested_wrappers(survey_dir)
    results[[survey_name]] <- written
    message(
      "  ", survey_name, ": ",
      sum(grepl("\\.sav$", written, ignore.case = TRUE)), " .sav, ",
      sum(grepl("(?i)read\\s*\\.?\\s*me", written, perl = TRUE)), " readme"
    )
  }

  if (isTRUE(remove_zip) && !is.na(bulk_zip) && file.exists(bulk_zip)) {
    unlink(bulk_zip, force = TRUE)
    message("Removed ", bulk_zip)
  }

  clean_old_flat_fs(data_dir)

  message("")
  message("Done.")
  message("  Surveys found:     ", length(survey_dirs))
  message("  Surveys prepared:  ", length(results))
  if (length(skipped) > 0L) {
    message("  Skipped:")
    for (s in skipped) {
      message("    - ", s)
    }
  }
  message("  Output folder:     ", mics_root)

  invisible(list(results = results, skipped = skipped, mics_root = mics_root))
}

prepare_mics_data()
