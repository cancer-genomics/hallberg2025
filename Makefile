# ─── Reproducibility ──────────────────────────────────────────────────────────
#
# The pipeline depends on three packages: hallberg2025.base (data + analysis
# functions, a subdirectory of this repo) and two companion data packages that
# live in their own repos and are installed from GitHub —
# hallberg2025.seq.data (FACETS/trellis copy-number output, read by _targets.R
# and by seven analysis/ pages) and hallberg2025.meth.data (the methylation
# SummarizedExperiment, read by _targets.R only):
#
#   remotes::install_github("cancer-genomics/hallberg2025.seq.data")
#   remotes::install_github("cancer-genomics/hallberg2025.meth.data")
#
# `make install` builds hallberg2025.base only — the two companion packages are
# installed once, out of band, by the commands above.
#
# Full local reproduction runs in this order:
#
#   1. make install   — (re)install hallberg2025.base from source
#   2. make workflow  — run analysis/ Rmds (wflow_build); produces figures,
#                       tables, and pre-computed files consumed by _targets.R
#   3. make verify    — verify workflow outputs match committed baseline
#                       (45 CSV/TSV/PNG, 40 RDS, 10 RDA, supplemental_tables.xlsx)
#   4. make targets   — run manuscript pipeline (tar_make)
#   5. make verify    — verify manuscript numbers match committed baseline
#   6. make pdf       — compile hallberg2025.pdf
#
# Shortcuts:
#   make all          — steps 1–6 in sequence
#   make check        — steps 4–5 only (skips workflow; uses committed files)
#
# Partial check (when ext-figure4-7 Circos PDFs are not yet available):
#   make check-partial — builds only the 11 unrestricted figure Rmds + all
#                        table Rmds, writes placeholder PDFs for the 4 missing
#                        Circos figures, compiles hallberg2025.pdf and
#                        supplemental.pdf, and verifies table hashes and
#                        manuscript target values.
#
# ─── Updating cancer-genomics/hallberg2025 ────────────────────────────────────
#
# The paper is published (Cancer Res Commun, accepted 2025-09).
# cancer-genomics/hallberg2025 is currently a private GitHub repo that will be
# made public once CI passes; Tier 2a reproducibility (from-BAM trellis) is
# already confirmed.
#
# CI (.github/workflows/check.yml) needs all three packages present in the tree
# it runs against, and checks out whichever are missing: hallberg2025.base (via
# the PACKAGE_DEPLOY_KEY secret, since it is gitignored here), and the two
# companion data packages hallberg2025.seq.data (public, no key) and
# hallberg2025.meth.data (private, via OSMETH_DEPLOY_KEY).  In the public tree
# all three are checked out; in this private tree the companions are already
# present and the checkout steps no-op.
#
#   make clean-ci     — assemble a clean single-commit snapshot from the private
#                       repo and force-push to cancer-genomics/hallberg2025,
#                       triggering CI. Use this to test that the public repo CI
#                       passes after changes to the private repo.
#   make push-pkg     — force-push cancer-genomics/hallberg2025.base only
#                       (when only the R package changed)
#   make sync         — assemble clean files into DEST without pushing
#
# Usage:
#   make clean-ci                           (default commit message)
#   make clean-ci RELEASE_MSG="Fix: ..."   (custom message)
#   make clean-ci DEST=/tmp/release        (custom staging directory)
#
# ─── Running on JHPCE ──────────────────────────────────────────────────────────
#
# The cluster provides R via `module load conda_R/4.5.x` (then
# `srun --pty --mem=8G bash`), not renv — `.Rprofile` skips renv activation
# automatically when renv/activate.R is absent, so no extra flags are needed
# for that. But `devtools::install()`'s pak-based dependency resolution fails
# to spawn a subprocess on compute nodes ("Subprocess is busy or cannot
# start"), so package installation needs a different target there:
#
#   make install-jhpce                 (R CMD INSTALL, no devtools/pak)
#   make targets RSCRIPT=Rscript       (override the Mac-pinned Rscript path)
#   make verify RSCRIPT=Rscript

DEST        ?= hallberg2025
GH_ORG       = cancer-genomics
MAIN_REPO    = hallberg2025
PKG_REPO     = hallberg2025.base
RELEASE_MSG ?= Public release: Hallberg et al. 2025 ovarian cancer subtypes

