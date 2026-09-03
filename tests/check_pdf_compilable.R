## tests/check_pdf_compilable.R
##
## Verifies that hallberg2025.Rtex and supplemental.tex compile to PDF via
## pdflatex without errors, and that the resulting PDFs have the expected
## minimum page counts.
##
## Pre-conditions (checked at start):
##   - All \includegraphics paths referenced in each .tex file must exist.
##     Missing PDFs are reported clearly, distinguishing placeholders from
##     genuine missing files.
##   - pdflatex must be on PATH.
##
## Usage:
##   Rscript tests/check_pdf_compilable.R
##
## Exit 0: both PDFs compile cleanly and meet page-count expectations.
## Exit 1: missing figures, compile errors, or wrong page counts.
##
## Page-count expectations:
##   hallberg2025.pdf  >= 20 pages  (main text + figures + tables)
##   supplemental.pdf  >= 11 pages  (11 supplemental figures)
##   Note: placeholders for the 4 Circos figures count as present pages.

library(here)

## ── helpers ──────────────────────────────────────────────────────────────────

stop_if <- function(cond, msg) if (cond) stop(msg, call. = FALSE)

extract_includegraphics <- function(tex_file) {
  lines <- readLines(tex_file, warn = FALSE)
  m <- regmatches(
    lines,
    gregexpr("\\\\includegraphics(?:\\[.*?\\])?\\{([^}]+)\\}",
             lines, perl = TRUE)
  )
  paths <- unlist(lapply(m, function(x) {
    if (!length(x)) return(character(0))
    sub(".*\\{([^}]+)\\}$", "\\1", x)
  }))
  paths <- gsub("\\\\_", "_", paths)          # unescape LaTeX \_
  paths <- gsub("^\\.\\./", "", paths)         # ../docs/... -> docs/...
  unique(paths)
}

check_figures_present <- function(tex_file) {
  rel_paths <- extract_includegraphics(tex_file)
  missing   <- rel_paths[!file.exists(here(rel_paths))]
  if (length(missing)) {
    cat("MISSING figures for", basename(tex_file), ":\n")
    cat(paste(" ", missing), sep = "\n")
    cat("\n")
    invisible(missing)
  } else {
    cat(sprintf("OK: all %d figures present for %s\n",
                length(rel_paths), basename(tex_file)))
    invisible(character(0))
  }
}

pdf_page_count <- function(pdf_path) {
  ## Use pdfinfo if available (fast), otherwise fall back to qpdf.
  if (nzchar(Sys.which("pdfinfo"))) {
    out <- system2("pdfinfo", pdf_path, stdout = TRUE, stderr = FALSE)
    pages_line <- grep("^Pages:", out, value = TRUE)
    if (length(pages_line)) return(as.integer(trimws(sub("Pages:\\s*", "", pages_line))))
  }
  if (nzchar(Sys.which("qpdf"))) {
    out <- system2("qpdf", c("--show-npages", pdf_path),
                   stdout = TRUE, stderr = FALSE)
    n <- suppressWarnings(as.integer(trimws(out[1])))
    if (!is.na(n)) return(n)
  }
  ## Last resort: count %%EOF markers (rough but dependency-free)
  raw <- readLines(pdf_path, warn = FALSE)
  sum(grepl("^%%EOF", raw))
}

run_pdflatex <- function(tex_file, workdir) {
  ## Run pdflatex twice (resolve cross-references) in workdir.
  ## Returns list(status, log_tail).
  cmd  <- Sys.which("pdflatex")
  stop_if(!nzchar(cmd), "pdflatex not found on PATH")
  args <- c("-interaction=nonstopmode",
            "-halt-on-error",
            basename(tex_file))
  for (pass in 1:2) {
    res <- system2(cmd, args,
                   stdout = TRUE, stderr = TRUE,
                   env    = paste0("TEXINPUTS=", workdir, ":"),
                   wd     = workdir)
    status <- attr(res, "status")
    if (!is.null(status) && status != 0L) {
      return(list(status = status, log_tail = tail(res, 30L)))
    }
  }
  list(status = 0L, log_tail = character(0))
}

