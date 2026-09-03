## Verify methylation provenance registry (Step 0 of
## code/methylation_provenance_verification_plan.md, safeguards A + E).
##
## Confirms the methylation frozen-frontier + anchor files on disk still
## match the committed registry. Run this BEFORE any hallberg2025.meth.data
## data-raw/_targets.R provenance step, and before trusting a
## verify_against_baseline() result from that pipeline: a step's
## "identical" result only means something if the frozen frontier it
## read is the frontier the registry says it should be.
##
## Usage: Rscript tests/verify_methylation_registry.R
## Exit code 0: all five files match. Exit code 1: drift detected.

library(here)
library(tools)

registry_file <- here("tests", "snapshots", "methylation_provenance_registry.rds")
if (!file.exists(registry_file)) {
  stop("Registry not found: ", registry_file,
       "\nRun Rscript tests/save_methylation_registry.R first (Step 0).")
}

registry <- readRDS(registry_file)
paths <- here(registry$rel_paths)
names(paths) <- names(registry$rel_paths)

pass <- TRUE

missing <- names(paths)[!file.exists(paths)]
if (length(missing) > 0) {
  cat("MISSING registry file(s):\n")
  for (nm in missing) cat(sprintf("  %-15s %s\n", nm, registry$rel_paths[[nm]]))
  pass <- FALSE
}

present <- setdiff(names(paths), missing)
current_hashes <- as.character(md5sum(paths[present]))
names(current_hashes) <- present

for (nm in present) {
  baseline_hash <- registry$hashes[[nm]]
  if (!identical(current_hashes[[nm]], baseline_hash)) {
    cat(sprintf(
      "DRIFTED %s (%s):\n  registry = %s\n  current  = %s\n",
      nm, registry$rel_paths[[nm]], baseline_hash, current_hashes[[nm]]
    ))
    pass <- FALSE
  }
}

if (pass) {
  cat("OK: all", length(paths), "methylation provenance registry files match.\n")
  quit(status = 0)
} else {
  cat("\nIf a drift above is INTENTIONAL (e.g. a corrected upstream re-fetch),\n",
      "verify the change against Rscript tests/verify_snapshot.R first, then\n",
      "re-run Rscript tests/save_methylation_registry.R and commit the update\n",
      "together with a CHANGES.md entry.\n", sep = "")
  quit(status = 1)
}