# uvr's R, resolved from .r-version rather than hardcoded -- this must be the
# interpreter that OWNS .uvr/library, not merely one reporting the same version.
#
# ENV-13/ENV-23: two R 4.5.3 installs exist on this Mac, and they are not
# interchangeable. 39 of .uvr/library's compiled packages link libR.dylib by
# absolute path into uvr's tree, so loading them under the R.framework build
# pulls a second libR into the process and 16 of them -- the whole Bioconductor
# core stack -- segfault at dyn.load(). Both report 4.5.3, so .Rprofile's
# version guard passes either way and nothing warns you. Since _targets.R's
# tar_option_set(packages=) includes SummarizedExperiment, `make targets` under
# the framework R cannot run at all.
#
# Do NOT "fix" this by repointing at R.framework: uvr owns the library and every
# uvr::sync() rebuilds against uvr's R, so that change would be undone silently.
#
# On JHPCE, override on the command line: RSCRIPT=Rscript (see above) --
# `module load conda_R` provides the only R there and none of this applies.
R_VERSION   := $(shell tr -d '[:space:]' < .r-version)
UVR_R_HOME   = $(HOME)/.uvr/r-versions/$(R_VERSION)
RSCRIPT      = $(UVR_R_HOME)/bin/Rscript

# quarto shells out to `R` (not Rscript) to run the knitr engine, and picks it up
# from PATH unless QUARTO_R says otherwise -- so the qmd targets below export it,
# or the .Rprofile version guard rejects whatever R happens to be on PATH.
QUARTO_R     = $(UVR_R_HOME)/bin/R

# Unrestricted analysis Rmds: all figure and table Rmds except those that
# require FACETS/Trellis data (ext-figure0, ext-figure1, table_s6–s9).
# ext-figure4-7 is also excluded here because it needs circosfigs.rds;
# placeholder PDFs are created separately via make circos-placeholders.
UNRESTRICTED_RMDS = \
  analysis/figure1.Rmd \
  analysis/figure2.Rmd \
  analysis/figure3.Rmd \
  analysis/figure4.Rmd \
  analysis/figure5.Rmd \
  analysis/figure6.Rmd \
  analysis/ext-figure2.Rmd \
  analysis/ext-figure3.Rmd \
  analysis/ext-figure8.Rmd \
  analysis/ext-figure9.Rmd \
  analysis/ext-figure10.Rmd \
  analysis/ext-figure11.Rmd \
  analysis/table_s1.Rmd \
  analysis/table_s2.Rmd \
  analysis/table_s3.Rmd \
  analysis/table_s4.Rmd \
  analysis/table_s5.Rmd

.PHONY: all check check-partial install install-jhpce workflow verify-artifacts targets verify verify-docs pdf \
        figures-baseline check-figures circos-placeholders check-pdf \
        clean-ci sync push-pkg clean plan audit

# ─── Step 1: package ──────────────────────────────────────────────────────────

install:
	$(RSCRIPT) -e "devtools::install('hallberg2025.base')"

# JHPCE: devtools::install() invokes pak for dependency resolution, which
# fails to spawn a subprocess on compute nodes. R CMD INSTALL skips pak
# entirely and installs into whatever library is active under conda_R.
install-jhpce:
	R CMD INSTALL hallberg2025.base

# ─── Step 2: workflowr analysis pages ─────────────────────────────────────────
#
# Builds all analysis/ Rmds and writes outputs to docs/ and output/.
# Some of these outputs are consumed by _targets.R (see step 4).

workflow:
	$(RSCRIPT) -e "library(workflowr); wflow_build()"

# ─── Step 3: verify workflow outputs ─────────────────────────────────────────
#
# Checks 45 CSV/TSV/PNG files, 40 RDS, 10 package RDA datasets, and
# supplemental_tables.xlsx against the committed baseline.

verify-artifacts:
	$(RSCRIPT) tests/verify_artifacts.R

# ─── Step 4: manuscript targets pipeline ──────────────────────────────────────
#
# tar_make() reads pre-computed files from docs/ and output/ (built by
# 'make workflow', or committed to the repo) and computes all manuscript numbers.

targets:
	$(RSCRIPT) -e "library(targets); tar_make()"

# ─── Step 5: verify manuscript numbers ────────────────────────────────────────
#
# Checks 35 manuscript target values against the committed baseline, and guards
# against the recurring "table_s4.rmd vs table_s4.Rmd" case-mismatch bug (GATE-03):
# invisible on macOS, a hard failure on Linux CI.

verify:
	$(RSCRIPT) tests/verify_snapshot.R
	$(RSCRIPT) tests/verify_rmd_case.R

# ─── Documentation-drift gate ─────────────────────────────────────────────────
#
# Checks that plan documents (REPRODUCIBILITY_PLAN.qmd, CHANGES.md, cards/*.md,
# provenance/*.md, every CLAUDE.md) cite paths that exist and are git-tracked, that
# status claims live only in the master, that asserted counts (35/25/9, CLAUDE.md
# count, latest CHANGES.md entry) match reality, and that cards/INDEX.md matches
# card frontmatter.

verify-docs:
	$(RSCRIPT) tests/verify_docs.R

# ─── Step 6: manuscript PDF ───────────────────────────────────────────────────

