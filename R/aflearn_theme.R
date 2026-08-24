# AFLEARN ggplot2 theme and palettes
# Source: ~/.cursor/skills/aflearn-data-viz/scripts/aflearn_theme.R
# PaperPlane Multimedia data colour style guide (2026-08-15)
#
# Usage:
#   source("C:/Users/cash/.cursor/skills/aflearn-data-viz/scripts/aflearn_theme.R")
#   ggplot(...) + theme_aflearn() + scale_colour_manual(values = aflearn_pal_categorical(3))

# --- Fonts (Montserrat + Barlow) --------------------------------------------
# Guide weights: Montserrat Bold 700 / ExtraBold 800; Barlow Regular 400 / SemiBold 600.
# Register ExtraBold and SemiBold as their own family names so ggplot does not
# have to fake weights via face=.

.aflearn_dpi <- 150
.aflearn_fonts_ready <- FALSE
.aflearn_font_title <- ""       # Montserrat Bold (via face = "bold")
.aflearn_font_extrabold <- ""   # Montserrat ExtraBold 800
.aflearn_font_body <- ""        # Barlow Regular
.aflearn_font_semibold <- ""    # Barlow SemiBold 600

if (requireNamespace("showtext", quietly = TRUE) &&
      requireNamespace("sysfonts", quietly = TRUE)) {
  tryCatch(
    {
      sysfonts::font_add_google("Montserrat", "Montserrat",
                                regular.wt = 400, bold.wt = 700)
      sysfonts::font_add_google("Montserrat", "Montserrat ExtraBold",
                                regular.wt = 800, bold.wt = 800)
      sysfonts::font_add_google("Barlow", "Barlow",
                                regular.wt = 400, bold.wt = 700)
      sysfonts::font_add_google("Barlow", "Barlow SemiBold",
                                regular.wt = 600, bold.wt = 600)
      showtext::showtext_auto()
      # Must match ggsave(..., dpi = ...) so guide px → rendered px
      showtext::showtext_opts(dpi = .aflearn_dpi)
      .aflearn_fonts_ready <<- TRUE
      .aflearn_font_title <<- "Montserrat"
      .aflearn_font_extrabold <<- "Montserrat ExtraBold"
      .aflearn_font_body <<- "Barlow"
      .aflearn_font_semibold <<- "Barlow SemiBold"
    },
    error = function(e) {
      message("AFLEARN theme: could not load Google fonts — using device default. ",
              conditionMessage(e))
    }
  )
} else {
  message("AFLEARN theme: install showtext + sysfonts for Montserrat/Barlow.")
}

# --- Literal point sizes -----------------------------------------------
# aflearn_size values below are literal, ruler-measurable point sizes —
# what you'd dial into an InDesign paragraph style. This matters now that
# figures are exported as PDFs at their exact placement size (rather than
# large PNGs later scaled down to fit), so a labeled "12" needs to print
# as a true 12pt, not some fraction of it.
#
# (This file used to run every size through a `px * 72 / .aflearn_dpi`
# "guide-pixel" scaling — meant for large raster PNG canvases at 150dpi —
# which silently halved every labeled size, e.g. "subtitle = 13" actually
# rendered at 6.24pt. Removed now that output is a size-accurate PDF.)
#
# aflearn_pt(): passthrough for theme() text elements, whose `size` is
# already literal points.
# aflearn_geom_size(): converts a literal point size into the mm units
# geom_text() / geom_label() / annotate("text", ...) expect (their
# `size` aesthetic means font size in millimetres — this uses ggplot2's
# standard pt<->mm ratio of 72.27pt / 25.4mm, independent of dpi).


       aflearn_pt = function(pt) pt
.aflearn_pt_ratio = 72.27 / 25.4
aflearn_geom_size = function(pt) pt / .aflearn_pt_ratio


# --- Primary ----------------------------------------------------------------

aflearn_offwhite     <- "#eef3f7"
aflearn_navy         <- "#0d0d52"
aflearn_electric_blue <- "#0049ff"
aflearn_amber        <- "#ffad44"
aflearn_cyan         <- "#0dd8f9"

aflearn_primary <- c(
  offwhite = aflearn_offwhite,
  navy     = aflearn_navy,
  blue     = aflearn_electric_blue,
  amber    = aflearn_amber,
  cyan     = aflearn_cyan
)

# --- Neutrals ---------------------------------------------------------------

aflearn_neutral <- c(
  surface  = "#f7fafc",
  rule     = "#dbe4ec",
  context  = "#b9c5d1",
  caption  = "#6f7d99"
)

# --- Secondary scales (darkest -> palest) -----------------------------------

