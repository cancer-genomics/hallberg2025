## Snapshot verification script
##
## Checks three things:
##   1. Manuscript values — 35 numerical \Sexpr{} targets vs baseline
##   2. Figure PNGs       — MD5 hashes vs figure_hashes.rds baseline
##   3. Table files       — MD5 hashes vs artifact_baseline.rds$file_hashes
##
## Usage: Rscript tests/verify_snapshot.R
##
## Exit code 0: all checks pass.
## Exit code 1: one or more checks fail.
##
## All 25 figure PNGs are tracked in figure_hashes.rds.  PNGs are used
## instead of PDFs because R's PNG device produces stable byte output
## across sessions, whereas PDFs embed timestamps and session metadata.
##
## When figures are intentionally re-rendered, update the baseline with:
##   pngs <- list.files("docs/figure", pattern = "[.]png$",
##                      recursive = TRUE, full.names = TRUE)
##   saveRDS(setNames(tools::md5sum(pngs), pngs), "tests/snapshots/figure_hashes.rds")
## and commit with a message explaining why.

library(targets)
library(here)

## Rmds that .github/workflows/check.yml's "Build workflowr analysis pages" step
## deliberately never rebuilds in CI (private/PHI-bearing inputs, or a live external
## API call) -- see check.yml's own `skip <- c(...)` vector, which this list must be
## kept in sync with by hand (GATE-03; the two can't be shared directly, one lives in
## a workflow YAML `run:` block). This applies to the FIGURE check only: their
## baseline-listed figure PNGs are genuinely never produced by a CI run (table_s2's
## and ext-figure2's underlying data/library dependency are unavailable there), so
## they are excluded from the missing-file check below rather than reported as an
## eternal, ignorable "MISSING" line. table_s4/table_s5 are also skip-listed but
## contribute no figure PNGs to the baseline, so they never actually hit this path --
## listed anyway so the mapping to check.yml's own vector stays exact and obviously
## complete at a glance.
CI_SKIPPED_RMD_STEMS <- c("table_s2", "table_s4", "table_s5", "ext-figure2")

## One narrower case than a whole skipped Rmd: figure1.Rmd itself runs fine in CI (its
## other PNGs, e.g. fig1-1.png, are checked normally), but this one chunk's PDF-to-PNG
## composite step is conditional on ImageMagick being present locally (analysis/CLAUDE.md)
## and isn't produced in the CI environment. Exact-path, not stem-level, so the rest of
## figure1.Rmd's output stays fully checked.
CI_SKIPPED_EXACT_PATHS <- c("docs/figure/figure1.Rmd/unnamed-chunk-1-1.png")

## GATE-03's published policy, finally reaching the code (GATE-07). figure_hashes.rds is
## Linux-CI-authoritative: the baseline is produced by the amd64 container CI runs in, and
## PNG rasterization is not bit-identical across platform/toolchain, so an arm64 macOS run
## cannot reproduce it. tests/CLAUDE.md has said "only CI's run is meaningful for the
## figure check now" since 2026-08-01 -- but the script kept failing fatally anyway, which
## left the gate root CLAUDE.md calls "the universal gate" permanently red and trained
## everyone to ignore the one signal it exists to carry.
##
## So: off Linux the figure check REPORTS but does not affect the exit status. On Linux it
## is unchanged and strictly fatal -- CI is where this is actually enforced. Manuscript
## values and table hashes stay fatal on every platform; they are platform-stable and are
## what actually catches a regression locally.
##
## Do NOT "fix" a local mismatch by re-saving figure_hashes.rds: that replaces an
## amd64-authoritative hash with an arm64 one and breaks CI (GATE-06, REL-20's Do NOT).
FIGURE_CHECK_FATAL <- identical(Sys.info()[["sysname"]], "Linux")

is_ci_skipped <- function(rel_paths) {
    ## rel_paths look like docs/figure/<stem>.Rmd/<file>.png
    stem <- sub("[.]Rmd$", "", basename(dirname(rel_paths)))
    (stem %in% CI_SKIPPED_RMD_STEMS) | (rel_paths %in% CI_SKIPPED_EXACT_PATHS)
}

pass <- TRUE

## ── 1. Manuscript values ──────────────────────────────────────────────────────

vals_file <- here("tests", "snapshots", "manuscript_values_baseline.rds")
if (!file.exists(vals_file)) {
    stop("Manuscript values baseline not found: ", vals_file)
}

manuscript_vals <- readRDS(vals_file)
target_names    <- names(manuscript_vals)

value_changed  <- character(0)
target_missing <- character(0)

for (nm in target_names) {
    current_val <- tryCatch(tar_read_raw(nm), error = function(e) NULL)
    if (is.null(current_val)) {
        target_missing <- c(target_missing, nm)
        next
    }
    baseline_val <- manuscript_vals[[nm]]$value
    b_str <- paste(as.character(unlist(baseline_val)), collapse = " / ")
    c_str <- paste(as.character(unlist(current_val)),  collapse = " / ")
    if (!identical(b_str, c_str)) {
        value_changed <- c(value_changed, nm)
        cat(sprintf("CHANGED %s:\n  baseline = %s\n  current  = %s\n",
                    nm, b_str, c_str))
    }
}