pdf: manuscript/hallberg2025.Rtex
	cd manuscript; pdflatex supplemental
	$(RSCRIPT) -e "library(targets); tar_make()"
	cd manuscript; pdflatex hallberg2025
	cd manuscript; bibtex hallberg2025
	cd manuscript; pdflatex hallberg2025
	cd manuscript; pdflatex hallberg2025

# ─── Step 7: manuscript audit ─────────────────────────────────────────────────

# Compare the pipeline's manuscript output against the accepted-for-publication
# version (tag CancerResCommunications_2025-09-accepted).  Reads the already-built
# manuscript/hallberg2025.tex -- run `make pdf` first.  Needs no R.
# Artifacts land in the gitignored manuscript/audit/.
audit:
	bash scripts/audit_manuscript.sh

# ─── Shortcuts ────────────────────────────────────────────────────────────────

all: install workflow verify-artifacts targets verify pdf

check: targets verify verify-docs

# ─── Partial check (no restricted FACETS data required) ──────────────────────
#
# Builds the 11 unrestricted figure Rmds + all table Rmds, creates placeholder
# PDFs for the 4 missing Circos figures, compiles both LaTeX files, and
# verifies table hashes and manuscript target values.

check-partial: circos-placeholders targets
	$(RSCRIPT) -e "library(workflowr); wflow_build(files=strsplit('$(UNRESTRICTED_RMDS)', ' +')[[1]])"
	$(RSCRIPT) tests/check_pdf_compilable.R
	$(RSCRIPT) tests/verify_snapshot.R

# ─── Placeholder PDFs for restricted Circos figures ───────────────────────────

circos-placeholders:
	$(RSCRIPT) scripts/make_circos_placeholders.R

# ─── PDF compilation check ───────────────────────────────────────────────────

check-pdf:
	$(RSCRIPT) tests/check_pdf_compilable.R

# ─── Figure hash review (manual, not in CI) ───────────────────────────────────

figures-baseline: manuscript/hallberg2025.Rtex manuscript/supplemental.tex
	$(RSCRIPT) tests/save_figure_baseline.R

check-figures: manuscript/hallberg2025.Rtex manuscript/supplemental.tex
	$(RSCRIPT) tests/verify_figures.R

# ─── Reproducibility plan (rendered doc) ──────────────────────────────────────
#
# REPRODUCIBILITY_PLAN.qmd is the single source of truth; the .html is a
# derived, gitignored render (see .gitignore). Re-run this after editing the
# .qmd so the checked-in-adjacent .html stays current for local review.

plan:
	QUARTO_R=$(QUARTO_R) quarto render REPRODUCIBILITY_PLAN.qmd

# ─── Card dashboard (rendered doc) ─────────────────────────────────────────────
#
# cards/dashboard.qmd computes completed/total per category and cards created
# since the DOC-01 baseline straight from cards/*.md frontmatter and git history
# every render -- nothing to hand-edit. The .html is a derived, gitignored
# render (see .gitignore).

dashboard:
	QUARTO_R=$(QUARTO_R) quarto render cards/dashboard.qmd

# ─── Clean ────────────────────────────────────────────────────────────────────

clean:
	cd manuscript; latexmk -c
	cd manuscript; rm -f *.aux *.bbl

# ─── Update cancer-genomics/hallberg2025 ──────────────────────────────────────
#
# clean-ci: assemble a clean single-commit snapshot from the private repo and
# force-push to cancer-genomics/hallberg2025, triggering CI. The public repo
# receives a single squashed commit — git history is not preserved in hallberg2025.
# This is intentional: hallberg2025 is a snapshot repo, not a development repo.
#
# When cancer-genomics/hallberg2025 is made public (by changing GitHub visibility
# manually), do not run clean-ci again — use normal git commits instead.

sync:
	bash scripts/build_public.sh $(DEST)

clean-ci: sync
	cd $(DEST) && \
	  git init -b main && \
	  git remote add origin git@github.com:$(GH_ORG)/$(MAIN_REPO).git 2>/dev/null || true && \
	  git remote set-url origin git@github.com:$(GH_ORG)/$(MAIN_REPO).git && \
	  git add -A && \
	  git commit -m '$(RELEASE_MSG)' && \
	  git gc --quiet && \
	  git push --force origin main

# ─── Update cancer-genomics/hallberg2025.base only ────────────────────────────
#
# Use when only the R package changed and hallberg2025 does not need updating.

push-pkg:
	@TMP=$$(mktemp -d) && \
	cp -r $(DEST)/$(PKG_REPO)/. $$TMP && \
	cd $$TMP && \
	git init -b main && \
	git remote add origin git@github.com:$(GH_ORG)/$(PKG_REPO).git && \
	git add -A && \
	git commit -m '$(RELEASE_MSG)' && \
	git gc --quiet && \
	git push --force origin main && \
	rm -rf $$TMP