aflearn_navy_scale <- c("#08083a", "#22225f", "#33377a", "#4b52a3")
aflearn_blue_scale <- c("#003bcc", "#2b5aa8", "#4d7fe0", "#b3c8ff")
aflearn_amber_scale <- c("#b36a10", "#e08a1e", "#ffc26b", "#ffdca8")
aflearn_cyan_scale <- c("#007a99", "#00b3d4", "#52e4ff", "#a3f0ff")
aflearn_emerald_scale <- c("#05684a", "#0f9b6f", "#4ddcae", "#b3f2dd")
aflearn_violet_scale <- c("#3a1a9c", "#5127c9", "#9a7cf7", "#d6c9ff")
aflearn_magenta_scale <- c("#b3145f", "#e02a7c", "#ff8cc0", "#ffd0e5")
aflearn_coral_scale <- c("#b32a12", "#e0421f", "#ff8f79", "#ffd2c7")
aflearn_cream_scale <- c("#f2dcae", "#e3c68a", "#cbab6d", "#a88a4f")

# Named list for sequential helpers
aflearn_scales <- list(
  navy    = aflearn_navy_scale,
  blue    = aflearn_blue_scale,
  amber   = aflearn_amber_scale,
  cyan    = aflearn_cyan_scale,
  emerald = aflearn_emerald_scale,
  violet  = aflearn_violet_scale,
  magenta = aflearn_magenta_scale,
  coral   = aflearn_coral_scale,
  cream   = aflearn_cream_scale
)

# Temperature heatmap (pale -> dark). Core brand blue mid-ramp.
aflearn_heatmap <- c(
  "#ffffff", "#dfe8ff", "#bfd1ff", "#9fbaff", "#80a4ff", "#608dff",
  "#4076ff", "#205fff", "#0049ff", "#003fdf", "#0036bf", "#002d9f",
  "#002480", "#001b60", "#001240", "#000920", "#000000"
)

# Extended categorical: darker steps for white grounds (sheet order after core)
.aflearn_extended_dark <- c(
  aflearn_navy,
  aflearn_blue_scale[1:2],
  aflearn_amber_scale[1:2],
  aflearn_cyan_scale[1:2],
  aflearn_emerald_scale[1:3],
  aflearn_violet_scale[1:3],
  aflearn_magenta_scale[1:3],
  aflearn_coral_scale[1:3],
  aflearn_cream_scale[4:1],
  aflearn_navy_scale[1:3]
)

# Lighter steps for navy grounds
.aflearn_extended_light <- c(
  aflearn_blue_scale[3:4],
  aflearn_amber_scale[3:4],
  aflearn_cyan_scale[3:4],
  aflearn_navy_scale[3:4],
  aflearn_emerald_scale[2:4],
  aflearn_violet_scale[2:4],
  aflearn_magenta_scale[2:4],
  aflearn_coral_scale[2:4],
  aflearn_cream_scale[1:3]
)

# --- Palette helpers --------------------------------------------------------

#' Categorical colours: blue, amber, cyan, then extended families.
#' @param n number of colours
#' @param on_navy if TRUE, prefer lighter steps for dark grounds
aflearn_pal_categorical <- function(n, on_navy = FALSE)
{
  stopifnot(n >= 1)
  core = c(aflearn_electric_blue, aflearn_amber, aflearn_cyan)
  ext  = if (on_navy) .aflearn_extended_light else .aflearn_extended_dark
  # First three are always blue / amber / cyan; then sheet-order darks (or lights)
  pool <- unique(c(core, ext))
  if (n > length(pool)) {
    warning("aflearn_pal_categorical: recycling colours; prefer fewer categories.")
    return(rep(pool, length.out = n))
  }
  pool[seq_len(n)]
}

#' Sequential shades of one family (dark -> pale by default).
#' @param family one of names(aflearn_scales)
#' @param n 1–4 typically
#' @param reverse if TRUE, pale -> dark
aflearn_pal_sequential <- function(family = "blue", n = 4, reverse = FALSE) {
  family <- match.arg(family, names(aflearn_scales))
  cols <- aflearn_scales[[family]]
  if (n > length(cols)) {
    cols <- grDevices::colorRampPalette(cols)(n)
  } else {
    cols <- cols[seq_len(n)]
  }
  if (reverse) rev(cols) else cols
}

#' Diverging: emerald (positive) vs coral (negative). Never reverse meanings.
#' Returns c(neg_dark, neg_light, mid_neutral, pos_light, pos_dark) for n=5,
#' or a length-n ramp through coral -> neutral -> emerald.
aflearn_pal_diverging <- function(n = 5) {
  stopifnot(n >= 2)
  low <- c(aflearn_coral_scale[1], aflearn_coral_scale[2])
  mid <- aflearn_neutral[["context"]]
  high <- c(aflearn_emerald_scale[2], aflearn_emerald_scale[1])
  if (n == 2) return(c(low[1], high[2]))
  if (n == 3) return(c(low[1], mid, high[2]))
  grDevices::colorRampPalette(c(low[1], low[2], mid, high[1], high[2]))(n)
}

#' Highlight one (or few) series; rest are context grey.
#' @param n_highlight number of accent colours from a categorical pool
#' @param accent optional vector of hex for highlights; default categorical
aflearn_pal_highlight <- function(n_highlight = 1, accent = NULL) {
  if (is.null(accent)) {
    accent <- aflearn_pal_categorical(n_highlight)
  }
  list(
    accent = accent,
    context = aflearn_neutral[["context"]]
  )
}

