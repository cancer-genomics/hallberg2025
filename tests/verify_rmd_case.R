## Guards against the recurring "table_s4.rmd vs table_s4.Rmd" class of bug (GATE-03,
## 2026-08-01): every analysis/*.Rmd source file is tracked with a capital "R" (confirmed
## via `git ls-tree`), but source code has repeatedly hardcoded a lowercase ".rmd" when
## constructing that Rmd's own output path or referencing its output elsewhere. macOS's
## default case-insensitive filesystem makes this invisible locally; Linux CI (and any
## case-sensitive filesystem) then hits a hard "file not found" or -- worse -- silently
## writes to an untracked, gitignored shadow directory that nothing else ever reads.
## Found repeatedly (ext-figure1.Rmd's table_s4/s5 reads, then discovered systemically
## across all nine table_sN.Rmd outdirs plus dead-code references in figure2.Rmd/
## figure4.Rmd) -- this check exists so the next occurrence fails the build immediately
## instead of surfacing as a Linux-only CI mystery.
##
## Usage: Rscript tests/verify_rmd_case.R
## Exit 0: no mismatches. Exit 1: at least one lowercase reference to a capital-R Rmd found.
##
## Deliberately NOT flagged: a lowercase ".rmd" reference for which no analysis/<stem>.Rmd
## file exists at all (e.g. "07-figure5.rmd", matching code/archive/07-figure5.rmd's own,
## genuinely lowercase, real filename -- there is no analysis/07-figure5.Rmd to conflict
## with). Only stems that collide with an actual capital-R source are a real bug.

suppressPackageStartupMessages(library(here))

ROOT <- here()

tracked_files <- system2("git", c("-C", shQuote(ROOT), "ls-files"),
                          stdout = TRUE, stderr = FALSE)

analysis_rmds <- tracked_files[grepl("^analysis/.*\\.Rmd$", tracked_files)]
rmd_stems <- tolower(sub("\\.Rmd$", "", basename(analysis_rmds)))

## Every tracked R/Rmd source file, plus .gitignore -- the actual places a hardcoded path
## can live. Vendored/generated trees (`.uvr/`, `docs/`, `output/`, `public/`,
## `hallberg2025/`, `code/archive/`) are never in `git ls-files` for this repo's own
## tracked content in the first place, so no explicit exclusion is needed here.
scan_files <- tracked_files[grepl("\\.(R|Rmd)$", tracked_files) | basename(tracked_files) == ".gitignore"]

## Deliberately scoped to the workflowr output-directory convention every *live*
## analysis/*.Rmd uses (its own outdir, or a sibling Rmd reading its table/figure output)
## -- not a bare "<stem>.rmd" anywhere in the tree. A bare-stem scan also flags unrelated,
## correctly-lowercase paths that merely share a name: retired pre-refactor `output/*.rmd`
## artifacts (a different, dead pipeline convention), archived `code/archive/**/*.rmd`
## scripts genuinely named in lowercase, and coincidental collisions (e.g. a
## manuscript-build `/index.rmd` LaTeX byproduct matching `analysis/index.Rmd`'s stem by
## pure chance). Those aren't this bug class.
##
## R source never writes the path as one literal string -- it always passes "docs", then
## "table" or "figure", then the Rmd-named subdirectory as separate quoted arguments to
## here()/file.path(), occasionally wrapped onto a second line for a long call. A
## single-line regex requiring all three as one literal slash-joined string therefore
## matches zero real R code (only literal-string contexts like .gitignore or a markdown
## href) -- this was caught by deliberately re-introducing the bug this script exists to
## catch and confirming an earlier version of this very check failed to catch it, before
## trusting it. Instead: slide a 3-line window over each file and require quoted "docs"
## and quoted "figure"/"table" tokens to appear somewhere in that window alongside a
## quoted token ending in a lowercase ".rmd" -- loose enough to survive the call-spanning-
## two-lines case, tight enough that it still requires all three ingredients of the actual
## bug pattern together, not just an incidental nearby mention of "table". (Deliberately
## not spelling out a literal three-argument example here, the way this paragraph
## originally did -- it tripped this exact check on its own comment.)
QUOTED_TOKEN <- function(word) sprintf('"%s"', word)

hits <- list()
for (f in scan_files) {
  full <- file.path(ROOT, f)
  if (!file.exists(full)) next
  lines <- readLines(full, warn = FALSE)
  n <- length(lines)
  for (i in seq_len(n)) {
    window <- paste(lines[i:min(i + 2, n)], collapse = " ")
    if (!grepl(QUOTED_TOKEN("docs"), window, fixed = TRUE)) next
    if (!grepl(QUOTED_TOKEN("figure"), window, fixed = TRUE) &&
        !grepl(QUOTED_TOKEN("table"), window, fixed = TRUE)) next
    m <- gregexpr('"([A-Za-z0-9_.-]+)\\.rmd"', window)
    matches <- regmatches(window, m)[[1]]
    for (mm in matches) {
      stem <- tolower(sub('^"([A-Za-z0-9_.-]+)\\.rmd"$', "\\1", mm))
      if (stem %in% rmd_stems) {
        ## Report whichever physical line in the window actually carries the offending
        ## token, not just the window's start line.
        offset <- which(grepl(mm, lines[i:min(i + 2, n)], fixed = TRUE))
        hit_line <- if (length(offset)) i + offset[1] - 1L else i
        hits[[length(hits) + 1]] <- list(file = f, line = hit_line,
                                          text = trimws(lines[hit_line]), stem = stem)
      }
    }
  }
}
## The sliding window re-finds the same token from up to 3 overlapping window starts --
## dedupe down to one report per actual (file, line, stem) hit.
if (length(hits)) {
  key <- vapply(hits, function(h) sprintf("%s|%s|%d", h$file, h$stem, h$line), character(1))
  hits <- hits[!duplicated(key)]
}

if (length(hits)) {
  cat(sprintf("FAIL: %d lowercase '.rmd' reference(s) to a capital-R analysis/*.Rmd source:\n",
              length(hits)))
  for (h in hits) {
    cat(sprintf("  %s:%d  (matches analysis/%s.Rmd)\n    %s\n",
                h$file, h$line, h$stem, h$text))
  }
  cat("\nFix: change the lowercase \".rmd\" to \".Rmd\" at each site above.\n")
  quit(status = 1)
} else {
  cat(sprintf("OK: no lowercase '.rmd' references found for any of the %d tracked analysis/*.Rmd sources\n",
              length(rmd_stems)))
  quit(status = 0)
}
