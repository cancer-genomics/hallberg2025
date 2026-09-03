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
  paths <- gsub("\\\\_", "_", paths)   # unescape LaTeX \_
  gsub("^\\.\\./", "", paths)          # ../docs/... -> docs/...
}

paths <- unique(unlist(lapply(tex_files, extract_figure_paths)))
full  <- setNames(here(paths), paths)

missing <- full[!file.exists(full)]
if (length(missing)) {
  cat("Missing PDFs (run 'make pdf' first):\n")
  cat(paste(" ", missing), sep = "\n")
  stop("Baseline not saved.")
}

hashes <- vapply(full, digest, character(1), file = TRUE, algo = "sha256")
names(hashes) <- paths

out <- here("tests", "snapshots", "figure_hashes.rds")
saveRDS(hashes, out)
cat(sprintf("Saved baseline for %d figure PDFs -> %s\n", length(hashes), out))
cat(paste(sprintf("  %s", names(hashes)), collapse = "\n"), "\n")
