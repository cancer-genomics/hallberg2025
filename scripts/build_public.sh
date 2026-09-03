#!/usr/bin/env bash
# build_public.sh — assemble the public release from the private repo.
#
# Usage:  bash scripts/build_public.sh [DEST]
#   DEST defaults to ./public  (created fresh each run)
#
# Strategy:
#   Phase 1 — rsync the repo minus all private/PHI files and the large output/ cache.
#   Phase 2 — explicitly copy only the three pre-computed output files that
#              _targets.R reads as file-format targets.  These are safe (no PHI)
#              but were excluded with output/ above.
#   Phase 3 — PHI scan: grep for PGDX identifier values in all text files.
#
# Adding a new private file will NOT automatically exclude it.  Add an
# explicit --exclude line in Phase 1, or leave it in output/ (which is
# excluded wholesale).

set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$SRC/public}"

echo "Building public release:"
echo "  SRC  = $SRC"
echo "  DEST = $DEST"
echo ""
rm -rf "$DEST"
mkdir -p "$DEST"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 — rsync with exclusions
# ─────────────────────────────────────────────────────────────────────────────
rsync -a \
  \
  `# ── PHI raw inputs (NEVER publish) ───────────────────────────────────────` \
  --exclude="hallberg2025.base/inst/extdata/manifest.rds" \
  --exclude="hallberg2025.base/inst/extdata/sdat.rds" \
  --exclude="hallberg2025.base/inst/extdata/diagnosis_surgery_dates.csv" \
  --exclude="hallberg2025.base/inst/extdata/Added metadata*" \
  --exclude="hallberg2025.base/inst/extdata/facets_trellis_directories.txt" \
  \
  `# ── Private ID mapping tables ─────────────────────────────────────────────` \
  --exclude="data/id_lookup.csv" \
  --exclude="data/bam_lookup.csv" \
  --exclude="data/crosswalk_private.csv" \
  \
  `# ── PGDX-containing extdata ───────────────────────────────────────────────` \
  --exclude="extdata/combmetadata.rds" \
  --exclude="extdata/geno_concordance.txt" \
  \
  `# ── Raw mutation-report inputs. _targets.R's own comment already says these` \
  `#    are "never published" -- the public tar_make() fallback reads only the` \
  `#    frozen extdata/mutations.tsv, never these. mutation_reports/` \
  `#    pgdx-compiled.xlsx carries real PGDX identifier values in its Prefix` \
  `#    column (undetectable by the text-only PHI scanner); shipping either` \
  `#    directory was an oversight, not a deliberate choice. ─────────────────` \
  --exclude="extdata/mutation_reports/" \
  --exclude="extdata/strelka_reruns/" \
  \
  `# ── Entire output/ cache (excluded wholesale; safe subset copied in Phase 2)` \
  --exclude="output/" \
  \
  `# ── docs/table/ nested subdirs (contain raw pipeline artefacts; HTML kept) ─` \
  --exclude="docs/table/*/***" \
  \
  `# ── code/ excluded wholesale. facets-trellis/ and crosswalk/ carry PGDX` \
  `#    sample identifiers; pgdx_reports.rmd is private by name; archive/ is` \
  `#    gitignored locally (see below) but rsync doesn't consult .gitignore.` \
  `#    mutations.rmd, the one file that used to ship, is superseded by MAN-01` \
  `#    (its logic now lives in hallberg2025.base::build_mutations_tbl()/` \
  `#    consolidate_mutation_calls(), which is what _targets.R actually calls);` \
  `#    it can't even run on a public clone regardless (needs the private` \
  `#    manifest.rds), so there's nothing left in code/ worth shipping. ─────` \
  --exclude="code/" \
  \
  `# ── Internal work register.  cards/ is the private backlog: cards quote the` \
  `#    PHI they exist to remove, and JOBS.md carries cluster paths.` \
  `#    provenance/ (card DOC-04) is the evidence tree behind those cards, and` \
  `#    REFACTOR_PLAN.md is the internal work order. ─────────────────────────` \
  --exclude="cards/" \
  --exclude="provenance/" \
  --exclude="REFACTOR_PLAN.md" \
  \
  `# ── Private working notes and superseded plan drafts.  These are internal` \
  `#    session material — they name cluster paths, PGDX-era filenames, and` \
  `#    unpublished analysis intent.  REPRODUCIBILITY_PLAN.html is the rendered` \
  `#    master status document; the public tree gets neither it nor its .qmd` \
  `#    working notes. ────────────────────────────────────────────────────────` \
  --exclude="prompts.org" \
  --exclude="SESSION_NOTES_*.md" \
  --exclude="REPO_SIZE_PLAN.txt" \
  --exclude="extfig_refactor_plan.md" \
  --exclude="trellis_wgs_inputs.md" \
  --exclude="baseline_review/" \
  --exclude="figure_dependencies.txt" \
  --exclude="REPRODUCIBILITY_PLAN.html" \
  --exclude="REPRODUCIBILITY_PLAN.qmd" \
  --exclude="ENV_UVR_SPIKE.md" \
  \
  `# ── The root .Rproj -- excluded HERE BY NAME ONLY, then re-copied in PHASE 2` \
  `#    as hallberg2025.Rproj (rsync cannot rename).  DO NOT drop that copy and` \
  `#    DO NOT re-exclude the file outright as \`cruft\`: workflowr locates the` \
  `#    project with rprojroot::find_rstudio_root_file(), whose criterion is any` \
  `#    root file matching *.Rproj containing a \`Version:\` line.  With no such` \
  `#    file, wflow_build() aborts with \"Unable to detect a workflowr project\"` \
  `#    and CI fails at the analysis-page step (card REL-24).  The content is` \
  `#    inert RStudio editor settings -- the only reason to rename is that` \
  `#    2024.ovarian.subtypes is a stale internal name. ─────────────────────────` \
  --exclude="2024.ovarian.subtypes.Rproj" \
  \
  `# ── Scratch files that accumulate at the repo root ────────────────────────` \
  --exclude="temp.txt" \
  --exclude="test_write.txt" \
  --exclude="Rplots.pdf" \
  \
  `# ── Regeneratable / personal ──────────────────────────────────────────────` \
  --exclude="_targets/" \
  --exclude="renv/" \
  --exclude=".uvr/" \
  --exclude=".Rprofile" \
  --exclude=".Rhistory" \
  --exclude="org/" \
  --exclude=".#*" \
  --exclude=".claude/" \
  \
  `# ── Personal editor/environment config (meaningless to a public clone) ────` \
  --exclude=".dir-locals.el" \
  --exclude=".renvignore" \
  --exclude=".vscode/" \
  \
  `# ── Root inst/extdata/ -- an empty, untracked, accidental directory. Leading` \
  `#    slash anchors to the transfer root so hallberg2025.base/inst/extdata/,` \
  `#    which is real and must ship, is untouched. ───────────────────────────` \
  --exclude="/inst/extdata/" \
  \
  `# ── NOT excluded: /.github/workflows/check.yml. It is the PUBLIC repo's CI,` \
  `#    not a status badge -- it is what produces hallberg2025's "Pipeline` \
  `#    check" runs, and REL-09/REL-12/REL-16 exist only because it runs there.` \
  `#    REL-17 excluded it and REL-22 put it back. If any /.github/ pattern is` \
  `#    ever added here, it MUST keep the leading slash: an unanchored pattern` \
  `#    matches the basename at any depth and silently deletes` \
  `#    hallberg2025.base's own check.yml too. ─────────────────────────────────` \
  \
  `# ── manuscript/ stray staging copies and LaTeX build byproducts. abdir/` \
  `#    to_submit were reconciled and renamed manuscript/submitted/ (REL-17);` \
  `#    it and the rest of this group are local-only regardless. ────────────` \
  --exclude="manuscript/submitted/" \
  --exclude="manuscript/testing/" \
  --exclude="manuscript/broman/" \
  --exclude="manuscript/rentrez/" \
  --exclude="manuscript/~/" \
  --exclude="manuscript/composite-1.eps" \
  --exclude="manuscript/to_submit.sh" \
  --exclude="manuscript/hallberg2025.aux" \
  --exclude="manuscript/hallberg2025.bbl" \
  --exclude="manuscript/hallberg2025.blg" \
  --exclude="manuscript/hallberg2025.log" \
  --exclude="manuscript/supplemental.aux" \
  --exclude="manuscript/supplemental.log" \
  --exclude="manuscript/diff_2025-04.tex" \
  --exclude="manuscript/data_quality.Rmd" \
  --exclude="manuscript/data_quality.html" \
  \
  `# ── SLURM logs and cluster scratch files (contain PGDX BAM names) ─────────` \
  --exclude="logs/" \
  --exclude="missing_bams.txt" \
  --exclude="slurm-*.out" \
  \
  `# ── Private development notes ─────────────────────────────────────────────` \
  --exclude="CLAUDE.md" \
  --exclude="SNP_CONCORDANCE_PROVENANCE.md" \
  \
  `# ── Dev-only scripts with no public purpose. gen_card_index.R regenerates` \
  `#    cards/INDEX.md, which is itself excluded above; make_circos_placeholders.R` \
  `#    is a local dev-testing convenience for \`make check-partial\`;` \
  `#    audit_manuscript.sh reads manuscript/submitted/, which PHASE 1 excludes,` \
  `#    so it cannot run on a public clone; bioc_install_env.sh documents one` \
  `#    particular laptop's two R 4.5.3 installations. build_public.sh` \
  `#    itself is kept -- it documents how this release was assembled. ──────────` \
  --exclude="scripts/gen_card_index.R" \
  --exclude="scripts/make_circos_placeholders.R" \
  --exclude="scripts/audit_manuscript.sh" \
  --exclude="scripts/bioc_install_env.sh" \
  \
  `# ── Git metadata (never copy — public/ gets its own fresh git init) ────────` \
  --exclude=".git/" \
  \
  `# ── Build artefacts ───────────────────────────────────────────────────────` \
  --exclude="hallberg2025.base/.git/" \
  --exclude="hallberg2025.base/..Rcheck/" \
  --exclude="hallberg2025.base/.Rcheck/" \
  --exclude="manuscript/auto/" \
  --exclude="manuscript/.#*" \
  --exclude="output/temp/" \
  --exclude="output/temp.tar.gz" \
  \
  `# ── This script's own output dir (all known DEST names) ──────────────────` \
  --exclude="hallberg2025/" \
  --exclude="hallberg2025/" \
  --exclude="public/" \
  \
  `# -- Private data packages (cluster pipeline only; not part of the public` \
  `#    release).  Both carry internal cluster paths, gitignored targets stores` \
  `#    that rsync will happily copy because it does not read .gitignore, and` \
  `#    working notes.  Exclude each one wholesale. ──────────────────────────` \
  --exclude="hallberg2025.seq.data/" \
  --exclude="hallberg2025.meth.data/" \
  \
  `# -- BAM files and indices (controlled access; cluster-only) ──────────` \
  --exclude="bam/" \
  --exclude="bam_clean/" \
  \
  "$SRC/" "$DEST/"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — copy the specific pre-computed files _targets.R reads
