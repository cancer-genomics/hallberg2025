# This directory contains analytic data that has been created from code outside of this repository.  Code that depends on these objects are listed below.

## Methylation data and dependencies:
bVals.rds:  manuscript/pca.Rtex code/methylation.Rmd
bVals081820.rds:  Rpackage/hallberg2025.base code/methylation.Rmd
combmetadata.rds:  Rpackage/hallberg2025.base/data-raw/methylation_se.R
mVals.rds:  code/assay_functions.R code/methylation.Rmd
mVals081820.rds: code/assay_functions.R code/methylation.Rmd
meth_081720/ :  code/methylation.Rmd
methdat082620.csv:  code/assay_functions.R code/methylation.Rmd
methylationmanifest.rds: code/assay_functions.R code/methylation.Rmd
se_lab_tcga.rds: Rpackage/hallberg2025.base/data-raw/methylation_se.R
targets.rds:  code/assay_functions.R  code/methylation.Rmd

## Mutation signature data and dependencies:
endosigs.rds:  analysis/ext-figure3.Rmd
mucsigs.rds: analysis/ext-figure3.Rmd

## Integrative figures
gene_pathway.csv:  code/gene_pathway.rmd
integrated_data.m_120420.rds: code/gene_pathway.rmd and code/05-data_integration.rmd
integrated_data_endo_120420.rds:  code/gene_pathway.rmd and code/05-data_integration.rmd
mutation_reports/: code/02-mutations.Rmd
AF-G4XH65-F1-model_v4.pdb: analysis/ext-figure2.Rmd

## Clinical data for manifest
sdat.rds:  Rpackage/hallberg2025.base/data-raw/manifest.R

## Trellis analyses
svpipelineConfig.txt:  ? facets analyses
trellis/


