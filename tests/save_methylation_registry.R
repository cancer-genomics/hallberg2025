## Save methylation provenance registry (Step 0 of
## code/methylation_provenance_verification_plan.md, safeguard A).
##
## Records file-byte MD5s of the methylation frozen-frontier + anchor
## artifacts. This registry is the immutable ground truth that
## verify_methylation_registry.R checks against before any provenance
## step is allowed to run — it is what makes the reverse-topological
## verification meaningful rather than circular.
##
## Only re-run this script when a change to one of these files is
## INTENTIONAL and has already been verified against the manuscript
## baseline (Rscript tests/verify_snapshot.R passes). Commit the updated
## .rds together with a CHANGES.md entry explaining why.
##
## Usage: Rscript tests/save_methylation_registry.R

library(here)
library(tools)

REGISTRY_FILES <- c(
  bValsselect    = "extdata/bValsselect.rds",
  combmetadata   = "extdata/combmetadata.rds",
  se_jhu         = "output/methylation.Rmd/se.rds",
  se_lab_tcga    = "extdata/se_lab_tcga.rds",
  methylation_se = "hallberg2025.meth.data/inst/extdata/methylation_se.rds"
)

paths <- here(REGISTRY_FILES)
names(paths) <- names(REGISTRY_FILES)

missing <- paths[!file.exists(paths)]
if (length(missing) > 0) {
  stop("Missing registry file(s): ", paste(missing, collapse = ", "))
}

hashes <- as.character(md5sum(paths))
names(hashes) <- names(paths)

registry <- list(
  hashes       = hashes,
  rel_paths    = REGISTRY_FILES,
  ## Pin the two historical anchor states by git SHA so a future
  ## investigation can always recover them exactly, even after the
  ## working tree has moved on (see plan, "Immutable baselines" table).
  git_pins     = c(
    published_buggy_se_lab_tcga    = "1e84178",  # outer repo, extdata/se_lab_tcga.rds
    published_buggy_methylation_se = "15dd9ef",  # inner repo (ovarian.subtypes), data/methylation_se.rda
    corrected_methylation_se       = "0c3e70f"   # inner repo, post-Change-002
  ),
  recorded_date = "2026-07-04"
)

saveRDS(registry, here("tests", "snapshots", "methylation_provenance_registry.rds"))

cat("Saved methylation provenance registry:\n")
for (nm in names(hashes)) {
  cat(sprintf("  %-15s %s  (%s)\n", nm, hashes[[nm]], REGISTRY_FILES[[nm]]))
}
