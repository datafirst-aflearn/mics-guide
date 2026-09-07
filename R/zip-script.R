# Rebuild Script.zip from Script/ so researchers can download one file.
# The archive contains the Script/ folder itself, not loose files.
#
# From the project root:
#   source("R/zip-script.R")

if (!file.exists("_bookdown.yml")) {
  stop("Run this from the mics-guide project root.")
}

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
script_dir <- file.path(root, "Script")
zip_path <- file.path(root, "Script.zip")

if (!dir.exists(script_dir)) {
  stop("No Script/ folder at: ", script_dir)
}

wanted <- list.files(script_dir, full.names = FALSE)
if (length(wanted) == 0L) {
  stop("Script/ is empty.")
}

if (file.exists(zip_path)) {
  unlink(zip_path)
}

old <- setwd(root)
on.exit(setwd(old), add = TRUE)

wrote <- FALSE
zip_try <- try(
  {
    utils::zip(zipfile = "Script.zip", files = "Script", flags = "-r9X")
    TRUE
  },
  silent = TRUE
)

if (isTRUE(zip_try) && file.exists(zip_path) && file.info(zip_path)$size > 0) {
  wrote <- TRUE
}

if (!wrote && .Platform$OS.type == "windows") {
  status <- system2(
    "powershell",
    c(
      "-NoProfile",
      "-Command",
      "Compress-Archive -Path 'Script' -DestinationPath 'Script.zip' -Force"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  if (file.exists(zip_path) && isTRUE(file.info(zip_path)$size > 0)) {
    wrote <- TRUE
  } else {
    stop("Could not write Script.zip.\n", paste(status, collapse = "\n"))
  }
}

if (!wrote) {
  stop(
    "Could not write Script.zip. Install Info-ZIP `zip` or rebuild on Windows with PowerShell."
  )
}

message("Wrote ", zip_path)
message("Contents of Script/ packed:")
for (f in wanted) message("  ", f)
