# Changes from Published Analysis (Hallberg et al., *Cancer Res Commun* 2025)

This file tracks every deviation between the current repository and the analysis
as originally published. Each entry records what changed, why, and whether the
scientific conclusion is affected.

---

## Change 001 — Mutation spectra: corrected ref/alt swap in substitution normalization

**Date:** 2025 (detected during Phase 6 code refactoring)  
**Affects:** Figure 2 (mutation spectra panel), Figure 4 (mutation spectra panel)  
**Manuscript text affected:** None — mutation_spectra feeds only figures, not `\Sexpr{}` targets  

### What changed

The mutation spectra displayed in the published Figures 2 and 4 had the reference
and alternate alleles swapped when converting raw substitutions to pyrimidine convention.

**Root cause:** Commit `33780c7` ("Correction of typo", 2024-08-05, author K. Lebarbenchon)
renamed two variables in `code/05-data_integration.rmd` — `oldbase` → `ref_base` and
`newbase` → `alt_base` — without recognizing that the underlying `strsplit` expressions
were already extracting them in reverse order:

```r
# After the "correction" — WRONG (ref_base actually extracts ALT):
ref_base <- strsplit(subs3$mutation, "[0-9]_[ATCG]") %>%  # → yields ALT
    map_chr(function(x) x[[2]]) %>%
    map_chr(function(x) substr(x, nchar(x), nchar(x)))

alt_base <- strsplit(subs3$mutation, "_[ATCG]$") %>%       # → yields REF
    map_chr(function(x) substr(x, nchar(x), nchar(x)))
```

For the mutation string format `chrN_start-end_REF_ALT`:
- Splitting on `[0-9]_[ATCG]` (last digit + `_` + REF) leaves `_ALT` as the
  second element → last character is **ALT**, not REF.
- Splitting on `_[ATCG]$` (last `_` + ALT) leaves `…_REF` → last character is
  **REF**, not ALT.

So the rename caused `firstbase` (used as the reference for pyrimidine
normalization) to hold the **alternate** allele. Substitutions were normalized
from the wrong strand.

The current implementation in `ovarian.subtypes/R/mutations.R`
(`build_mutation_spectra`) uses `stringr::str_match(subs$mutation,
"([ATCG])_([ATCG])$")`, which correctly extracts REF (group 1) and ALT
(group 2).

### Example: CGOV70T

| Substitution | Published (swapped) | Current (correct) |
|---|---|---|
| C>A | 3 | 5 |
| C>G | 3 | 3 |
| C>T | 1 | **12** |
| T>A | 2 | 2 |
| T>C | **12** | 1 |
| T>G | 5 | 3 |
| **Total** | **26** | **26** |

In the published figures, the 12 C>T transitions (the dominant class,
consistent with an aging/deamination signature) appeared as T>C.

### Scientific interpretation

The total number of substitutions per sample is unchanged. The biological
interpretation of the dominant mutational process (C>T transitions, SBS1/SBS5
deamination/aging signature) is unchanged — it was simply displayed under the
wrong label. No manuscript text statistics are affected.

### Baseline update

Figure PDF SHA-256 hashes updated in `tests/snapshots/figure_hashes.rds`:

| Figure | Old hash (swapped) | New hash (correct) |
|---|---|---|
| `docs/figure/figure2.Rmd/fig2-1.pdf` | `d9ee8b2c…` | `331fb938…` |
| `docs/figure/figure4.Rmd/fig4-1.pdf` | `ba2bc2c9…` | `6945098b…` |

---

## Change 002 — Methylation: mislabeling of the "additional JHU" Normal samples in `se_lab_tcga`

**Status:** RESOLVED (2026-07-04) — root cause fixed in `build_se_lab_tcga()`; baseline
artifacts (`ovarian.subtypes/data/methylation_se.rda`,
`ovarian.subtypes/inst/extdata/se_lab_tcga.rds`) regenerated with corrected code; all 35
manuscript values, 25 figure PNGs, and 9 table hashes confirmed unchanged by
`make verify`. **Affected-sample count corrected 2026-07-04 (later same day)** — see
"Correction to affected-sample count" below; the fix itself and the "no manuscript
impact" conclusion are unchanged.

