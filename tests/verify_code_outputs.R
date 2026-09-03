## verify_code_outputs.R
##
## Figure 6 outputs were previously written to output/figure6_*.Rmd/ by four
## separate Rmd files (figure6_jhu-LDA.Rmd, figure6_tcga-LDA.Rmd,
## figure6_jhu-heatmap.Rmd, figure6_tcga-heatmap.Rmd).  As of Phase 6
## (2026-06-27) those files have been deleted; the computations now run inside
## the targets pipeline (_targets.R) as the targets:
##
##   lda_samples, lda_model, tcga_lda_proj, lda_cancer_types,
##   jhu_lda_groups, probLDA, jhu_lda_fig, tcga_lda_fig,
##   tcga_heatmap, jhu_heatmap
##
## Output integrity is verified by verify_snapshot.R (which checks all
## 35 human-readable manuscript values against their Phase 0 baseline).
## Run that script instead:
##
##   Rscript tests/verify_snapshot.R
##
## This script is retained as a record of the old file-based approach and
## exits 0 without checking anything.

cat("Note: file-based figure6 outputs have moved into _targets.R.\n")
cat("Run Rscript tests/verify_snapshot.R to verify manuscript values.\n")
quit(status = 0)