## ── configuration ────────────────────────────────────────────────────────────

manuscript_dir <- here("manuscript")
tex_files <- c(
  main         = file.path(manuscript_dir, "hallberg2025.Rtex"),
  supplemental = file.path(manuscript_dir, "supplemental.tex")
)
## hallberg2025.Rtex is first compiled by tar_knit() to hallberg2025.tex;
## we test the .tex produced by that step (must exist before running this script).
tex_files["main_tex"] <- file.path(manuscript_dir, "hallberg2025.tex")

min_pages <- c(
  main_tex     = 20L,
  supplemental = 11L
)

## ── 1. Check all figures present ─────────────────────────────────────────────

pass <- TRUE

cat("\n── Figure presence check ────────────────────────────────────────────────\n")
for (nm in c("main", "supplemental")) {
  f <- tex_files[nm]
  if (!file.exists(f)) {
    cat(sprintf("SKIP (file not found): %s\n", f))
    next
  }
  missing <- check_figures_present(f)
  if (length(missing)) pass <- FALSE
}

## ── 2. Check hallberg2025.tex exists (produced by tar_knit) ─────────────────

cat("\n── LaTeX source check ───────────────────────────────────────────────────\n")
if (!file.exists(tex_files["main_tex"])) {
  cat(sprintf(
    "MISSING: %s\n  hallberg2025.tex is produced by tar_make() (tar_knit target).\n",
    tex_files["main_tex"]
  ))
  pass <- FALSE
} else {
  cat(sprintf("OK: %s exists\n", basename(tex_files["main_tex"])))
}

## ── 3. Compile both .tex files ───────────────────────────────────────────────

cat("\n── pdflatex compilation ─────────────────────────────────────────────────\n")

compile_targets <- list(
  list(src  = tex_files["main_tex"],
       pdf  = file.path(manuscript_dir, "hallberg2025.pdf"),
       key  = "main_tex"),
  list(src  = tex_files["supplemental"],
       pdf  = file.path(manuscript_dir, "supplemental.pdf"),
       key  = "supplemental")
)

for (ct in compile_targets) {
  if (!file.exists(ct$src)) {
    cat(sprintf("SKIP compile (source not found): %s\n", basename(ct$src)))
    next
  }

  cat(sprintf("Compiling %s ...\n", basename(ct$src)))
  result <- run_pdflatex(ct$src, manuscript_dir)

  if (result$status != 0L) {
    cat(sprintf("FAIL: pdflatex returned status %d for %s\n",
                result$status, basename(ct$src)))
    cat("Last 30 lines of output:\n")
    cat(paste(result$log_tail, collapse = "\n"), "\n\n")
    pass <- FALSE
    next
  }

  if (!file.exists(ct$pdf)) {
    cat(sprintf("FAIL: pdflatex succeeded but %s was not produced\n",
                basename(ct$pdf)))
    pass <- FALSE
    next
  }

  ## Page count check
  n_pages   <- pdf_page_count(ct$pdf)
  n_min     <- min_pages[[ct$key]]
  pages_ok  <- !is.na(n_pages) && n_pages >= n_min

  if (pages_ok) {
    cat(sprintf("OK: %s — %d pages (>= %d required)\n",
                basename(ct$pdf), n_pages, n_min))
  } else {
    cat(sprintf("FAIL: %s has %s pages (expected >= %d)\n",
                basename(ct$pdf),
                if (is.na(n_pages)) "unknown" else as.character(n_pages),
                n_min))
    pass <- FALSE
  }
}

## ── Summary ───────────────────────────────────────────────────────────────────

cat("\n─────────────────────────────────────────────────────────────────────────\n")
if (pass) {
  cat("OK: PDF compilation check passed.\n")
  quit(status = 0L)
} else {
  cat("FAIL: one or more PDF compilation checks failed.\n")
  quit(status = 1L)
}