if (length(target_missing) > 0) {
    cat("MISSING targets (in baseline, not built):\n")
    cat(paste(" -", target_missing), sep = "\n"); cat("\n")
    pass <- FALSE
}
if (length(value_changed) > 0) {
    pass <- FALSE
} else if (length(target_missing) == 0) {
    cat(sprintf("OK (manuscript values): all %d values match baseline\n",
                length(target_names)))
}

## ── 2. Figure PNG hashes ──────────────────────────────────────────────────────

fig_hash_file <- here("tests", "snapshots", "figure_hashes.rds")
if (!file.exists(fig_hash_file)) {
    cat("WARN: figure_hashes.rds not found — skipping figure check\n")
} else {
    fig_baseline <- readRDS(fig_hash_file)
    fig_checked  <- fig_baseline[!is_ci_skipped(names(fig_baseline))]

    fig_missing  <- character(0)
    fig_changed  <- character(0)

    for (rel_path in names(fig_checked)) {
        full_path <- here(rel_path)
        if (!file.exists(full_path)) {
            fig_missing <- c(fig_missing, rel_path)
        } else {
            current_hash <- unname(tools::md5sum(full_path))
            if (!identical(current_hash, fig_baseline[[rel_path]])) {
                fig_changed <- c(fig_changed, rel_path)
                cat(sprintf("CHANGED figure %s\n  baseline = %s\n  current  = %s\n",
                            rel_path, fig_baseline[[rel_path]], current_hash))
            }
        }
    }

    if (length(fig_missing) > 0) {
        cat("MISSING figure PNGs:\n")
        cat(paste(" -", fig_missing), sep = "\n"); cat("\n")
        if (FIGURE_CHECK_FATAL) pass <- FALSE
    }
    if (length(fig_changed) > 0) {
        if (FIGURE_CHECK_FATAL) pass <- FALSE
    } else if (length(fig_missing) == 0) {
        cat(sprintf(
            "OK (figures): all %d checked PNG hashes match baseline (%d of %d total excluded -- CI-skipped Rmd, never rebuilt)\n",
            length(fig_checked), length(fig_baseline) - length(fig_checked), length(fig_baseline)))
    }

    if (!FIGURE_CHECK_FATAL && (length(fig_changed) > 0 || length(fig_missing) > 0)) {
        cat(sprintf(
            "WARN (figures): %d changed, %d missing -- NOT fatal on %s.\n",
            length(fig_changed), length(fig_missing), Sys.info()[["sysname"]]))
        cat("  figure_hashes.rds is Linux-CI-authoritative (GATE-03); only CI's figure\n",
            "  check is meaningful. Do not re-save the baseline from this machine.\n",
            sep = "")
    }
}

## ── 3. Table file hashes ─────────────────────────────────────────────────────

artifact_file <- here("tests", "snapshots", "artifact_baseline.rds")
if (!file.exists(artifact_file)) {
    cat("WARN: artifact_baseline.rds not found — skipping table check\n")
} else {
    artifact    <- readRDS(artifact_file)
    all_hashes  <- artifact$file_hashes
    tbl_hashes  <- all_hashes[grepl("^docs/table/", names(all_hashes))]
    tbl_missing <- character(0)
    tbl_changed <- character(0)

    for (rel_path in names(tbl_hashes)) {
        full_path <- here(rel_path)
        if (!file.exists(full_path)) {
            tbl_missing <- c(tbl_missing, rel_path)
        } else {
            current_hash <- unname(tools::md5sum(full_path))
            if (!identical(current_hash, tbl_hashes[[rel_path]])) {
                tbl_changed <- c(tbl_changed, rel_path)
                cat(sprintf("CHANGED table %s\n  baseline = %s\n  current  = %s\n",
                            rel_path, tbl_hashes[[rel_path]], current_hash))
            }
        }
    }

    if (length(tbl_missing) > 0) {
        cat("MISSING table files:\n")
        cat(paste(" -", tbl_missing), sep = "\n"); cat("\n")
        pass <- FALSE
    }
    if (length(tbl_changed) > 0) {
        pass <- FALSE
    } else if (length(tbl_missing) == 0) {
        cat(sprintf("OK (tables): all %d table hashes match baseline\n",
                    length(tbl_hashes)))
    }
}

## ── Summary ───────────────────────────────────────────────────────────────────

if (pass) {
    quit(status = 0)
} else {
    n_val <- length(value_changed)
    n_fig <- if (exists("fig_changed"))  length(fig_changed)  else 0L
    n_tbl <- if (exists("tbl_changed"))  length(tbl_changed)  else 0L
    n_mis <- length(target_missing) +
             (if (exists("fig_missing")) length(fig_missing) else 0L) +
             (if (exists("tbl_missing")) length(tbl_missing) else 0L)
    cat(sprintf(
        "FAIL: %d value(s) changed, %d figure(s) changed, %d table(s) changed, %d missing\n",
        n_val, n_fig, n_tbl, n_mis))
    quit(status = 1)
}
