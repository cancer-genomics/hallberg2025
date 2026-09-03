library(digest)
library(here)

tex_files <- c(
  here("manuscript", "hallberg2025.Rtex"),
  here("manuscript", "supplemental.tex")
)

extract_figure_paths <- function(tex_file) {
  lines <- readLines(tex_file)
  m <- regmatches(lines,
                  gregexpr("\\\\includegraphics(?:\\[.*?\\])?\\{([^}]+)\\}",
                           lines, perl = TRUE))
  paths <- unlist(lapply(m, function(x) {
    if (!length(x)) return(character(0))
    sub(".*\\{([^}]+)\\}$", "\\1", x)
  }))
  paths <- gsub("\\\\_", "_", paths)
  gsub("^\\.\\./", "", paths)
}

baseline_file <- here("tests", "snapshots", "figure_hashes.rds")
if (!file.exists(baseline_file)) {
  stop("No figure baseline found. Run 'make figures-baseline' first.")
}
baseline <- readRDS(baseline_file)

paths <- unique(unlist(lapply(tex_files, extract_figure_paths)))
full  <- setNames(here(paths), paths)

current <- vapply(full, function(p) {
  if (!file.exists(p)) return(NA_character_)
  digest(p, file = TRUE, algo = "sha256")
}, character(1))
names(current) <- paths

all_paths  <- union(names(baseline), names(current))
n_match    <- 0L
flagged    <- character(0)

for (p in all_paths) {
  b  <- baseline[p]
  cu <- current[p]
  if (is.na(b)) {
    flagged <- c(flagged, sprintf("  NEW      %s", p))
  } else if (is.na(cu)) {
    flagged <- c(flagged, sprintf("  MISSING  %s", p))
  } else if (identical(b, cu)) {
    n_match <- n_match + 1L
  } else {
    flagged <- c(flagged, sprintf("  CHANGED  %s", p))
  }
}

n_flagged <- length(flagged)
cat(sprintf("\nFigure hash check: %d/%d match baseline",
            n_match, length(all_paths)))
if (n_flagged > 0) {
  cat(sprintf(", %d flagged for inspection\n\n", n_flagged))
  cat(paste(flagged, collapse = "\n"), "\n\n")
  cat("Flagged figures require visual inspection.\n")
  quit(status = 1)
} else {
  cat(" -- all match.\n")
}