#' Heatmap / temperature scale (one family). pale = low, dark = high.
#' @param n number of colours to sample from the ramp
aflearn_pal_heatmap <- function(n = 11) {
  stopifnot(n >= 2)
  grDevices::colorRampPalette(aflearn_heatmap)(n)
}

# Named shortcuts matching recipes
aflearn_cols_up   <- aflearn_emerald_scale[2]  # #0f9b6f
aflearn_cols_down <- aflearn_coral_scale[2]    # #e0421f

# --- Type size constants (guide px → ggplot via aflearn_pt / aflearn_geom_size)

aflearn_size <- list(
  heading   = aflearn_pt(14.25),          # Montserrat Bold
  subtitle  = aflearn_pt(9.75),          # Barlow Regular, grey
  big_num   = aflearn_pt(27.75),          # Montserrat ExtraBold
  big_cap   = aflearn_pt(8.25),          # Barlow SemiBold caps
  bar_value = aflearn_geom_size(9),    # Barlow SemiBold — for geom_text
  axis      = aflearn_pt(8.625),           # Barlow Regular, grey, never bold
  category  = aflearn_pt(9.75),          # Barlow SemiBold
  legend    = aflearn_pt(9.75),          # Barlow Regular
  source    = aflearn_pt(9),           # Barlow Regular, grey
 slide_mult = 2
)

# Convenience: category / row labels on a discrete axis (SemiBold navy)
aflearn_axis_category <- function(size = aflearn_size$category, ...) {
  ggplot2::element_text(
    family = if (nzchar(.aflearn_font_semibold)) .aflearn_font_semibold else .aflearn_font_body,
    face = "plain",
    colour = aflearn_navy,
    size = size,
    ...
  )
}


# --- Theme ------------------------------------------------------------------

#' AFLEARN ggplot2 theme: off-white ground, navy titles, grey axes.
#' @param base_size base font size
#' @param dark if TRUE, navy ground with off-white text
theme_aflearn <- function(base_size = aflearn_pt(12), dark = FALSE) {
  ground <- if (dark) aflearn_navy else aflearn_offwhite
  on_col <- if (dark) aflearn_offwhite else aflearn_navy
  muted  <- if (dark) "#b3c8ff" else aflearn_neutral[["caption"]]
  title_family <- if (nzchar(.aflearn_font_title)) .aflearn_font_title else ""
  body_family  <- if (nzchar(.aflearn_font_body))  .aflearn_font_body  else ""

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("theme_aflearn() requires ggplot2. install.packages(\"ggplot2\")")
  }

  ggplot2::theme_minimal(base_size = base_size, base_family = body_family) +
    ggplot2::theme(
      plot.background  = ggplot2::element_rect(fill = ground, colour = NA),
      panel.background = ggplot2::element_rect(fill = ground, colour = NA),
      panel.grid.major = ggplot2::element_line(
        colour = if (dark) "#22225f" else "#dbe4ec",
        linewidth = 0.3
      ),
      panel.grid.minor = ggplot2::element_blank(),
      axis.title       = ggplot2::element_text(
        family = body_family, colour = muted, size = aflearn_size$axis
      ),
      # Default axis ticks = Regular grey (never bold). For category row labels
      # on a discrete axis, override with aflearn_axis_category().
      axis.text        = ggplot2::element_text(
        family = body_family, face = "plain", colour = muted,
        size = aflearn_size$axis
      ),
      axis.ticks       = ggplot2::element_blank(),
      legend.text      = ggplot2::element_text(
        family = body_family, face = "plain", colour = on_col,
        size = aflearn_size$legend
      ),
      legend.title     = ggplot2::element_text(
        family = body_family, colour = on_col, size = aflearn_size$legend
      ),
      legend.background = ggplot2::element_blank(),
      plot.title       = ggplot2::element_text(
        family = title_family, face = "bold", colour = on_col,
        size = aflearn_size$heading, hjust = 0,
        margin = ggplot2::margin(b = 4)
      ),
      plot.subtitle    = ggplot2::element_text(
        family = body_family, face = "plain", colour = muted,
        size = aflearn_size$subtitle, hjust = 0, lineheight = 1.25,
        margin = ggplot2::margin(b = 10)
      ),
      plot.caption     = ggplot2::element_text(
        family = body_family, face = "plain", colour = muted,
        size = aflearn_size$source, hjust = 0,
        margin = ggplot2::margin(t = 8)
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.margin      = ggplot2::margin(12, 12, 10, 12)
    )
}

message(
  "AFLEARN theme loaded. Fonts: ",
  if (.aflearn_fonts_ready) {
    "Montserrat Bold/ExtraBold + Barlow Regular/SemiBold"
  } else {
    "default"
  },
  ". Use theme_aflearn() and aflearn_pal_*(). Category labels: aflearn_axis_category()."
)
