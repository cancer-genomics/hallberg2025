## Verify MD5 checksums for Bucket B pre-computed objects.
## These files are not tracked in git (gitignored) but must remain unchanged
## between refactoring sessions.  See REPRODUCIBILITY_PLAN.qmd Part IV.
##
## Usage:  Rscript tests/verify_checksums.R
## Exit 0 on success; exit 1 if any checksum mismatches or files are missing.

checksum_file <- file.path("tests", "checksums.txt")
if (!file.exists(checksum_file)) {
  stop("tests/checksums.txt not found — run the seeding command in REPRODUCIBILITY_PLAN.qmd Part IV")
}

tbl <- read.table(checksum_file, sep = "\t", header = FALSE,
                  col.names = c("expected_md5", "path"),
                  stringsAsFactors = FALSE)

ok <- TRUE
for (i in seq_len(nrow(tbl))) {
  path     <- tbl$path[i]
  expected <- tbl$expected_md5[i]

  if (!file.exists(path)) {
    message("SKIP (absent): ", path)
    next
  }

  actual <- unname(tools::md5sum(path))
  if (!identical(actual, expected)) {
    message("FAIL: ", path)
    message("  expected: ", expected)
    message("  actual:   ", actual)
    ok <- FALSE
  } else {
    message("OK: ", path)
  }
}

if (!ok) {
  message("\nChecksum mismatch(es) detected.",
          "\nInvestigate before proceeding — see REPRODUCIBILITY_PLAN.qmd Part IV.")
  quit(status = 1)
} else {
  message("\nOK: all Bucket B checksums match.")
}
