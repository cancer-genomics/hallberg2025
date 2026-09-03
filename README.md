# Ovarian Cancer Subtypes — Hallberg et al. 2025

Companion code and data for:

> Hallberg D, Eastman AC, Koul S, Bruhm DC, Papp E, et al.
> "Genomic Landscapes of Endometrioid and Mucinous Ovarian Cancers and Morphologically Similar Tumor Types."
> *Cancer Research Communications* 5(11):1952–1966 (2025).

This repository contains the R package `hallberg2025.base` (data + functions) and the
`targets` pipeline that reproduces all numbers, figures, and tables in the manuscript.

---

## Repository layout

```
_targets.R                  # manuscript pipeline (tar_make reproduces all text statistics)
hallberg2025.base/          # R package: stripped sample data + analysis functions
  R/                        # source modules
  data/                     # PHI-free .rda datasets (manifest, methylation_se, idat, …)
  DESCRIPTION / NAMESPACE
analysis/                   # workflowr Rmds → docs/ HTML (figures and supplemental tables)
manuscript/                 # LaTeX source, compiled PDF, supplemental Excel tables
code/                       # upstream data processing scripts (requires restricted BAM data)
extdata/                    # public reference data (TCGA methylation SE, AlphaFold PDB, …)
data/                       # small shared data objects (color palettes, gene-pathway table)
tests/                      # snapshot verification (verify_snapshot.R)
output/                     # pre-computed intermediate files consumed by _targets.R
docs/                       # pre-built HTML analysis website (view without running Rmds)
```

---

## Reproducing the manuscript statistics

All 35 manuscript values are computed by `tar_make()` from the package data and
the pre-computed intermediate files in `output/`.  No restricted sample-level
data (BAMs, IDATs) is required.

The pipeline draws on three companion packages: `hallberg2025.base` (data and
analysis functions), `hallberg2025.seq.data` (FACETS/trellis copy-number
outputs) and `hallberg2025.meth.data` (the methylation
`SummarizedExperiment`).  The first two are public; see the note below on
`hallberg2025.meth.data`.

```r
# 1. Install the companion packages from GitHub
install.packages("remotes")
remotes::install_github("cancer-genomics/hallberg2025.base")
remotes::install_github("cancer-genomics/hallberg2025.seq.data")
remotes::install_github("cancer-genomics/hallberg2025.meth.data")

# 2. Install pipeline dependencies
install.packages(c("targets", "tarchetypes", "tidyverse",
                   "knitr", "magrittr", "survival"))

# 3. Run the pipeline
library(targets)
tar_make()

# 4. Verify all 35 values match the published baseline
Rscript tests/verify_snapshot.R
```

Expected output of step 4: `OK (manuscript values): all 35 values match baseline`
(alongside the figure and table checks `verify_snapshot.R` also runs).

---

## Reproducing the analysis website (figures and supplemental tables)

The pre-built HTML pages are in `docs/`.  To re-render from source:

```r
library(workflowr)
wflow_build()
```

**Note:** Seven analysis pages read FACETS/trellis copy-number output, which
is not stored in this repository.  It is distributed in the companion package
`hallberg2025.seq.data`, a public repository on GitHub:

```r
remotes::install_github("cancer-genomics/hallberg2025.seq.data")
```

With that package installed these pages re-render like any other; sample
identifiers are CG lab IDs throughout.  Each page reaches its data through an
exported accessor rather than a file path:

| Page | Accessor in `hallberg2025.seq.data` |
|------|-------------------------------------|
| `analysis/ext-figure1.Rmd`   | `wgs_summary_stats()`, `wes_summary_stats()` |
| `analysis/ext-figure4-7.Rmd` | `extfig47_circos_grobs()` |
| `analysis/ext-figure8.Rmd`   | `extfig8_rlist()` |
| `analysis/table_s6.Rmd`      | `wgs_amplicon_table()` |
| `analysis/table_s7.Rmd`      | `wes_segments()` |
| `analysis/table_s8.Rmd`      | `wgs_deletion_table()` |
| `analysis/table_s9.Rmd`      | `wgs_fusion_table()` |

The remaining analysis pages (`figure1`–`figure6`, `ext-figure2`,
`ext-figure3`, `ext-figure9`–`ext-figure11`, `table_s1`–`table_s5`) need only
`hallberg2025.base`.  Pre-built HTML for every page is in `docs/`, so the whole
site can be inspected without running anything.