#   These files contain only CG lab IDs or aggregate statistics — no PGDX IDs.
# ─────────────────────────────────────────────────────────────────────────────
echo "Copying pre-computed targets inputs..."

copy_file() {
  local src="$1" dest_dir="$2"
  if [ -f "$src" ]; then
    mkdir -p "$DEST/$dest_dir"
    cp "$src" "$DEST/$dest_dir/"
    echo "  OK  $dest_dir/$(basename "$src")"
  else
    echo "  MISSING  $src  (run wflow_build() first)"
  fi
}

# Same, but writes the copy under a different name (rsync cannot rename, so any
# file that must ship under a public name is handled here instead of in PHASE 1).
copy_file_as() {
  local src="$1" dest_rel="$2"
  if [ -f "$src" ]; then
    mkdir -p "$DEST/$(dirname "$dest_rel")"
    cp "$src" "$DEST/$dest_rel"
    echo "  OK  $dest_rel  (renamed from $(basename "$src"))"
  else
    echo "  MISSING  $src"
  fi
}

# Root .Rproj -- load-bearing, not cruft.  workflowr detects the project via
# rprojroot::find_rstudio_root_file(): any root *.Rproj holding a `Version:`
# line.  Without it wflow_build() cannot run at all.  PHASE 1 excludes the file
# only to keep the stale 2024.ovarian.subtypes name out of the public tree; it
# ships here under the public name.  (card REL-24)
copy_file_as "2024.ovarian.subtypes.Rproj" \
             "hallberg2025.Rproj"

