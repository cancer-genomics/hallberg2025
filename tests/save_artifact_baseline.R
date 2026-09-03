## Save artifact baseline
##
## Records content digests of all workflow and package outputs:
##   - CSV / TSV / PNG  in docs/ and output/   — MD5 file hash
##   - RDS              in output/              — MD5 value digest
##   - RDA              in hallberg2025.base/data/ — MD5 value digest
##   - supplemental_tables.xlsx                 — MD5 digest of sheet contents
##
## PDFs and HTML are excluded: PDFs embed timestamps; HTML differs by renderer.
## Restricted-data outputs (facets, pgdx) are excluded.
##
## Run once after a known-good full build, then commit the resulting
## tests/snapshots/artifact_baseline.rds.
##
## Usage: Rscript tests/save_artifact_baseline.R

library(here)
library(tools)

EXCLUDE <- "output/facets|output/facets-trellis|output/pgdx"

## ── CSV / TSV / PNG ──────────────────────────────────────────────────────────

file_artifacts <- list.files(
    c(here("docs/figure"), here("docs/table"), here("output")),
    pattern = "\\.(csv|tsv|png)$",
    recursive = TRUE, full.names = TRUE
)
file_artifacts <- file_artifacts[!grepl(EXCLUDE, file_artifacts)]

file_hashes <- setNames(
    unname(md5sum(file_artifacts)),
    sub(paste0("^", here(), "/"), "", file_artifacts)
)
cat(sprintf("Hashed   %3d CSV/TSV/PNG files\n", length(file_hashes)))

## ── RDS ──────────────────────────────────────────────────────────────────────

rds_paths <- list.files(
    here("output"),
    pattern = "\\.rds$", recursive = TRUE, full.names = TRUE
)
rds_paths <- rds_paths[!grepl(EXCLUDE, rds_paths)]

rds_digests <- list()
for (p in rds_paths) {
    rel <- sub(paste0("^", here(), "/"), "", p)
    obj <- tryCatch(readRDS(p), error = function(e) NULL)
    if (is.null(obj)) { cat(sprintf("  SKIP (unreadable): %s\n", rel)); next }
    rds_digests[[rel]] <- digest::digest(obj, algo = "md5")
}
cat(sprintf("Digested %3d RDS files\n", length(rds_digests)))

## ── RDA (package data) ───────────────────────────────────────────────────────

rda_paths <- list.files(
    here("hallberg2025.base/data"),
    pattern = "\\.rda$", full.names = TRUE
)

rda_digests <- list()
for (p in rda_paths) {
    rel <- sub(paste0("^", here(), "/"), "", p)
    e <- new.env(parent = emptyenv())
    load(p, envir = e)
    rda_digests[[rel]] <- digest::digest(as.list(e), algo = "md5")
}
cat(sprintf("Digested %3d RDA package datasets\n", length(rda_digests)))

## ── supplemental_tables.xlsx ─────────────────────────────────────────────────
## Hash sheet contents, not the file, to avoid xlsx timestamp sensitivity.

xlsx_path <- here("manuscript/supplemental_tables.xlsx")
sheets     <- readxl::excel_sheets(xlsx_path)
xlsx_data  <- lapply(sheets, function(s)
    suppressMessages(readxl::read_excel(xlsx_path, sheet = s, col_types = "text")))
names(xlsx_data) <- sheets
xlsx_digest <- digest::digest(xlsx_data, algo = "md5")
cat(sprintf("Digested supplemental_tables.xlsx (%d sheets)\n", length(sheets)))

## ── Save ─────────────────────────────────────────────────────────────────────

baseline <- list(
    file_hashes  = file_hashes,
    rds_digests  = rds_digests,
    rda_digests  = rda_digests,
    xlsx_digest  = xlsx_digest,
    created      = format(Sys.time(), "%Y-%m-%d")
)

out <- here("tests/snapshots/artifact_baseline.rds")
saveRDS(baseline, out)
cat(sprintf("\nBaseline saved to %s\n", out))
