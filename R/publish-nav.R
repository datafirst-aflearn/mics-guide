# Install the navigation landing page as docs/index.html
# Called by after_render (input/output are provided by bookdown) or manually.

book_root <- function() {
  if (exists("input", inherits = TRUE) && !is.null(input) && nzchar(input)) {
    return(dirname(normalizePath(input, winslash = "/", mustWork = TRUE)))
  }
  if (file.exists("_bookdown.yml")) {
    return(normalizePath(".", winslash = "/", mustWork = TRUE))
  }
  stop(
    "Could not find the book project root. ",
    "Run this from the project folder or via bookdown::render_book()."
  )
}

root <- book_root()
nav_rmd <- file.path(root, "nav-guide.Rmd")
nav_html <- file.path(root, "nav-guide.html")
docs_dir <- file.path(root, "docs")
index_html <- file.path(docs_dir, "index.html")

if (!file.exists(nav_rmd)) {
  stop("nav-guide.Rmd not found at: ", nav_rmd)
}

if (!dir.exists(docs_dir)) {
  dir.create(docs_dir, recursive = TRUE)
}

old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(root)

nav_format <- rmarkdown::html_document(
  theme = NULL,
  highlight = NULL,
  self_contained = FALSE,
  css = NULL,
  mathjax = NULL
)

message("Rendering navigation page...")
rmarkdown::render(
  input = nav_rmd,
  output_format = nav_format,
  output_dir = root,
  output_file = "nav-guide.html",
  knit_root_dir = root,
  quiet = TRUE
)

if (!file.exists(nav_html)) {
  stop("nav-guide.html was not created. Check nav-guide.Rmd for errors.")
}

ok <- file.copy(nav_html, index_html, overwrite = TRUE)
if (!ok) {
  stop("Failed to copy nav-guide.html to docs/index.html")
}

file.copy(nav_html, file.path(docs_dir, "nav-guide.html"), overwrite = TRUE)

files_src <- file.path(root, "files")
files_dst <- file.path(docs_dir, "files")
if (dir.exists(files_src)) {
  dir.create(files_dst, recursive = TRUE, showWarnings = FALSE)
  file.copy(files_src, dirname(files_dst), recursive = TRUE, overwrite = TRUE)
}

message("Landing page installed: ", index_html)
