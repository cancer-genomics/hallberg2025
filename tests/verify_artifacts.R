## Verify all workflow and package artifacts against baseline
##
## Compares CSV/TSV/PNG hashes, RDS/RDA value digests, and
## supplemental_tables.xlsx sheet content against the baseline saved by
## save_artifact_baseline.R.
##
## Usage: Rscript tests/verify_artifacts.R
##
## Exit 0: all artifacts match.
## Exit 1: one or more files are missing or changed.

library(here)
library(tools)

baseline_file <- here("tests/snapshots/artifact_baseline.rds")
if (!file.exists(baseline_file))
    stop("Artifact baseline not found: ", baseline_file,
         "\nRun tests/save_artifact_baseline.R to create it.")

b <- readRDS(baseline_file)

EXCLUDE  <- "output/facets|output/facets-trellis|output/pgdx"
changed  <- character(0)
missing  <- character(0)
added    <- character(0)

check_hash <- function(nm, current) {
    if (!identical(current, b$file_hashes[[nm]])) {
        changed <<- c(changed, nm)
        cat(sprintf("CHANGED  %s\n  baseline=%s  current=%s\n",
                    nm, b$file_hashes[[nm]], current))
    }
}

check_digest <- function(nm, current, store) {
    if (!identical(current, store[[nm]])) {
        changed <<- c(changed, nm)
        cat(sprintf("CHANGED  %s\n  baseline=%s  current=%s\n",
                    nm, store[[nm]], current))
    }
}

## ── CSV / TSV / PNG ──────────────────────────────────────────────────────────

cur_files <- list.files(
    c(here("docs/figure"), here("docs/table"), here("output")),
    pattern = "\\.(csv|tsv|png)$",
    recursive = TRUE, full.names = TRUE
)
cur_files <- cur_files[!grepl(EXCLUDE, cur_files)]
cur_rel   <- sub(paste0("^", here(), "/"), "", cur_files)

for (nm in names(b$file_hashes)) {
    p <- here(nm)
    if (!file.exists(p)) { missing <- c(missing, nm); next }
    check_hash(nm, unname(md5sum(p)))
}
new_files <- setdiff(cur_rel, names(b$file_hashes))
if (length(new_files)) {
    added <- c(added, new_files)
    cat(sprintf("ADDED  %d CSV/TSV/PNG file(s) not in baseline\n",
                length(new_files)))
}

## ── RDS ──────────────────────────────────────────────────────────────────────

cur_rds <- list.files(here("output"), pattern = "\\.rds$",
                      recursive = TRUE, full.names = TRUE)
cur_rds <- cur_rds[!grepl(EXCLUDE, cur_rds)]
cur_rds_rel <- sub(paste0("^", here(), "/"), "", cur_rds)

for (nm in names(b$rds_digests)) {
    p <- here(nm)
    if (!file.exists(p)) { missing <- c(missing, nm); next }
    obj <- tryCatch(readRDS(p), error = function(e) NULL)
    if (is.null(obj)) { missing <- c(missing, nm); next }
    check_digest(nm, digest::digest(obj, algo = "md5"), b$rds_digests)
}
new_rds <- setdiff(cur_rds_rel, names(b$rds_digests))
if (length(new_rds)) added <- c(added, new_rds)

## ── RDA (package data) ───────────────────────────────────────────────────────

for (nm in names(b$rda_digests)) {
    p <- here(nm)
    if (!file.exists(p)) { missing <- c(missing, nm); next }
    e <- new.env(parent = emptyenv())
    load(p, envir = e)
    check_digest(nm, digest::digest(as.list(e), algo = "md5"), b$rda_digests)
}

## ── supplemental_tables.xlsx ─────────────────────────────────────────────────

xlsx_path <- here("manuscript/supplemental_tables.xlsx")
if (!file.exists(xlsx_path)) {
    missing <- c(missing, "manuscript/supplemental_tables.xlsx")
} else {
    sheets    <- readxl::excel_sheets(xlsx_path)
    xlsx_data <- lapply(sheets, function(s)
        suppressMessages(readxl::read_excel(xlsx_path, sheet = s, col_types = "text")))
    names(xlsx_data) <- sheets
    d <- digest::digest(xlsx_data, algo = "md5")
    if (!identical(d, b$xlsx_digest)) {
        changed <- c(changed, "manuscript/supplemental_tables.xlsx")
        cat(sprintf("CHANGED  manuscript/supplemental_tables.xlsx\n"))
    }
}

## ── Summary ──────────────────────────────────────────────────────────────────

if (length(missing)) {
    cat(sprintf("MISSING  (%d):\n", length(missing)))
    cat(paste(" -", missing), sep = "\n"); cat("\n")
}

ok <- length(changed) == 0 && length(missing) == 0

n_total <- length(b$file_hashes) + length(b$rds_digests) +
           length(b$rda_digests) + 1L   # +1 for xlsx

if (ok) {
    cat(sprintf("OK: all %d artifacts match baseline", n_total))
    if (length(added)) cat(sprintf("  (%d new file(s) ignored)", length(added)))
    cat("\n")
    quit(status = 0)
} else {
    cat(sprintf("FAIL: %d changed, %d missing\n",
                length(changed), length(missing)))
    quit(status = 1)
}