**Date:** 2026-07-04 (found during OsMethExpData Step 2 provenance verification)  
**Affects:** `ovarian.subtypes/data/methylation_se.rda` (15 of 27 mislabeled samples
survive into this published object), `ovarian.subtypes/inst/extdata/se_lab_tcga.rds`
(private intermediate, all 27 of the "additional JHU" block)  
**Manuscript text/figures affected:** None currently rendered (see "Downstream
consequences" below)

### What changed

`build_se_lab_tcga()` (`ovarian.subtypes/R/methylation.R`, ported from the archived
`methylation_summarized_experiment.Rmd`) builds `se_lab_tcga` from two sources: a primary
233-sample block (`bValsselect.rds` + `combmetadata.rds`) and an "additional JHU" block of
27 samples pulled from `output/methylation.Rmd/se.rds` that aren't already in the primary
block. For that second block, `colData()` was assigned to the SummarizedExperiment
**positionally**:

```r
df.addl.jhu <- filter(manifest2, lab_id %in% colnames(se.jhu3)) %>%
    select(lab_id, diagnosis, tumor, study)
colData(se.jhu3) <- DataFrame(df.addl.jhu)   # trusts row order == colnames(se.jhu3) order
```

This assumes `df.addl.jhu`'s row order already matches `se.jhu3`'s physical column order.
It doesn't: the manifest-filtered rows are grouped/ordered however `manifest2` naturally
sorts (by diagnosis), while `se.jhu3`'s columns stay in `se.jhu`'s original order. Because
samples within a diagnosis/tumor/study group share identical metadata, the resulting
label-to-data mismatch is invisible at the metadata level — the sample sheet still looks
correct — only the underlying 945-marker beta values are swapped.

Fixed by replacing the positional assignment with an explicit name-based alignment:
`arrange(match(lab_id, colnames(se.jhu3)))` plus `row.names = colnames(se.jhu3)` on the
`DataFrame()` call.

### Evidence this predates the current refactor (not introduced by it)

The positional-assignment logic (no name-based reordering, no explicit `row.names=`) is
copied verbatim from the archived `methylation_summarized_experiment.Rmd`; the bug is in
that original script, not introduced while porting it. An attempt to reproduce the exact
historical `extdata/se_lab_tcga.rds` (git `1e84178`) byte-for-byte using today's
`manifest.rds` did **not** succeed — the affected-sample identities differ from what a
naive comparison against the frozen historical file suggested (see "Correction" below).
This is expected: `manifest.rds` has itself been revised since `1e84178` was committed,
including by the SNP genotype-concordance work (`SNP_CONCORDANCE_PROVENANCE.md`), which
relabeled/excluded samples in exactly the numeric ID range (`CGOV462–488`) this bug
affects. Reproducing the *exact* historical manifest snapshot was judged not worth pursuing
— it would resurrect a since-corrected, known-stale state, not aid verification.

### Downstream consequences

- 12 of the 27 "additional JHU" samples (`CGOV463N, 465N, 466N, 467N, 469N, 473N, 478N,
  479N, 481N, 484N, 487N, 488N`) are independently excluded from the published
  `manifest`/`methylation_se` already, via the unrelated `discordant_tumor_type` QC step
  (WGS/WES SNP `genotype_id` concordance check). This bug has no additional consequence for
  those 12 — they're already absent from published data.
- The remaining 15 (`CGOV166N, 167N, 169N, 462N, 464N, 468N, 470N, 471N, 472N, 474N, 475N,
  477N, 480N, 485N, 486N`) **are** present in the shipped
  `ovarian.subtypes/data/methylation_se.rda` and hold another patient's normal-tissue
  methylation profile under their label.
- No currently-rendered figure or in-text manuscript statistic is affected:
  - Every manuscript-pipeline consumer of `methylation_se`'s JHU columns
    (`filter_lda_samples()`, feeding Figure 6's LDA panels and heatmaps) calls it with the
    default `jhu_tumor_only = TRUE`, so JHU Normal columns — including all 15 affected
    ones — are filtered out before any figure is built.
  - The in-text methylation ANOVA/Wilcoxon statistics (`Fstat`, `Fstat.p`, `minp` via
    `prop_methylated_anova()`) are computed from a `propmeth` table
    (`output/ext-figures/ext-figure9.Rmd/prop_methylated.rds`) keyed directly to sample-sheet
    metadata, not from `methylation_se`'s assay matrix — this argument is structurally
    independent of which/how many samples are affected, so it still holds under the
    corrected count.
- Latent risk: the package ships `pairedMeth()`/`tumor_normal_matrix()` and
  `filter_lda_samples(..., jhu_tumor_only = FALSE)` specifically to support patient-matched
  tumor/normal comparisons. Any such analysis — now or in future work — using
  `methylation_se` for these 15 patients would silently substitute the wrong normal
  reference.
- Circumstantial cross-reference, not established as causal: `analysis/ext-figure9.Rmd`
  contains a pre-existing author note that **CGOV486T** is an outlier in the Figure 6
  mucinous LDA classification. CGOV486 is one of the patients whose *Normal* sample we found
  mislabeled here; the Tumor sample (486T) is not part of this specific swap and Figure 6
  excludes Normals by default, so this bug does not explain that outlier — but the same
  patient appearing twice under independent scrutiny is worth a second look.

### Verification (2026-07-04)

`make targets` completed (48 targets completed, 110 skipped) followed by `make verify`:
all 35 manuscript values, 25 figure PNG hashes, and 9 table hashes match baseline exactly,
confirming the fix has no effect on any published manuscript output.

### Correction to affected-sample count (2026-07-04, later same day)

The counts above (27 mislabeled / 12 dropped / 15 published) **replace** an earlier
same-day account of this change that said 13 mislabeled / 6 dropped / 7 published, with a
different (partially overlapping) sample list centered on `CGOV477–488`.

The original count came from comparing the corrected code's output directly against the
frozen historical `extdata/se_lab_tcga.rds` file — which conflates **two** simultaneous
differences: the code fix itself, and a change in which `manifest.rds` snapshot feeds the
function (the corrected pipeline deliberately switched from the public package `manifest`
to the raw `inst/extdata/manifest.rds`, to include 12 WGS-only Normal samples the public
manifest lacks — an unrelated, intentional change). That comparison could not isolate which
difference caused which part of the observed swap.

The corrected count comes from a controlled, dedicated `targets` pipeline
(`OsMethExpData/data-raw/change002_delta_targets.R`, run via `tar_make(callr_function =
NULL)` with a fixed package-attach order) that holds every input — including
`manifest.rds` — identical between a reconstruction of the pre-fix logic and the current
corrected code, varying **only** the one code difference. Under that isolation, the bug
turns out to mislabel **all 27** of the "additional JHU" samples, not a 13-sample subset —
every one of them, regardless of which manifest snapshot is fed in, since the positional
assignment never aligns with physical column order at any row. Building this comparison as
a `targets` pipeline (rather than ad hoc REPL scripts) was itself necessary: an earlier
attempt via one-off scripts hit non-deterministic `SummarizedExperiment::colData<-`
behavior across runs with ostensibly identical code, traced to inconsistent package-load
ordering — not reproducible enough to trust for a documentation correction. See
`provenance/methylation_provenance_verification_plan.md`, "Verification safeguards," for the
full methodology this correction is built on.

---

## Change 003 — Trellis Tier-2a reproduction: from-BAM pipeline now runs end-to-end and reproduces the published `inst/extdata` within a documented tolerance

**Status:** COMPLETE (2026-07-14). The Tier-2a pipeline
(`OsSeqExpData/data-raw/_targets.R`) now runs end-to-end from BAMs for all 54 WGS
samples and reproduces the published `inst/extdata` trellis objects for ~50/54
samples exactly (deletion/amplicon/fusion call sets), with a small set of
documented deviations attributable to inherent FACETS non-determinism (see
"Reproduction outcome" below). **The shipped `inst/extdata` objects are UNCHANGED**
— per the Tier-2a goal, the from-BAM run *verifies* the published objects rather
than replacing them, so no manuscript figure, table, or `\Sexpr{}` value changes.
The stale-GRanges crash below (the original scope of this entry) was one of ~14
pipeline fragilities resolved to get there; the full catalog is in
`code/facets-trellis/TRELLIS_FRAGILITY.md`.

**Date found:** 2026-07-09 (surfaced while investigating a `tar_make()` run that appeared
to newly fail on most `trellis_*` targets)
**Affects:** `trellis_<lab_id>` targets (`OsSeqExpData/data-raw/_targets.R`) for any sample
with a real detected amplification (i.e. `sv_amplicons2()` is actually invoked, not the
empty-`AmpliconGraph()` fallback) whose `.temp/<lab_id>/_amplicons.rds` checkpoint had not
yet successfully cached. Ultimately affects `extfig47_circos_grobs.rds` reproduction for
those samples, since `trellis` output feeds that published object.
**Manuscript text/figures affected:** Not yet determined — this is an infrastructure bug in
the *reproduction* pipeline (Tier 2a rebuilding trellis output from BAMs), not a change to
the already-published `inst/extdata` baseline. Relevant once Tier-2a reproduction is
compared against that baseline.

### What changed / root cause

`code/facets-trellis/run_trellis_pipeline.R`'s `read_or_compute()` helper checkpoints every
intermediate step to `.temp/<lab_id>/*.rds` via a plain `saveRDS()` call. `BiocGenerics`
(attached transitively via `GenomicRanges`/`GenomicAlignments`, which the pipeline always
loads) overrides base `saveRDS()` with a version that first calls
`containsOutOfMemoryData(object)`, recursively walking every slot of the object being saved.

The amplicon-calling step (`sv_amplicons2()`, only reached when a sample has a real
high-gain segment) builds an `AmpliconGraph` whose `germline_cnv`/`outliers` slots are
populated from `trellis::ampliconFilters("hg18")` →
`data("germline_filters", package = "svfilters.hg18")` — a `GRanges` object **bundled as
static package data**, serialized under `GenomicRanges < 1.31.16` (confirmed via
`updateObject()`'s own diagnostic message). That old representation is missing the
`elementType` slot that current `GenomicRanges`/`S4Vectors` formally declare, so the
recursive walk crashes with:

```
Error in evaluating the argument 'object' in selecting a method for function
'containsOutOfMemoryData': no slot of name "elementType" for this object of class "GRanges"
```

before the checkpoint file is ever written — so the failure recurs on every retry for the
same sample. A systematic scan found this same staleness in effectively every plain
`GRanges` object bundled in `svfilters.hg18` (11 files) and `svfilters.hg19` (8 files), not
just `germline_filters`; `GRangesList`-typed data was unaffected.

### Evidence this predates 2026-07-09 (not a new regression)

Two archived logs from the weekend already show the identical error:
`OsSeqExpData/data-raw/logs/archive/slurm-33930033.out` (2026-07-06: 27 targets errored) and
`slurm-33936619.out` (2026-07-07: 87 targets errored) — both terminating in the same fatal
`crew` worker-crash halt (`crashed 4 consecutive time(s)`) once one specific sample's
amplicon step hit it repeatedly. The bug was not noticed at the time because (a) a crashed
`tar_make()` still leaves `targets`' cache of already-completed work intact, so each
resubmission made incremental visible progress before hitting the same wall on the next
unblocked sample, and (b) earlier blockers (the corrupt CGOV486T/CGOV488 BAMs, the
`>2000`-segment `stop()` later changed to `warning()`) meant fewer samples had even reached
the amplicon step yet on those earlier runs. The error count grew (27 → 87 → most of the
remaining un-cached targets on 2026-07-09) as those other blockers were cleared and more
samples reached the amplicon-calling code path for the first time.

### Fix

Re-serialized every affected `.rda` object in both packages with Bioconductor's own
`updateObject()` (the standard tool for exactly this class of stale-S4-representation
issue). Confirmed by direct field-by-field comparison that genomic content
(seqnames/ranges/strand/metadata) is byte-identical before and after — only the internal S4
representation changed. Pushed upstream:

- `cancer-genomics/svfilters.hg18` `1b1d0d5` (0.0.18 → 0.0.19): 11 `.rda` files fixed;
  `GenomicRanges (>= 1.31.16)` pinned in `Depends`.
- `cancer-genomics/svfilters.hg19` `183447c` (0.0.24 → 0.0.25): 8 `.rda` files fixed; same
  `GenomicRanges` pin.
- `cancer-genomics/trellis` `21d4b38` (1.0.4 → 1.0.5): `GenomicRanges (>= 1.31.16)` pinned;
  `svfilters.hg18 (>= 0.0.19)` / `svfilters.hg19 (>= 0.0.25)` pinned in `Suggests`.

`OsSeqExpData/data-raw/install_deps.R` intentionally installs GitHub packages only "if
missing" (so routine runs stay fast) — this does **not** auto-upgrade already-installed
copies. The cluster's stale copies were force-reinstalled once via a standalone script
(`force_reinstall_trellis_deps.R`/`.sh`), not by changing `install_deps.R`'s default
behavior; any new/future environment gets the fixed versions automatically since GitHub
`master` is fixed for good.

### Verification (2026-07-09)

Reproduced the exact crash locally (`OsSeqExpData/data-raw/repro_amplicons_cgov160t.R`,
using `CGOV160T`'s cached `_cnv_pdata.rds`/`_segs.rds` pulled from the cluster — no BAMs or
cluster access needed) with the pre-fix package versions, confirmed the fix resolves it
end-to-end (`sv_amplicons2()` → `saveRDS()` succeeds; all `AmpliconGraph` slots pass
`containsOutOfMemoryData()`) after reinstalling the fixed versions locally via `renv`.
Cluster packages force-reinstalled (`trellis` 1.0.5, `svfilters.hg18` 0.0.19 confirmed via
`packageVersion()`); a full rerun of the previously-failed `trellis_*` targets was submitted
same day.

### Reproduction outcome (2026-07-14)

Completing the end-to-end reproduction surfaced ~14 further pipeline fragilities
(cataloged in `TRELLIS_FRAGILITY.md`); the load-bearing fixes:

- **trellis 1.0.6/1.0.7/1.0.8** — guards for empty/degenerate BLAT input
  (header-only/0-row PSL, reversed/NA coords, 0-length inversions, and the 0-row
  `annotateBlatRecords()` `1:nrow` crash).
- **svplots 0.0.16** — `circosTracks()` anchors tracks to the standard autosomes+X
  instead of a possibly-empty deletions track (empty-deletion samples no longer
  crash the circos build).
- **`run_trellis_pipeline.R`** — (a) skip CNV/SV calling above 2000 segments,
  reproducing the original's behavior for hypersegmented samples (CGOV365T,
  CGOV127T_2, CGOV131T, CGOV141T_1 → segments-only, matching their empty published
  tables, and CGOV365T now terminates instead of running >48 h); (b) regenerate a
  0-byte (failed-BLAT) PSL instead of caching it; (c) compute `acn` fresh from the
  current purity every run instead of baking it into `_segs.rds` (a stale `acn=NA`
  from pre-FACETS segmentation had silently zeroed ~15 samples' deletion/amplicon
  calls).
- **`run_facets.R` — `set.seed(123)`** (Change: see below).

**Concordance vs published `inst/extdata` (per-sample call counts):** deletions
reproduce for all samples (exact or ±1–3); amplicons and (post-filter) fusions
reproduce for ~50/54. Remaining deviations, all documented and accepted as the
reproduction *tolerance*, not shipped changes:

- **CGOV140T, CGOV358T** — FACETS two-solution (purity/ploidy) ambiguity. FACETS'
  `procSample()` CBS segmentation uses Monte-Carlo p-values, so `emcncf()` can
  settle on either of two alternative solutions depending on the RNG; the original
  `get-cnv-calls.R` set no seed, so its published values were an uncontrolled draw
  (skoul's own `verify_facets_purity_ploidy_w_prev_run.R` shows his/Dan's/Leo's
  runs disagreed). Our seeded run lands on the alternative solution for these two,
  changing their amplicon counts (e.g. CGOV140T 18 vs 110). We now `set.seed(123)`
  in `run_facets()` for reproducibility going forward; matching the original's
  exact historical draw is not achievable and is accepted as inherent FACETS
  non-determinism.
- **CGOV488T** — amplicon over-call (34 vs 0) with *matching* purity/ploidy.
  **Resolved 2026-07-16** — root cause was the pre-restage corrupt tumor BAM, not
  a calling discrepancy; recomputing from the restaged, md5-verified BAM yields 0
  amplicons, matching published. See "CGOV488T amplicon over-call resolved" below.

**Shipped data unchanged:** the published `inst/extdata` grob/table objects and
their `extdata_hashes_baseline.rds` integrity baseline are retained as-is; the
regenerated objects are reproduction evidence only. `Rscript tests/verify_snapshot.R`
and the `OsSeqExpData` `testthat` integrity suite therefore continue to pass
against the unchanged published objects.

### CGOV488T amplicon over-call resolved (2026-07-16)

The remaining CGOV488T amplicon deviation (34 called vs 0 published) was **not** a
calling discrepancy — it was a stale-cache artifact of the pre-restage **corrupt
tumor BAM**. The entire per-sample cache chain (`bins` → `improper_rp` → `bins_norm`
→ `segs` → CNV/amplicon calls) had been built from the corrupt BAM before the BAM
was restaged, and was never invalidated, so the spurious amplicons persisted through
every subsequent partial run.

`OsSeqExpData/data-raw/recompute_486_488.sh` cleared the whole chain
(`snp_matrix`, `facets_metrics`, `trellis_output/.temp/`) for CGOV486T and CGOV488T
and rebuilt end-to-end from the restaged, md5-verified intact BAMs (SLURM job
**34128883**, completed 2026-07-16, ~29.5 h: re-extract improper read pairs from the
~85 GB BAMs + re-run BLAT, then FACETS + trellis + downstream `trellis_wgs`/
`extfig47_data`/`pkg_data`).

**Outcome — CGOV488T amplicons: 34 → 0**, matching published. Confirmed by direct
inspection of the recomputed `AmpliconGraph` (`CGOV488T_amplicons.rds`): the graph
is empty (0 ranges, 0 amplified-segment query, 0 nodes, 0 edges). FACETS
purity/ploidy were already matching, consistent with the BAM — not FACETS RNG —
being the cause.

The amplicon result was corroborated by `debug_counts.R` run against the rebuilt
`trellis_wgs` target (SLURM job **34182850**, 2026-07-16), which reports per-sample
deletion/amplicon/fusion counts vs the published `inst/extdata` tables:

| sample   | del | amp | fus (raw) | published del | published amp | published fus |
|----------|----:|----:|----------:|--------------:|--------------:|--------------:|
| CGOV488T |   2 |   0 |         2 |             3 |             0 |             0 |
| CGOV486T |  47 |   0 |        28 |            46 |             0 |             0 |

- **Amplicons — 0 for both, matching published.** This is the resolution: the
  CGOV488T over-call is gone.
- **Deletions — CGOV488T 2 vs 3, CGOV486T 47 vs 46**, each off by one and within
  the documented "exact or ±1–3" deletion tolerance (minor CBS/BLAT non-determinism).
- **Fusions — not a discrepancy.** The `fus` column is `debug_counts.R`'s *raw
  pre-filter* rearrangement count (`nrow`), not the published *post-filter* fusion
  set; cohort-wide it diverges from the published counts in both directions. For
  CGOV488T the final filtered fusion object (`CGOV488T_fusions.rds`) is empty (0
  rows), matching published 0. Post-filter fusion concordance is tracked separately
  (`fusion_concordance.R`) and is unaffected by this recompute.

With CGOV488T resolved, it is no longer a special case: it folds into the general
"~50/54" amplicon/fusion reproduction already documented above. The material
remaining amplicon deviations are the **FACETS two-solution RNG** cases — most
prominently **CGOV140T** (18 vs 110) and **CGOV358T** (20 vs 52), whose published
values were an uncontrolled unseeded draw (see above) — alongside a few small
residuals near the documented ±-tolerance (e.g. CGOV142T, CGOV481T). None involve a
corrupt-BAM or stale-cache artifact of the kind fixed here.

**Shipped data still unchanged:** this recompute only improves the from-BAM
reproduction concordance (Option A); it does not touch the published `inst/extdata`
objects or their integrity baseline, so no manuscript figure/table/`\Sexpr{}` value
changes and `Rscript tests/verify_snapshot.R` is unaffected.

### Batched 54-sample rebuild after `step_seed()`, trellis 1.0.9, and the vendored-pileup default (card `SEQ-09`, 2026-08-01)

Three landed changes each invalidated every per-sample WGS target — the `step_seed()`
seeding fix in `bin_counts()` (binning arm only), the trellis 1.0.9 bump, and
`run_snp_pileup()`'s default flipping to the vendored script. This is the one rebuild
that spent all three at once (SLURM jobs `34491256` FAILED, `34523320` completed but
did not exercise the reseeded binning arm due to a `_targets` metadata desync
(`SEQ-22`/`SEQ-23`), `34537166` the resubmit that finally did). Full job history in
`cards/JOBS.md`; per-run diagnosis in `SEQ-09`'s own Notes.

**Outcome: reproduces within the same tolerance already documented above, restricted
to the 54 authoritative WGS tumors (`ovarian.subtypes::manifest`, `platform == "WGS"
& tumor.normal == "tumor"` — `inst/extdata/wgs-summary-stats.txt` itself still carries
13 extra pre-concordance/superseded rows, e.g. `CGOV359T`, not part of this cohort;
excluded from all counts below):**

| Metric | Exact match | Residual |
|---|---|---|
| Fusions | 54/54 | — |
| Amplicons | 44/54 | All 10 already covered by the FACETS two-solution cases above (`CGOV140T`, `CGOV358T`) or the small-residual bucket (`CGOV142T`, `CGOV481T`), plus trivial ±1 noise on 6 samples |
| Deletions | 39/54 | Within the documented ±1–3 tolerance except `CGOV138T` (+8) and `CGOV139T_1` (−4), slightly over — Monte-Carlo CBS/BLAT noise, not a corrupt-BAM/stale-cache signature like `CGOV488T` had |
| Purity/ploidy | median diff 0 | Only `CGOV358T` crosses into alternate-FACETS-solution territory (already known) |

**One new minor case: `CGOV466T` now returns `NA` purity** ("insufficient information
to estimate purity"), joining `CGOV142T` in the same already-documented FACETS
low-confidence-flag bucket (the mechanism already published for `CGOV131T`) — not a
new failure mode.

**`extfig47_amplicon_grobs.rds`'s knowingly-red `test-data-integrity.R` assertion**
(`tests/CLAUDE.md`) is not a digest/serialization artifact — confirmed the object
hashes identically across repeated fresh R sessions for the same file — it is a real
(small) content difference driven by exactly this tolerance: any one differing
amplicon call anywhere in the 54-sample list changes the whole object's hash. The
baseline was almost certainly captured from a different historical FACETS run than
what is currently committed, for the same reason. **Left as knowingly-red, baseline
not touched** — per `tests/CLAUDE.md`'s rule against updating a baseline just to make
a red assertion green.

**Shipped data unchanged:** as with the rest of this Change, `inst/extdata` and its
integrity baselines are untouched; this rebuild is from-BAM reproduction evidence
only (Option A). `Rscript tests/verify_snapshot.R` is unaffected.

---

## Change 004 — Trellis Track C: ext-figure 8 rearrangement count drift (CGOV161T/172T/173T) accepted as reproduction tolerance

**Date:** 2026-07-22 (Track C W1 verification)  
**Affects:** ext-figure 8 only (rearrangement/fusion circos panel)  
**Manuscript text affected:** None — these samples have no `\Sexpr{}` anchor; their only
manuscript-fidelity reference is the baselined ext-figure 8 PNG, which is unchanged.

### What was observed

A 2026-07-16 Track C from-BAM run of the decomposed WGS trellis pipeline
(`OsSeqExpData/data-raw/_targets.R`, W1) produced a strict *subset* of the published
rearrangements for exactly the three ext-figure 8 samples:

| Sample | Published | This run | Lost | Added |
|---|---:|---:|---:|---:|
| CGOV161T | 265 | 246 | 19 | 0 |
| CGOV172T | 111 | 107 | 4 | 0 |
| CGOV173T | 22 | 21 | 1 | 0 |

(7%/4%/5% loss respectively, consistent in direction — losses only, no additions — across
all three samples.)

### Disposition

**Accepted as documented reproduction tolerance, not investigated further (Rob, 2026-07-22).**
Two candidate mechanisms were identified but **neither was distinguished by a targeted
rerun**:

- an incomplete-run artifact — a stale pre-2026-07-12 0-byte-PSL BLAT checkpoint left in
  scratch (the same failure mode as `TRELLIS_FRAGILITY.md` observed failure #10, documented
  for CGOV161T specifically) surviving into the 07-16 run, or
- `TRELLIS_FRAGILITY.md` theme #7 — `getSequenceOfReads(..., MAX=25)`'s unseeded
  `sample(seq_len(25), 25)` inside `trellis`, reordering which reads reach BLAT independent
  of any artifact.

An investigation plan to distinguish these (determinism rerun, per-stage `message()` count
capture, re-render against the baselined PNG) was drafted in
`code/facets-trellis/TRACK_C_REFACTOR_PLAN.md` §"First validation case" but **was not run**.
Rob reviewed the magnitude and shape of the drift directly and judged it consistent with the
RNG/version non-determinism already documented and accepted elsewhere in this pipeline
(theme #7 above; theme #13 / CGOV140T / CGOV358T's FACETS two-solution ambiguity, this same
Change log's Change 003) rather than a functional regression — the same class of tolerance,
not a new finding.

This is recorded here **for completeness of the deviation log**, per this file's own
standard ("track every deviation... whether the scientific conclusion is affected"), even
though — unlike Changes 001–003 — no root-cause fix or reproduction step was performed. See
`TRELLIS_FRAGILITY.md` observed failure #17 for the corresponding fragility-catalog entry.

**Shipped data unchanged:** the published `inst/extdata` `extfig8_rlist.rds` and its
baseline are retained as-is; the from-BAM run is reproduction evidence only, and
`Rscript tests/verify_snapshot.R` continues to pass against the unchanged published object.

---

## Change 005 — Methylation provenance registry: repointed `methylation_se` off the retiring base-package copy

**Date:** 2026-07-28 (card `GATE-02`)  
**Affects:** `tests/save_methylation_registry.R`, `tests/snapshots/methylation_provenance_registry.rds`  
**Manuscript text affected:** None — no manuscript number, figure, or table depends on this
registry; it is a pre-flight gate for the `OsMethExpData/data-raw` pipeline
(`run_targets.sh:67` via `tests/verify_methylation_registry.R`).

### What changed

`REGISTRY_FILES`'s `methylation_se` entry moved from
`ovarian.subtypes/data/methylation_se.rda` to `OsMethExpData/inst/extdata/methylation_se.rds`,
ahead of card `BASE-03` deleting the base-package copy. Card `MET-02a` had already placed a
byte-for-byte `identical()`-confirmed copy at the new path; this card re-confirmed the
`identical()` check still held on 2026-07-28, then repointed the registry and regenerated
`tests/snapshots/methylation_provenance_registry.rds` (new MD5
`de7854f0232c9ac572f1053a83e89565` for the `methylation_se` entry, same bytes as the
retiring `.rda` — a path change, not a data change).

**Shipped data unchanged:** no `.rda`/`.rds` object's bytes changed, only which path the
registry checks. `Rscript tests/verify_methylation_registry.R` reports all 5 files matching
against the new baseline.

---

## Change 006 — Base package: retired its own `methylation_se` test section ahead of `BASE-03`

**Date:** 2026-07-29 (card `BASE-05`)  
**Affects:** `ovarian.subtypes/tests/testthat/test-data-integrity.R`  
**Manuscript text affected:** None — this is package test coverage, not a manuscript
number, figure, or table.

### What changed

Removed the `# ── methylation_se (SummarizedExperiment) ──` section (4 `test_that` blocks)
from `ovarian.subtypes/tests/testthat/test-data-integrity.R`. These tests called
`data(methylation_se, package = "ovarian.subtypes")` directly against the base-package copy
that card `BASE-03` is retiring. Equivalent coverage — existence, structure, no-PHI
colData, JHU/TCGA composition, CG-identifier naming, and a SHA-256 hash baseline — already
exists in `OsMethExpData/tests/testthat/test-accessors.R`, added under card `MET-02a`
specifically to anticipate this handoff.

This card was opened after `BASE-03` attempted its removal Do steps, hit a red
`devtools::test("ovarian.subtypes")` from exactly this section, and reverted its own edits
rather than proceed with a broken gate.

**Shipped data unchanged:** no `.rda` object's bytes changed; only a redundant test section
was removed. `devtools::test("ovarian.subtypes")` now reports 0 failures (one `SKIP` for
`deconstructSigs`, unrelated) and `Rscript tests/verify_snapshot.R` remains 35/25/9 green.

---

## Change 007 — Cross-platform figure-hash policy, and a systemic `.rmd`/`.Rmd` case-mismatch bug fixed across the whole repo

**Date:** 2026-08-01 (card `GATE-03`)

### Figure-hash policy

`REL-06`'s CI run (2026-07-31) was the first time `wflow_build()` and `tar_make()` both
completed and `verify_snapshot.R` ran to completion in this repo's CI history. It found
21 of 25 figure PNGs hash-differing from the Mac-authored baseline, while all 35
manuscript values and all 9 tables matched exactly — cross-platform font/anti-aliasing/DPI
rendering differences, not a content regression, but nothing had ever decided how
`verify_snapshot.R` should treat that split.

Tested a perceptual/structural-diff tolerance (`magick::image_compare_dist()`, several
metrics) against the real Linux-rendered PNGs before picking a policy, rather than assume
it would work: a synthetic real content change (a solid rectangle covering ~2% of a
figure) produced a smaller MAE/RMSE and a smaller PHASH distance than several of the
*benign* cross-platform pairs already showed. The noise floor from dense scientific
figures (thin lines, small text, wide margins) is comparable to or larger than what an
actual regression would move — no tested metric/threshold safely separated the two
cases. **Decision (Rob): adopt the Linux CI baseline.** `tests/snapshots/figure_hashes.rds`
regenerated from CI run 30695856652's rendered output for the 21 figures that differ; the
other 4 (skip-listed/ImageMagick-conditional Rmds, never rebuilt in CI) keep their
original Mac hash. `verify_snapshot.R`'s figure check is now CI-authoritative — a local
Mac run is expected to show all 25 as CHANGED going forward.

Also fixed the 7 "MISSING" entries `verify_snapshot.R` reported every run: 4 of the figure
PNGs are genuinely never produced in CI (private-data/live-API-skipped Rmds, or an
ImageMagick-conditional chunk) are now excluded from the missing-file check by name
(`verify_snapshot.R`'s `CI_SKIPPED_RMD_STEMS`, kept in sync with `check.yml`'s own
`skip <- c(...)` by comment); the other 3 (table_s2/s4/s5's table files) turned out to
have a different, more consequential root cause — see below — and are no longer missing
at all once that's fixed.

### The `.rmd`/`.Rmd` case-mismatch bug (systemic, not isolated)

Investigating the 3 "missing" table files found the real cause: every `analysis/*.Rmd`
source is tracked with a capital `R` (`table_s6.Rmd`, confirmed via `git ls-tree`), but
`tests/snapshots/artifact_baseline.rds` stored 8 of 9 table-file keys as lowercase
`table_sN.rmd`, and — far more consequentially — **all nine `analysis/table_s*.Rmd`
files hardcoded their own `outdir` using the lowercase form**
(`here("docs", "table", "table_s6.rmd")`), diverging from the capital-R directory
`_targets.R`'s `amp_file`/`wes_cnv_file`/`del_file`/`s3file`/`s4file` targets actually read
(and that `MAN-04` had just re-tracked). Every `wflow_build()` run — including Rob's own
local ones — has been silently writing table_s6/s7/s8's fresh output into an untracked,
gitignored shadow directory that nothing downstream ever reads, rather than refreshing the
tracked file `_targets.R` depends on. macOS's case-insensitive filesystem made this
invisible locally; it only ever surfaced as a hard Linux CI failure for the *skip-listed*
Rmds (table_s2/s4/s5), which have no fresh build to coincidentally paper over the
mismatch. This is the same class of bug `b1b796a` already fixed once for
`ext-figure1.Rmd`'s downstream reads — it turned out to be systemic, not a one-off.

Rob: "we've run into this issue a hundred times now and it needs to be fixed once and for
all." Fixed comprehensively rather than patched at the one site that happened to be
visible:

- All nine `analysis/table_s{1..9}.Rmd` `outdir` lines: lowercase → capital `.Rmd`.
- `analysis/figure2.Rmd`/`figure4.Rmd`'s dead-code (`eval = FALSE`) `table_s5/6/7`
  references: fixed for consistency even though currently inert.
- `analysis/index.Rmd`: 5 broken/miscased links to `ext-figure4-7/9/10/11.Rmd`.
- `.gitignore`: `table_s1.rmd`/`table_s9.rmd`/`figure1.rmd` (×3)/`figure5.rmd` (×2) →
  capital `.Rmd`. (`output/*.rmd` entries deliberately left alone — confirmed these
  correspond to retired pre-refactor `code/archive/*.rmd` generators that are genuinely
  lowercase-named, a different, dead pipeline convention, not this bug.)
- `tests/snapshots/artifact_baseline.rds`: all 8 lowercase table-file keys renamed to
  capital `.Rmd`, then verified every one of the 9 table entries' hash now matches the
  currently-committed file exactly.
- **New guard, wired into the universal gate**: `tests/verify_rmd_case.R` fails loudly if
  any tracked R/Rmd source (or `.gitignore`) ever again references a lowercase `.rmd` path
  for a source actually tracked with a capital `R`. Added to `make verify` and as its own
  CI step. Validated by deliberately re-introducing the bug and confirming the check
  failed before trusting it — an earlier, simpler version of the regex silently caught
  nothing, because R code builds these paths via `here("docs", "table", "table_s6.rmd")`
  (separate quoted arguments), never as one literal `"docs/table/table_s6.rmd"` string.

**Shipped data unchanged by the case fixes themselves:** correcting where *future*
`wflow_build()` runs write does not retroactively alter any already-committed file; no
manuscript figure/table/`\Sexpr{}` value moves. Whether the already-committed
`table_s6/7/8.Rmd` tables have themselves drifted from what current `wflow_build()` output
would produce (now that it will actually reach them) is a separate, not-yet-investigated
question, flagged as a follow-up rather than assumed either way.

---

## Change 008 — Package rename: `ovarian.subtypes`/`OsSeqExpData`/`OsMethExpData` → `hallberg2025.*`

**Date:** 2026-08-03 (cards `BASE-06`, `SEQ-24`, `MET-10`, and the `DOC`/`ENV`/`GIT`/`REL`
follow-up cards that repointed references to them)
**Affects:** Repository/package naming only — `ovarian.subtypes` → `hallberg2025.base`,
`OsSeqExpData` → `hallberg2025.seq.data`, `OsMethExpData` → `hallberg2025.meth.data` (the
last of the three renamed private, not public — its visibility flip is a separate,
still-open decision)
**Manuscript text affected:** None — this is a repository/package-identity rename with no
change to any computed value, figure, or table.

### What changed

All three R packages in this project's module set were renamed to a consistent
`hallberg2025.*` naming scheme ahead of the outer `hallberg2025` repo going public: the
shared base package, the sequencing companion data package, and the methylation companion
data package. Each rename covered the package's own `DESCRIPTION`/self-references, its
GitHub repository, the outer repo's directory name and git index entry, `renv`/`uvr`
lockfile entries, `_targets.R`/manuscript-Rmd references, install/build/CI scripts, and
this repo's own `cards/`, `CLAUDE.md`, and provenance/plan documentation.

**Root cause:** not a defect — a deliberate, planned repository-maintenance step (the
`hallberg2025.*` package rename initiative) undertaken to give the three packages names
consistent with the outer `hallberg2025` repo before its public release, rather than the
legacy `ovarian.subtypes`/`OsSeqExpData`/`OsMethExpData` names carried over from the
project's pre-publication history. No computation, figure, table, or manuscript
`\Sexpr{}` value is produced differently under the new names; `Rscript
tests/verify_snapshot.R` remained 35/25/9 green throughout.

---

## Change 009 — Figure-hash baseline: one entry updated for the container-based CI environment

**Date:** 2026-08-04 (card `REL-16`)

`REL-16` switched `check.yml`'s `check` job to run inside the published `manuscript`
Docker image (`ENV-14`/`ENV-15`) instead of a bare `ubuntu-24.04` GitHub-hosted runner
provisioned from scratch each run. `Change 007` (`GATE-03`) already established that
`tests/snapshots/figure_hashes.rds` is Linux-CI-authoritative — regenerated from whatever
environment `check.yml` actually renders in — precisely so this kind of environment
change has a defined procedure rather than an ad hoc one.

The first live run of `check.yml` inside the container (CI run `30954775048`) came back
24 of 25 figure PNGs unchanged and one, `docs/figure/ext-figure10.Rmd/heatmaps-1.png`,
hash-differing from the `GATE-03` baseline (`0d0044ef7e6657ba28a1d885f9f116f7` →
`b17be8fb280425b989b5f2d064e49997`). Not a fresh finding: `ENV-15`'s own local-docker
validation of this exact image already surfaced this figure (plus `figure3.2`, which
happens to match in this run) drifting for the identical reason — `ComplexHeatmap`'s row/
column text-label rendering is sensitive to font/anti-aliasing differences between the
old bare-runner environment and this container's — and Rob already accepted it as a
documented residual, not a correctness issue, at that time.

Updated only the one changed entry in `tests/snapshots/figure_hashes.rds` (the other 24
baseline hashes are untouched) using the exact hash `verify_snapshot.R`'s own CI run
reported, so the new baseline is provably what that run actually produced, not a
separately-regenerated guess. All 35 manuscript values and all 9 table hashes were
unaffected throughout (matched on the very first container-based run with no changes
needed).

**Root cause:** benign font/anti-aliasing rendering difference between two Linux
environments (the container image vs. the previous bare GitHub Actions runner), already
investigated and accepted by Rob during `ENV-15`. No manuscript figure, table, or
`\Sexpr{}` value is affected; the heatmap's actual data/labels are unchanged, only
sub-pixel text rendering.

---

## Change 010 — Mutational-signature matrices: producer restored, but `endosigs`/`mucsigs` kept as frozen 2025 artifacts

**Date:** 2026-08-31 (card `BASE-02`)
**Affects:** Nothing shipped. `extdata/endosigs.rds` and `extdata/mucsigs.rds` are
unchanged, and `analysis/ext-figure3.Rmd` still renders from them.
**Manuscript text affected:** None — the signature matrices feed only Extended Data
Figure 3, not any `\Sexpr{}` target.

### What changed

`BASE-02` closed a reproducibility hole: the mutational-signature computation existed only
as prose in an archived 2019 script, so `extdata/{endosigs,mucsigs}.rds` were frozen leaves
with no producer in this repository. There is now a producer —
`hallberg2025.base::{parse_mutation_coords, signature_input_table,
fit_mutational_signatures, endo_signature_matrix, muc_signature_matrix}`, wired as
`endosigs`/`mucsigs` targets in `hallberg2025.base/_targets.R`, with `deconstructSigs`
pinned in `uvr.toml`/`uvr.lock` to the CRAN GitHub mirror at the `1.8.0` tag by exact SHA
(the package is archived on CRAN, so the ordinary CRAN path cannot resolve it).

**The regenerated matrices do not reproduce the committed ones**, and after review
**Rob's decision is to keep the committed 2025 files as frozen published artifacts.** The
new targets are a documented producer and a regression anchor; they are deliberately *not*
wired to overwrite `extdata/{endosigs,mucsigs}.rds`.

| | committed | regenerated | shared columns | shared block |
|---|---|---|---|---|
| `endosigs` | 24 × 50 | 22 × 63 | 49 | max abs diff 0.364; 24 of 49 columns differ |
| `mucsigs` | 26 × 65 | 21 × 75 | 62 | max abs diff 1.000; 30 of 62 columns differ |

### Root cause — the input table, not the port

Not a defect in either the committed files or the new code. Three independent checks
localize the difference to the *input mutation calls*:

1. **The coordinates in `extdata/mutations.tsv` really are hg18**, as
   `code/mutations.rmd` claims. That file carries a caller-written `context` column
   (11-mer, `N` at position 6 = reference base), which is an independent witness to the
   genome build. The reference trinucleotide it implies agrees with a
   `BSgenome.Hsapiens.UCSC.hg18` lookup at each coordinate on **100.00% of 37,420
   substitution rows across all 138 samples** (sole exception: 1 of CGCRC245T's 3 rows).
2. **The new port reproduces the 2019 computation bit-exactly wherever the inputs agree.**
   The archived producer's own per-sample output survives
   (`~/Dropbox/Labs/CancerGenomicsLab/Projects/Ovarian_Subtypes/archive/users-dhallber/data/{endo,muc}sigoutput.rds`),
   including each sample's fitted `$tumor` trinucleotide profile. **37 of 53 shared
   endometrioid samples match to 0.00000.** This is the real verification that the
   parsing, arm membership, `mut.to.sigs.input()` wiring and normalization are correct.
   It also shows why hg18-here vs hg19-there is a non-issue: liftOver changes coordinates,
   not the underlying sequence, so the trinucleotide context is preserved.
3. **The residual divergence tracks a different source table.** The divergent endometrioid
   samples are *exactly* the archived script's hardcoded hg19-native list (`CGOV353T`,
   `CGOV354T`, `CGOV358T`, `CGOV365T`, `CGOV369T`; the sixth, `CGOV450T`, is the one column
   present in the committed matrix and absent from the regeneration). For the mucinous arm
   a genome-build error was ruled out — refitting the whole arm as hg19-on-hg18-coordinates
   is no closer (still 0 of 66 exact, median max-abs-diff 0.195 either way) — as was the
   Strelka-rerun hypothesis, since that arm is 15,125 of 15,617 PGDx WES calls.

The committed matrices were fitted in 2019 on a mixed hg18/hg19 WES+WGS merge, lifted to
hg19, then filtered by a curated `integrated_data.e` sample list that is not
reconstructable from anything in this repository. `extdata/mutations.tsv` is a later,
deliberate re-derivation (`MAN-01`): Strelka reruns replacing failed jobs, the CGPA367T
column-shift patch, and 12 rerun samples excluded to preserve published counts. They are
not the same input, so they do not give the same signature weights, and no defensible
change to the port would reconcile them.

### Consequence

Extended Data Figure 3 remains exactly as published, and no figure, table or manuscript
value moves. The honest limitation, recorded here rather than papered over: **Extended
Data Figure 3 is not regenerable from the current pipeline.** Its inputs are preserved as
committed artifacts, and the pipeline can now produce a *documented, pinned, tested*
signature computation from today's mutation table — but the two are different
computations on different inputs and are not expected to agree.

A regression test (`hallberg2025.base/tests/testthat/test-mutation-signatures.R`) locks the
new producer to a fixed per-sample fit, anchored on `CGOV105T` — one of the 37 samples
verified bit-exact against the 2019 producer — so the baseline traces to the original
computation rather than to whatever the port happened to emit first.