# Consolidated mutation calls (CG lab IDs only; produced by code/mutations.rmd)
copy_file "output/mutations.rds" \
          "output"

# Bayesian mutation model results (gene-level summaries, no patient IDs)
copy_file "output/07-figure5.rmd/bayes.rds" \
          "output/07-figure5.rmd"

# Paired methylation proportions (aggregate per tumor type, no sample IDs)
copy_file "output/ext-figures/ext-figure9.Rmd/prop_methylated.rds" \
          "output/ext-figures/ext-figure9.Rmd"

# Supplemental Table 2 — coverage stats (lab IDs derived from CG BAM filenames)
copy_file "docs/table/table_s2.Rmd/table_S2.csv" \
          "docs/table/table_s2.Rmd"

# Supplemental Table 4 — WES mutation table (CG lab IDs)
copy_file "docs/table/table_s4.Rmd/table_S4.tsv" \
          "docs/table/table_s4.Rmd"

# Supplemental Table 5 — WGS mutation table (CG lab IDs)
copy_file "docs/table/table_s5.Rmd/table_S5.tsv" \
          "docs/table/table_s5.Rmd"

# Supplemental Table 6 — WGS amplifications (CG lab IDs) — MAN-04 file-target
copy_file "docs/table/table_s6.Rmd/table_S6.tsv" \
          "docs/table/table_s6.Rmd"