---

## Data

Sample-level data is in `hallberg2025.base/data/`:

| Object | Description |
|--------|-------------|
| `manifest` | 220 tumor/normal samples; CG lab IDs only |
| `clinical` | Overall survival and clinical covariates |
| `idat.endometrioid` | Integrated somatic alterations — endometrioid subtypes |
| `idat.mucinous` | Integrated somatic alterations — mucinous subtypes |
| `idat.gi` | Integrated somatic alterations — GI mucinous subtypes |
| `methylation` | CpG methylation fractions (JHU cohort) |
| `hypermut` | Hypermutated samples (excluded from mutation analyses) |

The methylation `SummarizedExperiment` (JHU + TCGA β-values) is not a
`hallberg2025.base` data object; it is served by the companion package as
`hallberg2025.meth.data::methylation_se()`.

The file `data/gene.pathway.csv` is a curated gene-to-pathway annotation table
(165 rows; columns: `gene.symbol`, `pathway`, `tumor_type`). It maps genes to
biological pathways separately for the endometrioid and mucinous subtypes,
reflecting modest differences in the gene sets of interest across tumor types.
It is read via the `gene_pathway_file` target in `_targets.R` so downstream
manuscript numbers are invalidated if it is updated.

All identifiers are CG lab IDs (e.g., `CGOV167T`, `CGCRC245T`).
No PGDX internal identifiers, BAM paths, or patient dates are present.

---

## Package installation

Install the companion packages from GitHub:

```r
remotes::install_github("cancer-genomics/hallberg2025.base")
remotes::install_github("cancer-genomics/hallberg2025.seq.data")
remotes::install_github("cancer-genomics/hallberg2025.meth.data")
```

`hallberg2025.base` and `hallberg2025.seq.data` are public.
**`hallberg2025.meth.data` is currently a private repository**; it is required
by `tar_make()` only, so request access from the corresponding author until it
is released.  The analysis website does not use it — every page in `analysis/`,
including all seven `hallberg2025.seq.data` pages above, renders without it.

### Reproducing from raw data

The three commands above reproduce every manuscript number, figure, and
supplemental table from the packaged summary data — no restricted sample-level
data (BAMs, IDATs) and no cluster are needed.  Regenerating that summary data
from the raw sequencing and array files is a separate, larger undertaking: it
runs the `data-raw/` pipeline inside each companion package
(`hallberg2025.seq.data/data-raw/` for the FACETS/trellis copy-number arm,
`hallberg2025.meth.data/data-raw/` for the methylation arm) and needs the raw
BAMs and IDATs, which are controlled-access — the sequencing data is deposited
in the EGA and released only under a data use agreement.  Contact the
corresponding author to start that process.

---

## Session info

R version and key package versions used to generate the published results
are recorded in `renv.lock`.  The pipeline was run with R 4.5.3 and
Bioconductor 3.22.

---

## License

GPL-3 — see `LICENSE`.

## Citation

```bibtex
@Article{hallberg2025,
  author  = {Hallberg, Dorothy and Eastman, Alice C. and Koul, Shashikant and
             Bruhm, Daniel C. and Papp, Eniko and Davenport, Simon and
             Adleff, Vilmos and Ferreira, Leonardo and Niknafs, Noushin and
             Medina, Jamie E. and Cristiano, Stephen and Hruban, Carolyn and
             Fiksel, Jacob and Lebarbenchon, Kaui P. and Aparicio, Luis and
             Vulpescu, Nicholas A. and Kuo, Kuan-Ting and Ahuja, Nita and
             Drapkin, Ronny and Jung, Euihye and Kim, Sarah H. and
             Eckert, Mark A. and Lengyel, Ernst and Nakayama, Kentaro and
             Ayhan, Ayse and Shih, Ie-Ming and Wang, Tian-Li and
             Lavie, Ofer and Rennert, Gad and Easwaran, Hariharan and
             Baylin, Stephen B. and Press, Michael F. and
             Velculescu, Victor E. and Scharpf, Robert B.},
  title   = {Genomic {Landscapes} of {Endometrioid} and {Mucinous} {Ovarian}
             {Cancers} and {Morphologically} {Similar} {Tumor} {Types}},
  journal = {Cancer Res Commun},
  year    = {2025},
  volume  = {5},
  number  = {11},
  pages   = {1952--1966},
  month   = {nov}
}
```
