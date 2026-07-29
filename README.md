# MICS Analysis Guide

AFLEARN guide for analysing [MICS](https://mics.unicef.org/) (Multiple Indicator Cluster Surveys) data in R and Stata.

Built with [bookdown](https://bookdown.org/yihui/bookdown/). Hosted from the `docs/` folder on GitHub Pages (`main` / `/docs`).

## Render the site

From the project root in R:

```r
source("render-site.R")
```

This builds the book chapters into `docs/` and installs the navigation landing page as `docs/index.html`.

Then open `docs/index.html` in a browser, or commit and push `docs/` to update the live site.

## Adding chapters

1. Add a new `NN-topic.Rmd` with a stable H1 anchor, e.g. `# My Topic {#c05-my-topic}`.
2. Append the filename to `rmd_files` in `_bookdown.yml`.
3. When you want a landing-page card, add a card and search entry in `nav-guide.Rmd`.
4. Re-run `source("render-site.R")`.

*This repo was initially generated from a bookdown template available here: https://github.com/jtr13/bookdown-template.*