# Supplemental Table 7 — WES copy number segments (CG lab IDs) — MAN-04 file-target
copy_file "docs/table/table_s7.Rmd/table_S7.tsv" \
          "docs/table/table_s7.Rmd"

# Supplemental Table 8 — WGS deletions (CG lab IDs) — MAN-04 file-target
copy_file "docs/table/table_s8.Rmd/table_S8.csv" \
          "docs/table/table_s8.Rmd"

# Marginal CNV frequencies (per sample, CG lab IDs only) — needed by ext-figure1.Rmd
copy_file "output/05-data_integration.rmd/marginal_frequencies.rds" \
          "output/05-data_integration.rmd"

# Mutation spectra summaries (aggregate by mutation type, CG lab IDs) — figure2, figure4
copy_file "output/05-data_integration.rmd/mutation_spectra_summary.rds" \
          "output/05-data_integration.rmd"

# figure3 circos data, ext-fig 4-7 grobs and the ext-fig 8 rlist are NOT copied:
# they moved into hallberg2025.seq.data/inst/extdata/ and are reached through accessors
# (figure3_circos_data(), extfig47_circos_grobs(), extfig8_rlist()). hallberg2025.seq.data is
# excluded from this tree and installed from GitHub by CI.

# output/01-coverage_stats.rmd/ and output/read_length.rmd/ are NOT copied:
# filenames contain PGDX BAM identifiers. table_s2.Rmd (which reads them) is
# excluded from CI; its pre-built table_S2.csv is already committed.

# Sanitized FACETS outputs — CG lab IDs only, no PGDX or Genotype IDs
copy_dir() {
  local src="$1" dest="$2"
  if [ -d "$src" ]; then
    mkdir -p "$DEST/$dest"
    cp "$src"/*.txt "$DEST/$dest/" 2>/dev/null || true
    echo "  OK  $dest/ ($(ls "$src"/*.txt 2>/dev/null | wc -l | tr -d ' ') files)"
  else
    echo "  MISSING  $src  (run code/archive/sanitize_facets.R first)"
  fi
}
copy_dir "output/facets-trellis-public" "output/facets-trellis-public"
copy_dir "output/facets-public"         "output/facets-public"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3a — Fix .gitignore: drop the exclusions that must not apply in the
#   public tree, so that git add -A there actually tracks them.
#
#   (a) /hallberg2025.base/ -- the package directory itself.
#
#   (b) The rendered workflowr site under /docs/.  GIT-03 untracked ~58 MB of
#       generated content in the PRIVATE repo on purpose (it was the input to the
#       history rewrite), and that stays true -- but the consequence was that the
#       public repo shipped only 6 HTML pages, with no index.html and no figures,
#       while README.md advertises "pre-built HTML analysis website (view without
#       running Rmds)".  The public repo is a single historyless commit, so the
#       ~53 MB is a one-time snapshot cost and carries no history bloat.
#
#       Note this is *only* meaningful because rsync does not read .gitignore --
#       the files are already in $DEST from PHASE 1.  Stripping the rules here is
#       what lets `git add -A` commit them.
#
#   Build the site first (`make workflow`, or wflow_build() in the manuscript
#   container) or this phase ships whatever stale subset is on disk.
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "$DEST/.gitignore" ]; then
  python3 -c "
import sys
path = sys.argv[1]
lines = open(path).readlines()

# The base-package rule is matched by PREFIX, never by exact string.  It has
# been spelled '/hallberg2025.base/' and '/hallberg2025.base/*' (plus a
# '!/hallberg2025.base/CLAUDE.md' negation) at different times; an exact-string
# test silently stopped firing when DOC-13 rewrote it, and the snapshot lost all
# 76 package files with no error anywhere.  Strip every rule that mentions the
# directory, negations included, so the whole package is trackable.
BASE = 'hallberg2025.base/'

def is_base_rule(s):
    return s.lstrip('!').lstrip('/').startswith(BASE)

def is_site_rule(s):
    # Rendered site: every /docs/ rule except the table_s*.Rmd/ working dirs,
    # which hold raw pipeline artefacts and are excluded from the release
    # separately (see PHASE 1's docs/table/*/*** rule).
    return s.startswith('/docs/') and '/table/' not in s

n_base = n_site = 0
kept = []
for l in lines:
    s = l.rstrip('\r\n')
    if is_base_rule(s):
        n_base += 1
    elif is_site_rule(s):
        n_site += 1
    else:
        kept.append(l)
open(path, 'w').writelines(kept)
print(f'Fixed .gitignore: dropped {n_base} hallberg2025.base rule(s), {n_site} /docs/ site rule(s)')

# Fail closed.  Zero base rules dropped means the rule was renamed out from
# under this phase again -- 'git add -A' would then skip the entire package and
# the force-push would DELETE it from the public repo.
if n_base == 0:
    sys.exit('FAIL: no hallberg2025.base exclusion found in .gitignore. '
             'Either the rule was renamed (fix is_base_rule above) or it is '
             'gone; publishing now would drop the base package silently.')
" "$DEST/.gitignore"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3b — PHI scan: look for PGDX identifier values in all text files
#   Column names (facet_id, bamfile, pgdx_id) in code are expected and safe.
#   This scan catches actual PGDX sample ID values -- vendor accession numbers of
#   the form PGDX<digits>, optionally suffixed (…T_Ex, …N_Ex) or prefixed (t_…).
#   Do not write a literal example with digits here: the scanner reads its own
#   copy in the assembled tree and would flag it.
#
#   The include globs are matched by fnmatch, which is CASE-SENSITIVE.  Writing
#   them as literals (--include="*.Rmd") is how four PGDX IDs in the lowercase
#   code/mutations.rmd shipped under an "OK" verdict.  Every pattern below is
#   therefore spelled with character classes so both cases match.  Add new
#   extensions the same way; a plain literal is a silent hole.
# ─────────────────────────────────────────────────────────────────────────────
PHI_INCLUDES=(
  --include="*.[Rr]"
  --include="*.[Rr][Mm][Dd]"        # .Rmd and .rmd
  --include="*.[Qq][Mm][Dd]"
  --include="*.[Mm][Dd]"
  --include="*.[Cc][Ss][Vv]"
  --include="*.[Tt][Ss][Vv]"
  --include="*.[Tt][Xx][Tt]"
  --include="*.[Tt][Ee][Xx]"
  --include="*.[Rr][Tt][Ee][Xx]"    # manuscript/hallberg2.Rtex
  --include="*.[Rr][Nn][Ww]"
  --include="*.[Ss][Hh]"
  --include="*.[Oo][Rr][Gg]"
  --include="*.[Yy][Mm][Ll]"
  --include="*.[Yy][Aa][Mm][Ll]"
  --include="*.[Jj][Ss][Oo][Nn]"
  --include="*.[Hh][Tt][Mm][Ll]"    # REL-19 publishes docs/ -- 150 rendered pages
  --include="*.[Hh][Tt][Mm]"
)
echo ""
echo "=== PHI scan: checking for PGDX identifier values ==="
HITS=$(grep -rn \
  "${PHI_INCLUDES[@]}" \
  -e "PGDX[0-9]" -e "_PGDX[0-9]" \
  "$DEST/" 2>/dev/null || true)

if [ -n "$HITS" ]; then
  echo "WARNING: PGDX identifier values found — review before publishing:"
  echo "$HITS" | head -40
  exit 1
else
  echo "OK: no PGDX identifier values found"
fi

echo ""
echo "Done. Public release assembled at: $DEST"
echo "Next steps:"
echo "  1. cd $DEST && git init && git add -A && git commit -m 'Initial public release'"
echo "  2. ZIP for Zenodo: cd $(dirname "$DEST") && zip -r hallberg2025_ovarian_subtypes.zip $(basename "$DEST")"
