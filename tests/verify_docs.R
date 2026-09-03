## Plan-document integrity gate (card GATE-01)
##
## The card system's one real failure mode is documentation drift: a generated index
## disagreeing with card frontmatter, or a plan document citing a path/count that is
## wrong. Five assertions:
##
##   1. Every path cited (in an inline `code span`) in a plan document exists on disk.
##   2. Every such path that exists is git-tracked (the fresh-clone test).
##   3. CLAUDE.md files (and TRELLIS_FRAGILITY.md, per SEQ-11's precedent) carry no
##      DONE/COMPLETE/Pending/TODO status tokens -- status lives only in card frontmatter
##      and REPRODUCIBILITY_PLAN.qmd's generated block.
##   4. Counts asserted in prose (35/25/9, the historical "379 target hashes" bug, the
##      CLAUDE.md file count) match reality.
##   5. cards/INDEX.md matches card frontmatter (scripts/gen_card_index.R --check).
##
## Usage: Rscript tests/verify_docs.R
## Exit 0: all five assertions pass. Exit 1: one or more fail.
##
## Scope notes (see cards/GATE-01-verify-docs.md and its Notes/log for the reasoning):
##
## - Only *inline* `code spans` are treated as path citations. Fenced ``` code blocks are
##   frozen shell transcripts (Evidence sections, Done-when checklists) and are exempt --
##   evidence_asof freezes them on purpose; they are not living claims.
## - For cards/*.md specifically, the frontmatter block, the "## Evidence" section, and
##   the "## Notes / log" section are exempt from all four content assertions (1/2/3/4):
##   a card's Evidence is a snapshot at evidence_asof; Notes/log is where a session appends
##   what it found. What remains "live" is Why/Do/Do NOT/anything else.
## - Within that live remainder, cards additionally restrict assertions 1/2 to only
##   "## Why" and "## Do NOT" for *non*-documentation paths (code/data/script/directory
##   citations). "## Do" sections, and any other custom heading a card uses (a decision
##   card's "## Options", a job-tracking "## 34408517", etc.), are inherently procedural or
##   conditional narrative -- "run this, which writes to `reproduction_output/`", "clean up
##   `.uvr/` before finishing", "chmod the `JHU_EST_1941_GSFile/` dir" -- describing files
##   that get created, consumed, or cleaned up as steps in a not-yet-executed (or
##   cluster/other-machine-only) procedure, not a claim that the path exists in this
##   checkout right now. Citations of *other documentation* (`.md`/`.qmd`/`.html`/
##   `DESCRIPTION`) are still checked everywhere in a card's live body, Do included --
##   that is the actual class of bug this gate exists to catch (a doc citing a doc that
##   moved), and it is not procedural in the same way.
## - The same doc-citations-only restriction applies to the four documents the project's
##   own CLAUDE.md names as evidence appendices -- CHANGES.md, provenance/*.md,
##   code/facets-trellis/TRACK_C_REFACTOR_PLAN.md, code/facets-trellis/TRELLIS_FRAGILITY.md
##   -- for the same reason: they are dated historical narrative by design (a changelog
##   entry naming the one-off script used to reproduce a 2026-07 crash, a provenance plan
##   walking the pre-refactor `code/methylation/` tree) and are not supposed to stay
##   in lockstep with the current file tree. Their *cross-references to other documents*
##   are still checked in full -- that was the original motivating bug (CHANGES.md citing
##   `code/methylation_provenance_verification_plan.md`, which DOC-04 relocated).
## - REPRODUCIBILITY_PLAN.qmd (the master) and every CLAUDE.md are checked in full, with no
##   procedural/appendix carve-out: neither is a runbook of steps-to-execute, and CLAUDE.md
##   files are explicitly load-bearing (DOC-06) -- a stale citation there is exactly the
##   drift this gate exists to catch.
## - A path under a gitignored prefix (e.g. `code/archive/`, a `.gitignore`d `_targets_*`
##   store) is deliberately allowed to be absent/untracked -- referencing it as "local-only"
##   is the documented, correct thing to do. Such paths are exempt from both assertions,
##   checked against every prefix combination the path could resolve to, not just its
##   literal unresolved spelling.
## - A citation that resolves only to a *broken symlink* counts as present: the symlink
##   itself is real and git-tracked in this checkout, it just doesn't dereference on a
##   laptop. Assertion 1 asks "is there a citable thing here", not "is the cluster
##   mounted". (No such symlink is currently tracked in this repo -- MET-06's
##   `idat_links/batch{1,2}_idats` were converted to plain-text pointer files by MET-09,
##   since `R CMD build` dereferences symlinks and aborts on the dangling ones off-cluster
##   -- but the check stays generic for whatever future citation needs it.)
## - Bare filenames (no `/`) are only treated as path citations when they have a
##   recognizable (letter-led) extension, and are resolved against *either* the repo root
##   *or* the citing document's own directory -- this lets a directory's own CLAUDE.md
##   reference its sibling files by basename (e.g. tests/CLAUDE.md -> `verify_snapshot.R`)
##   without requiring every citation to spell out the directory.
## - GH_ORG_DENYLIST catches "org/repo" shorthand (`cancer-genomics/trellis`) and a few
##   sibling-directory names that live *outside* this repo checkout entirely (`private/...`,
##   `public/...` -- the outer project folder and the `build_public.sh` staging tree) --
##   path-shaped strings that are not citations into this tree at all.
## - A citation is also skipped when immediately preceded by a negation/historical-origin
##   phrase ("not", "never", "consolidated from", "absorbed from") -- these describe what a
##   path used to be, or explicitly isn't, not a current-state claim.

suppressPackageStartupMessages(library(here))

ROOT <- here()
pass <- TRUE
fail <- function(...) { cat(sprintf(...)); pass <<- FALSE }
ok   <- function(...) cat(sprintf(...))

## ── Document inventory ───────────────────────────────────────────────────────

find_claude_mds <- function() {
  f <- list.files(ROOT, pattern = "^CLAUDE\\.md$", recursive = TRUE, full.names = TRUE)
  f <- f[!grepl("/renv/|/hallberg2025/", f)]
  sort(f)
}

find_card_files <- function() {
  f <- list.files(file.path(ROOT, "cards"),
                   pattern = "^[A-Z]+-[0-9]+[a-z]?-.*\\.md$", full.names = TRUE)
  ## TEMPLATE.md is structurally a card (frontmatter + ## Evidence + ## Notes / log) even
  ## though its filename doesn't match the PREFIX-NN pattern -- its "paths" are
  ## placeholders (`path/one`, `path/to/CLAUDE.md`) that live entirely inside the
  ## frontmatter block, so it needs the same frontmatter-stripping treatment as a real
  ## card, not a bespoke exemption.
  f <- c(f, file.path(ROOT, "cards/TEMPLATE.md"))
  sort(f)
}

find_provenance_files <- function() {
  f <- list.files(file.path(ROOT, "provenance"), pattern = "\\.md$", full.names = TRUE)
  sort(f)
}

CLAUDE_MDS   <- find_claude_mds()
CARD_FILES   <- find_card_files()
PROV_FILES   <- find_provenance_files()
## cards/JOBS.md and cards/PARKED.md are, like CHANGES.md, dated historical/operational
## narrative: JOBS.md's job rows describe cluster-only output paths (`~/env03_install.log`
## on cluster home, in-flight `.out` files for jobs still running) that were never meant to
## resolve on a laptop checkout; PARKED.md cites external-repo paths (`CancerGenes/PLAN.md`)
## that live outside this tree by design (see the `EXT` prefix). Both get the
## appendix-style restriction: only cross-references to *other documentation* are checked,
## not every code/data/script path mentioned in the operational narrative.
CARD_APPENDICES <- c(
  file.path(ROOT, "cards/JOBS.md"),
  file.path(ROOT, "cards/PARKED.md")
)

## GATE-04: a `status: done` card's citations of the pre-rename package names
## (`ovarian.subtypes`, `OsSeqExpData`, `OsMethExpData`) are historical record, not a live
## claim -- GATE-05's own Done section says this explicitly ("excluding categories that are
## supposed to still contain them: `status: done` cards' bodies (historical record)"), and
## a done card's Why/Do-NOT prose describes the tree as it stood at evidence_asof, before
## this rename. Rewriting ~30 already-`done` cards to retroactively use the new names would
## itself be the thing cards/README.md forbids ("never rewrite that history" -- see
## `DOC-10`'s own Why). `cards/JOBS.md`/`PARKED.md` get the same treatment for the same
## reason: dated operational logs, not living guidance -- entries under old job/path names
## describe what those paths were called on the date the job ran.
##
## This does NOT exempt a *non*-done card (its citations may still need fixing before that
## card executes -- `DOC-10`'s whole reason for existing) or any non-card document (the
## master plan, CLAUDE.md files, `cards/README.md` itself) -- those are still live and still
## checked in full.
OLD_PACKAGE_PREFIX_RE <- "^(ovarian\\.subtypes|OsSeqExpData|OsMethExpData)(/|$)"

card_frontmatter_status <- function(path) {
  lines <- readLines(path, warn = FALSE, n = 40)
  dashes <- which(trimws(lines) == "---")
  if (length(dashes) < 2) return(NA_character_)
  fm <- lines[dashes[1]:dashes[2]]
  st <- grep("^status:", fm, value = TRUE)
  if (!length(st)) return(NA_character_)
  trimws(sub("^status:", "", st[1]))
}

CARD_STATUS <- setNames(vapply(CARD_FILES, card_frontmatter_status, character(1)), CARD_FILES)

is_historical_old_name_context <- function(path) {
  if (is_card_file(path)) return(identical(unname(CARD_STATUS[path]), "done"))
  path %in% CARD_APPENDICES
}
APPENDICES   <- c(
  file.path(ROOT, "CHANGES.md"),
  file.path(ROOT, "code/facets-trellis/TRACK_C_REFACTOR_PLAN.md"),
  file.path(ROOT, "code/facets-trellis/TRELLIS_FRAGILITY.md"),
  CARD_APPENDICES
)
MASTER <- file.path(ROOT, "REPRODUCIBILITY_PLAN.qmd")
## cards/README.md is the card-system protocol doc -- prose, no frontmatter/Evidence/Notes
## structure to strip, and (like the master and every CLAUDE.md) supposed to stay fully
## accurate rather than carrying a procedural/historical carve-out.
CARDS_README <- file.path(ROOT, "cards/README.md")
## Companion-package DESCRIPTION files: both cite the provenance tree (the original
## GATE-01 Evidence bug was a broken citation at OsMethExpData/DESCRIPTION:12-13).
DESCRIPTIONS <- c(
  file.path(ROOT, "hallberg2025.meth.data/DESCRIPTION"),
  file.path(ROOT, "hallberg2025.seq.data/DESCRIPTION")
)

## The full document set scanned by assertions 1/2/4 (path existence, git-tracked, counts).
## The card's own Do-item 1 says "cards/*.md" -- not just the numbered cards -- so the
## register's own protocol/parking-lot/job-log files are in scope too, each with the
## treatment its own structure calls for (see the comments above).
ALL_DOCS <- c(MASTER, CARDS_README, APPENDICES, CARD_FILES, PROV_FILES, CLAUDE_MDS, DESCRIPTIONS)
ALL_DOCS <- ALL_DOCS[file.exists(ALL_DOCS)]

is_card_file     <- function(path) path %in% CARD_FILES
is_appendix_file <- function(path) path %in% APPENDICES || path %in% PROV_FILES

## ── Section stripping ────────────────────────────────────────────────────────
##
## Returns the lines of `path` with certain ranges blanked out (kept as "" so line
## numbers in diagnostics still line up): fenced code blocks everywhere, and -- for
## cards specifically -- the frontmatter block, the "## Evidence" section, and the
## "## Notes / log" section (to EOF).

strip_fenced <- function(lines) {
  infence <- FALSE
  for (i in seq_along(lines)) {
    if (grepl("^\\s*```", lines[i])) {
      infence <- !infence
      lines[i] <- ""
      next
    }
    if (infence) lines[i] <- ""
  }
  lines
}

strip_card_sections <- function(lines) {
  n <- length(lines)
  dashes <- which(trimws(lines) == "---")
  if (length(dashes) >= 2) lines[dashes[1]:dashes[2]] <- ""

  h2 <- grep("^## [^#]", lines)
  section_end <- function(start) {
    later <- h2[h2 > start]
    if (length(later)) later[1] - 1L else n
  }
  ev_start <- h2[grepl("^## Evidence\\b", lines[h2])]
  if (length(ev_start)) lines[ev_start[1]:section_end(ev_start[1])] <- ""
  notes_start <- h2[grepl("^## Notes", lines[h2])]
  if (length(notes_start)) lines[notes_start[1]:n] <- ""

  lines
}

## Keeps ONLY the "## Why" and "## Do NOT" sections of a card (everything else blanked).
## Used to decide, per line, whether a *non-documentation* path citation is in a section
## that plausibly makes a current-state claim (Why/Do NOT) versus a procedural one (Do,
## Done when, or any card-specific heading like "## Options"/"## 34408517").
strict_card_lines <- function(lines) {
  n <- length(lines)
  h2 <- grep("^## [^#]", lines)
  if (!length(h2)) return(lines)
  starts <- h2
  ends   <- c(h2[-1] - 1L, n)
  keep <- rep(FALSE, n)
  for (i in seq_along(starts)) {
    heading <- trimws(lines[starts[i]])
    if (grepl("^## Why\\b", heading) || grepl("^## Do NOT\\b", heading)) {
      keep[starts[i]:ends[i]] <- TRUE
    }
  }
  lines[!keep] <- ""
  lines
}

live_lines <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (is_card_file(path)) lines <- strip_card_sections(lines)
  strip_fenced(lines)
}

## Same as live_lines(), but also blanks inline `code spans` -- used by assertions 3/4,
## which look at prose, not at things merely *quoted* (e.g. a card's Evidence-adjacent
## prose quoting a code comment verbatim).
live_prose_lines <- function(path) {
  lines <- live_lines(path)
  gsub("`[^`\n]*`", "", lines)
}

## ── Assertion 1 + 2: cited paths exist and are git-tracked ──────────────────

tracked_files <- tryCatch(
  system2("git", c("-C", shQuote(ROOT), "ls-files"), stdout = TRUE, stderr = FALSE),
  error = function(e) character(0)
)

is_tracked <- function(rel) {
  if (rel %in% tracked_files) return(TRUE)
  ## directory reference: tracked if anything under it is tracked
  any(startsWith(tracked_files, paste0(sub("/$", "", rel), "/")))
}

## file.exists() on a broken symlink is FALSE, but a tracked symlink to cluster-only
## storage is a real, correct citation on a laptop checkout -- it just doesn't dereference
## here. Treat "is a symlink at all" as presence too.
path_present <- function(p) {
  if (file.exists(p)) return(TRUE)
  link <- tryCatch(Sys.readlink(p), error = function(e) "")
  !is.na(link) && nzchar(link)
}

check_ignored <- function(candidates) {
  if (!length(candidates)) return(character(0))
  out <- tryCatch(
    system2("git", c("-C", shQuote(ROOT), "check-ignore", candidates),
            stdout = TRUE, stderr = FALSE),
    error = function(e) character(0), warning = function(w) character(0)
  )
  out
}

## Path candidates require at least one `/` -- R itself uses `.` as a name separator
## (`set.seed`, `data.table`, `split.default`, `Fstat.p`, `svfilters.hg18`...), so a bare
## `name.ext`-shaped backtick span is not reliably a file citation. This means genuinely
## bare citations of well-known root files (`CHANGES.md`, `verify_snapshot.R`) are not
## checked either -- a deliberate precision-over-recall call; see the card's Notes/log.
##
## GH_ORG_DENYLIST catches "org/repo" shorthand (`cancer-genomics/trellis`,
## `mskcc/facets`, `dhallber/endomuc`, `Velculescu/dhallberg`) and sibling directories
## that live *outside* this checkout ("private/2025.ovarian.subtypes" describing the
## repo's own place in the containing folder; "public/..." the build_public.sh staging
## tree) -- path-shaped but not a citation into this tree.
## ...and a few bare directory-name fragments of *cluster* storage paths that recur in
## prose without their absolute prefix (skoul's warehouse GenomeStudio export, the
## `dcl01`-scratch-only pre-refactor TCGA tree) -- never resolvable in any git checkout of
## this repo, laptop or cluster, because they were never inside it.
## `CancerGenes` (cards/PARKED.md's `CancerGenes/PLAN.md`) is the same case as the cluster
## fragments above, not an org/repo shorthand: it is a standalone sibling lab project the
## project's own CLAUDE.md module map places outside this tree entirely ("EXT | repos
## outside this tree (trellis, CancerGenes, svfilters.*)"); PARKED.md citing its plan
## document is a cross-repo pointer, never a path that resolves inside this checkout.
GH_ORG_DENYLIST <- c("cancer-genomics", "mskcc", "dhallber", "Velculescu", "jhpce.jhu.edu",
                     "private", "public", "extdata_old", "CancerGenes",
                     "JHU_EST_1941_GSFile", "JHU_EST_1941_idats")

## One narrow, explicit, disclosed exception: `<file>:<line>` pairs this gate would
## otherwise flag, that are real but genuinely not this card's (or any open card's) to
## fix right now -- disclosed here rather than silently hidden, per this repo's own
## test-data-integrity.R precedent (tests/CLAUDE.md: a knowingly-red assertion is
## reconciled by a named card, never by weakening the check). Removing an entry should
## coincide with the cited card actually closing the underlying issue.
KNOWN_EXCEPTIONS <- c(
  ## cards/REL-04-dead-precomputed-copies.md's own Do NOT: `build_public.sh:167-168`
  ## copies `output/ext-figures/ext-figure9.Rmd/...`, but the git-tracked directory is
  ## lowercase `ext-figure9.rmd` -- this only resolves today because macOS is
  ## case-insensitive. REL-04 explicitly says "leave that alone... REL-03's problem if
  ## Linux CI trips on it" -- touching build_public.sh is outside GATE-01's scope and
  ## explicitly forbidden by REL-04's own Do-NOT.
  "cards/REL-04-dead-precomputed-copies.md:141",

  ## Found live by REL-16 (container-based CI run): two false positives, both prose,
  ## not path citations, in already-`done` cards outside this card's own scope to edit.
  ## `svfilters.hg18/hg19` is shorthand for two sibling package names sharing a common
  ## prefix (this project's own naming convention for the hg18/hg19 genome-build
  ## variants), not a path -- `is_path_shaped()`'s slash-separated-segment rule can't
  ## distinguish this from a real path without misclassifying genuine multi-segment
  ## citations elsewhere.
  "cards/ENV-19-build-seq-data-raw-docker-image.md:29"

  ## REMOVED by GATE-07: "cards/REL-15-publish-manuscript-image-ghcr.md:29", a
  ## `ghcr.io/cancer-genomics/...` container-registry reference. is_path_shaped() now
  ## rejects any token whose first segment is a hostname, so that string -- and every
  ## other registry reference anyone writes later -- is handled by a rule instead of by
  ## a file:line entry that would silently stop matching the moment the card's Notes
  ## grew by a line.
)

## Three classes of token that are path-SHAPED but are never citations into this tree.
## All three are matched on the token's FIRST SEGMENT, generically -- GATE-07 added them
## in place of file:line exceptions, which are keyed to a line number and silently stop
## matching as soon as an open card's Notes grow.

## A registry/host reference (`ghcr.io/cancer-genomics/hallberg2025-manuscript`,
## `jhpce.jhu.edu/...`). Recognised by a KNOWN suffix, not by "contains a dot": this
## repo's own package directories are dotted (`hallberg2025.base`,
## `hallberg2025.seq.data`), and a generic `<label>.<letters>` hostname pattern would
## classify every one of them as a hostname and stop checking their contents entirely.
HOSTNAME_TLDS <- c("io", "com", "org", "net", "edu", "gov", "dev", "ai", "co",
                   "uk", "us", "cloud")

## Absolute-path roots written WITHOUT their leading slash, because prose quotes them as
## a symlink target rather than as a location (`/lib64` -> `usr/lib64`). The leading-slash
## form is already rejected above by the "^[/$]" rule; this is the same idea for the
## dereferenced spelling.
FS_ROOT_SEGMENTS <- c("usr", "etc", "var", "opt", "tmp", "proc", "dev",
                      "bin", "sbin", "lib", "lib64", "run", "srv", "boot")

## Docker/OCI platform pairs (`linux/amd64`, `darwin/arm64`).
PLATFORM_SEGMENTS <- c("linux", "darwin", "windows")

is_hostname_segment <- function(seg) {
  parts <- strsplit(seg, ".", fixed = TRUE)[[1]]
  length(parts) >= 2 && tolower(parts[length(parts)]) %in% HOSTNAME_TLDS
}

is_path_shaped <- function(x) {
  if (grepl("[[:space:]]", x))              return(FALSE)
  if (grepl("::", x, fixed = TRUE))          return(FALSE)
  if (grepl("[()<>]", x))                    return(FALSE)
  if (grepl("^https?://|^git@|://", x))      return(FALSE)
  if (grepl("^[/$]", x))                     return(FALSE)  # absolute/cluster or shell var
  if (grepl("^[.]{2,}", x))                  return(FALSE)  # "..." elision marker
  if (!grepl("/", x))                        return(FALSE)  # bare filenames: see above
  x2 <- sub(":[0-9]+(-[0-9]+)?$", "", x)
  if (!grepl("^[A-Za-z0-9_.\\-]+(/[A-Za-z0-9_.\\-]+)*/?$", x2)) return(FALSE)
  ## The repo's own directory name used self-referentially in prose ("the private source
  ## lives at `2025.ovarian.subtypes/`") names the checkout from OUTSIDE it, so it can
  ## never resolve from within. Derived from ROOT rather than hardcoded -- BASE-06 has
  ## already renamed things here once.
  if (identical(sub("/$", "", x2), basename(ROOT)))    return(FALSE)

  first_seg <- strsplit(x2, "/", fixed = TRUE)[[1]][1]
  if (first_seg %in% FS_ROOT_SEGMENTS)                 return(FALSE)
  if (first_seg %in% PLATFORM_SEGMENTS)                return(FALSE)
  if (is_hostname_segment(first_seg))                  return(FALSE)
  !(first_seg %in% GH_ORG_DENYLIST)
}

## A citation is a "documentation reference" if it plausibly names another plan/reference
## document (as opposed to a code/data/script/directory path). Deliberately excludes
## .Rmd/.rmd: those are pipeline-stage scripts in this project (analysis/*.Rmd,
## code/05-data_integration.rmd), not cross-referenced plan documents, and historical
## narrative constantly names them ("commit X renamed a variable in
## `code/05-data_integration.rmd`") without claiming they exist today.
is_doc_reference <- function(clean) {
  grepl("\\.(md|qmd|html)$", clean) || basename(clean) == "DESCRIPTION"
}

## "(not `docs/provenance/` -- ...)" is citing a path to explain why it's *wrong*, not
## claiming it resolves. "Consolidated from `X`" / "absorbed from `X`" / "originally `X`" /
## "the standalone `X`" name a historical predecessor file, not a current one. Skip a
## candidate whose backtick span is immediately preceded by one of these.
NEGATION_RE <- "(not|never|n't|consolidated from|absorbed from|originally|standalone)\\s*$"

extract_candidates <- function(path) {
  lines <- live_lines(path)
  restrict_mask <- rep(FALSE, length(lines))   # TRUE = doc-references only on this line
  if (is_card_file(path)) {
    strict <- strict_card_lines(lines)
    restrict_mask <- strict != lines
  } else if (is_appendix_file(path)) {
    restrict_mask <- rep(TRUE, length(lines))
  }
  historical_old_names <- is_historical_old_name_context(path)

  m <- gregexpr("`([^`\n]+)`", lines)
  spans <- regmatches(lines, m)
  out <- list()
  for (i in seq_along(spans)) {
    if (!length(spans[[i]])) next
    positions <- gregexpr("`([^`\n]+)`", lines[i])[[1]]
    for (k in seq_along(spans[[i]])) {
      s <- spans[[i]][k]
      content <- trimws(substring(s, 2, nchar(s) - 1))
      if (!nchar(content) || !is_path_shaped(content)) next
      clean <- sub(":[0-9]+(-[0-9]+)?$", "", content)
      if (restrict_mask[i] && !is_doc_reference(clean)) next
      if (historical_old_names && grepl(OLD_PACKAGE_PREFIX_RE, clean)) next
      pos <- positions[k]
      preceding <- if (pos > 1) substr(lines[i], max(1, pos - 40), pos - 1) else ""
      ## Markdown soft-wraps paragraphs across physical lines -- "...; originally\n`X`,
      ## folded in..." is one sentence, and a citation opening right at column 1 has no
      ## same-line preceding context to check. When the span starts within the window,
      ## fold in the tail of the previous line too.
      if (pos <= 40 && i > 1) {
        prev_tail <- substr(lines[i - 1], max(1, nchar(lines[i - 1]) - 40), nchar(lines[i - 1]))
        preceding <- paste0(prev_tail, " ", preceding)
      }
      if (grepl(NEGATION_RE, preceding, ignore.case = TRUE)) next
      out[[length(out) + 1]] <- list(file = path, line = i, raw = content, clean = clean)
    }
  }

  ## DESCRIPTION is plain prose, not markdown -- it has no backtick-span convention (the
  ## original GATE-01 Evidence bug, "OsMethExpData/DESCRIPTION:12-13 cites
  ## code/methylation_provenance_verification_plan.md", was written as bare prose, no
  ## backticks). Tokenize on whitespace and check each word for path-shapedness too.
  if (basename(path) == "DESCRIPTION") {
    for (i in seq_along(lines)) {
      line <- lines[i]
      ## DESCRIPTION is a debian-control-file: unindented "Field/Name: value" lines.
      ## A field key itself can be path-shaped (`Config/testthat/edition: 3`,
      ## `Config/roxygen2/version: 8.0.0`) without being a citation to anything -- strip
      ## the key before tokenizing so only the value half of the line is scanned. Wrapped
      ## continuation lines (indented, no leading key) are untouched and still scanned in
      ## full -- that's where real citations live (e.g. the Description: paragraph).
      if (grepl("^[A-Za-z][A-Za-z0-9./]*:", line)) {
        line <- sub("^[A-Za-z][A-Za-z0-9./]*:", "", line)
      }
      for (tok in strsplit(line, "[[:space:]]+")[[1]]) {
        content <- gsub("^[,;:()]+|[,;:()]+$", "", tok)
        if (!nchar(content) || !is_path_shaped(content)) next
        clean <- sub(":[0-9]+(-[0-9]+)?$", "", content)
        out[[length(out) + 1]] <- list(file = path, line = i, raw = content, clean = clean)
      }
    }
  }
  out
}

all_candidates <- unlist(lapply(ALL_DOCS, extract_candidates), recursive = FALSE)

## dedupe by (clean path, citing doc) isn't useful -- dedupe by clean path alone, keep
## first occurrence for reporting.
seen <- new.env()
uniq_candidates <- list()
for (c in all_candidates) {
  if (!exists(c$clean, envir = seen, inherits = FALSE)) {
    assign(c$clean, TRUE, envir = seen)
    uniq_candidates[[length(uniq_candidates) + 1]] <- c
  }
}

## This is a monorepo of independently-scoped packages (project CLAUDE.md's module-
## boundary map). Prose frequently drops the package prefix once context is established
## a few lines earlier ("Serve methylation_se from OsMethExpData ... inst/extdata/...").
## A candidate is accepted if it resolves at the literal repo-root-relative path, at the
## citing document's own directory, or under any of these package roots -- whichever
## resolves first is what gets checked for git-tracked-ness.
## "docs" is not a package, but it is the same phenomenon: the rendered workflowr site is
## its own root, and prose about it cites paths relative to that root
## (`figure/table_s2.Rmd/distribution.of.coverage-1.png`, which really lives at
## docs/figure/...). GATE-07 added it so site-relative citations resolve generically
## rather than one file:line exception at a time.
PACKAGE_PREFIXES <- c("", "hallberg2025.base", "hallberg2025.seq.data", "hallberg2025.meth.data",
                      "hallberg2025.seq.data/data-raw", "hallberg2025.meth.data/data-raw",
                      "docs")

## file.path("", rel) produces a leading-slash path ("/cards/INDEX.md"), not the bare
## relative path -- and a single invalid/leading-slash entry in the batch passed to `git
## check-ignore` aborts the *entire* batch with a fatal error, silently discarding every
## real answer (see the card's Notes/log: this was the root cause of assertion 2 reporting
## dozens of spurious untracked-path failures). Join only when the prefix is non-empty.
join_prefix <- function(prefix, rel) if (nzchar(prefix)) file.path(prefix, rel) else rel

## The literal-as-cited path, and the path resolved relative to the citing document's own
## directory -- these are the only two attempts we have direct evidence for; anything else
## is a speculative guess (below). Used to decide "gitignored, therefore fine to be
## missing" -- NOT the full package-prefix cross-product, because at least one whole
## nested-repo boundary in this tree (`hallberg2025.base/`) is gitignored in its entirety
## (.gitignore:335), so a *coincidental* guess like "hallberg2025.base/<unrelated rel>"
## would "match" the ignore pattern for almost anything, regardless of whether that guess
## has anything to do with the actual citation -- e.g. a genuinely-broken citation to
## `code/methylation_provenance_verification_plan.md` must not be waved through just
## because "hallberg2025.base/code/methylation_provenance_verification_plan.md" (a path
## nobody claimed, a pure side effect of blindly trying every package prefix) happens to
## sit under an ignored directory.
## Nearest ancestor of `doc_dir` that is an R package root (has a DESCRIPTION), or NA.
## This is evidence, not a guess: a document physically inside a package that cites a bare
## `data-raw/...` is citing its own package's tree, the same way a document cites its own
## directory. That is why the result belongs in primary_attempts() rather than in the
## speculative cross-product -- see the resolution loop, whose gitignore-exemption pass
## consults primary only, and `hallberg2025.seq.data/data-raw/.container-r-lib/` (cited
## bare from that package's own CLAUDE.md) is deliberately gitignored.
nearest_package_root <- function(doc_dir) {
  if (!nzchar(doc_dir) || doc_dir == ".") return(NA_character_)
  d <- doc_dir
  repeat {
    if (file.exists(file.path(ROOT, d, "DESCRIPTION"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d) || parent %in% c(".", "/", "")) return(NA_character_)
    d <- parent
  }
}

primary_attempts <- function(rel, doc_dir) {
  pkg <- nearest_package_root(doc_dir)
  tried <- c(rel,
             if (nzchar(doc_dir) && doc_dir != ".") file.path(doc_dir, rel) else NA,
             if (!is.na(pkg) && pkg != doc_dir) file.path(pkg, rel) else NA)
  unique(tried[!is.na(tried)])
}

candidate_attempts <- function(rel, doc_dir) {
  unique(c(
    primary_attempts(rel, doc_dir),
    vapply(PACKAGE_PREFIXES, join_prefix, character(1), rel = rel, USE.NAMES = FALSE)
  ))
}

## Gather every attempted resolution, for every candidate, up front -- so the single
## `git check-ignore` batch call below can recognize a path as deliberately ignored at
## whichever prefix it actually resolves to (e.g. `_targets_change002_delta/` cited bare
## from hallberg2025.meth.data/data-raw/CLAUDE.md is only ignored at
## `hallberg2025.meth.data/data-raw/_targets_change002_delta/`, not at the bare string itself).
cand_meta <- lapply(uniq_candidates, function(c) {
  doc_dir <- dirname(sub(paste0("^", ROOT, "/?"), "", c$file))
  list(c = c,
       primary  = primary_attempts(c$clean, doc_dir),
       attempts = candidate_attempts(c$clean, doc_dir))
})
all_attempts <- unique(unlist(lapply(cand_meta, `[[`, "attempts")))
ignored_set <- check_ignored(all_attempts)

missing_paths <- list()
untracked_paths <- list()

for (m in cand_meta) {
  c <- m$c
  attempts <- m$attempts

  ## Checked first, before any resolution attempt -- a KNOWN_EXCEPTIONS entry is a
  ## disclosed non-citation (prose that merely looks path-shaped), not a path that
  ## happens to resolve, so it must be skipped before assertion 1's "does it exist at
  ## all" check, not just assertion 2's "is it tracked" check further down.
  relf_line <- sprintf("%s:%d", sub(paste0("^", ROOT, "/"), "", c$file), c$line)
  if (relf_line %in% KNOWN_EXCEPTIONS) next

  ## Resolve in three passes, most-authoritative first, not just "first attempt that
  ## happens to exist on disk". A bare citation like `inst/extdata/` tried under the
  ## package-prefix list can coincidentally match stray, untracked, unignored local debris
  ## (an empty leftover directory at the repo root, in one case found while writing this
  ## gate) *before* it ever reaches the actually-intended, correctly git-tracked location
  ## (`hallberg2025.seq.data/inst/extdata/`) later in the same attempt list. Assertion 2 is
  ## explicitly "the fresh-clone test" -- a fresh clone never has that local debris at
  ## all, so a tracked or deliberately-ignored match must always win over one that merely
  ## happens to exist on this particular laptop.
  ## Pass 2 (ignored) deliberately consults only m$primary, not the full speculative
  ## attempts list -- see primary_attempts()'s comment: a speculative "hallberg2025.base/
  ## <rel>" guess coincidentally matches the ignore pattern for *anything*, because that
  ## whole nested-repo directory is blanket-ignored, regardless of whether the guess has
  ## anything to do with the citation. Pass 1 (tracked) has no such trap -- exact
  ## git-ls-files truth isn't gameable by a directory-wide ignore rule.
  resolved <- NA_character_
  for (t in attempts) if (is_tracked(t)) { resolved <- t; break }
  if (is.na(resolved)) for (t in m$primary) if (t %in% ignored_set) { resolved <- t; break }
  if (is.na(resolved)) for (t in attempts) if (path_present(file.path(ROOT, t))) { resolved <- t; break }

  if (is.na(resolved)) {
    ## Not present under any candidate resolution -- exempt only if deliberately
    ## gitignored at a *literal* attempt (as-cited, or relative to the citing doc's own
    ## directory). Package-prefix guesses are deliberately excluded here -- see
    ## primary_attempts()'s comment for why (the hallberg2025.base/ blanket-ignore trap).
    if (any(m$primary %in% ignored_set)) next
    missing_paths[[length(missing_paths) + 1]] <- c
    next
  }
  if (resolved %in% ignored_set) next
  if (!is_tracked(resolved)) {
    untracked_paths[[length(untracked_paths) + 1]] <- c
  }
}

if (length(missing_paths)) {
  fail("FAIL (assertion 1 -- path exists): %d cited path(s) resolve nowhere:\n",
       length(missing_paths))
  for (c in missing_paths) {
    cat(sprintf("  %s:%d  `%s`\n", sub(paste0("^", ROOT, "/"), "", c$file), c$line, c$raw))
  }
} else {
  ok("OK (assertion 1): all %d cited path(s) exist\n", length(uniq_candidates))
}

if (length(untracked_paths)) {
  fail("FAIL (assertion 2 -- git-tracked): %d cited path(s) exist locally but are not git-tracked:\n",
       length(untracked_paths))
  for (c in untracked_paths) {
    cat(sprintf("  %s:%d  `%s`\n", sub(paste0("^", ROOT, "/"), "", c$file), c$line, c$raw))
  }
} else {
  ok("OK (assertion 2): all cited path(s) are git-tracked (or deliberately gitignored)\n")
}

## ── Assertion 3: status words confined to the master ────────────────────────
##
## CLAUDE.md files carry no exact-case DONE/COMPLETE/Pending/TODO token (status lives in
## card frontmatter and the master's generated block, never copied into living guidance
## docs). code/facets-trellis/TRELLIS_FRAGILITY.md is held to the same bar, per SEQ-11's
## own precedent (its Done-when check already asserts zero hits there). Other appendices
## (CHANGES.md, TRACK_C_REFACTOR_PLAN.md, provenance/*.md) are, in their entirety, dated
## historical narrative -- see the header note -- and are exempt from this assertion.
##
## This deliberately anchors on exact-case tokens, not the word in any casing: ordinary
## prose ("this is done", "a pending decision") stays untouched; only the ALL-CAPS/
## Title-case forms used as status flags are checked.

STATUS_RE <- "\\b(DONE|COMPLETE|Pending|TODO)\\b"

status_targets <- c(CLAUDE_MDS, file.path(ROOT, "code/facets-trellis/TRELLIS_FRAGILITY.md"))
status_targets <- status_targets[file.exists(status_targets)]

status_hits <- list()
for (f in status_targets) {
  lines <- live_prose_lines(f)
  hit_idx <- grep(STATUS_RE, lines)
  for (i in hit_idx) {
    status_hits[[length(status_hits) + 1]] <- list(file = f, line = i, text = trimws(lines[i]))
  }
}

if (length(status_hits)) {
  fail("FAIL (assertion 3 -- status confined to master): %d status token(s) outside the master:\n",
       length(status_hits))
  for (h in status_hits) {
    cat(sprintf("  %s:%d  %s\n", sub(paste0("^", ROOT, "/"), "", h$file), h$line, h$text))
  }
} else {
  ok("OK (assertion 3): no stray status tokens in CLAUDE.md files or TRELLIS_FRAGILITY.md\n")
}

## ── Assertion 4: asserted counts match reality ───────────────────────────────

read_baseline_len <- function(rel) {
  p <- file.path(ROOT, "tests/snapshots", rel)
  if (!file.exists(p)) return(NA_integer_)
  length(readRDS(p))
}

n_manuscript <- read_baseline_len("manuscript_values_baseline.rds")
n_figs       <- read_baseline_len("figure_hashes.rds")

artifact_file <- file.path(ROOT, "tests/snapshots/artifact_baseline.rds")
n_tbls <- if (file.exists(artifact_file)) {
  a <- readRDS(artifact_file)
  sum(grepl("^docs/table/", names(a$file_hashes)))
} else NA_integer_

n_claude_total <- length(CLAUDE_MDS)
n_claude_dirscoped <- n_claude_total - 1L   # minus the root CLAUDE.md

change_nums <- integer(0)
if (file.exists(file.path(ROOT, "CHANGES.md"))) {
  ch <- readLines(file.path(ROOT, "CHANGES.md"), warn = FALSE)
  m <- regmatches(ch, regexpr("^## Change ([0-9]+)", ch))
  change_nums <- as.integer(sub("^## Change ([0-9]+).*", "\\1", m))
}
n_latest_change <- if (length(change_nums)) max(change_nums) else NA_integer_

count_problems <- character(0)

WORDNUM <- c(one=1, two=2, three=3, four=4, five=5, six=6, seven=7, eight=8, nine=9,
             ten=10, eleven=11, twelve=12)
num_from_token <- function(tok) {
  if (grepl("^[0-9]+$", tok)) return(as.integer(tok))
  as.integer(unname(WORDNUM[tolower(tok)]))
}
count_mismatch <- function(tok, real) {
  n <- num_from_token(tok)
  is.na(n) || !isTRUE(n == as.integer(real))
}

NUMTOK <- "([0-9]+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)"

for (f in ALL_DOCS) {
  lines <- live_prose_lines(f)
  relf  <- sub(paste0("^", ROOT, "/"), "", f)
  full  <- paste(lines, collapse = " ")

  ## the historical bug: "379 target hashes" / "379 hashes" asserted as current truth.
  ## tests/CLAUDE.md is the doc that explains this history and is exempt from this
  ## specific check (it is quoting the stale phrase to describe why it is stale).
  if (relf != "tests/CLAUDE.md" &&
      grepl("[0-9]+\\s+(target\\s+)?hashes", full, ignore.case = TRUE) &&
      grepl("379", full)) {
    count_problems <- c(count_problems, sprintf(
      "%s: asserts the stale '379 target hashes' figure (real: %d/%d/%d)",
      relf, n_manuscript, n_figs, n_tbls))
  }

  for (i in seq_along(lines)) {
    line <- lines[i]
    for (mm in regmatches(line, gregexpr(
        paste0(NUMTOK, "\\s+manuscript values?"), line, ignore.case = TRUE))[[1]]) {
      tok <- sub(paste0("^", NUMTOK, ".*"), "\\1", mm, ignore.case = TRUE)
      if (count_mismatch(tok, n_manuscript)) {
        count_problems <- c(count_problems, sprintf(
          "%s:%d: '%s' does not match real count %d", relf, i, mm, n_manuscript))
      }
    }
    for (mm in regmatches(line, gregexpr(
        paste0(NUMTOK, "\\s+figure (PNGs?|hashes?)"), line, ignore.case = TRUE))[[1]]) {
      tok <- sub(paste0("^", NUMTOK, ".*"), "\\1", mm, ignore.case = TRUE)
      if (count_mismatch(tok, n_figs)) {
        count_problems <- c(count_problems, sprintf(
          "%s:%d: '%s' does not match real count %d", relf, i, mm, n_figs))
      }
    }
    for (mm in regmatches(line, gregexpr(
        paste0(NUMTOK, "\\s+table (files?|hashes?)"), line, ignore.case = TRUE))[[1]]) {
      tok <- sub(paste0("^", NUMTOK, ".*"), "\\1", mm, ignore.case = TRUE)
      if (count_mismatch(tok, n_tbls)) {
        count_problems <- c(count_problems, sprintf(
          "%s:%d: '%s' does not match real count %d", relf, i, mm, n_tbls))
      }
    }
    for (mm in regmatches(line, gregexpr(
        paste0(NUMTOK, "\\s+directory-scoped"), line, ignore.case = TRUE))[[1]]) {
      tok <- sub(paste0("^", NUMTOK, ".*"), "\\1", mm, ignore.case = TRUE)
      if (count_mismatch(tok, n_claude_dirscoped)) {
        count_problems <- c(count_problems, sprintf(
          "%s:%d: '%s' does not match real count %d", relf, i, mm, n_claude_dirscoped))
      }
    }
    for (mm in regmatches(line, gregexpr(
        paste0(NUMTOK, "\\s+CLAUDE\\.md files?"), line, ignore.case = TRUE))[[1]]) {
      tok <- sub(paste0("^", NUMTOK, ".*"), "\\1", mm, ignore.case = TRUE)
      if (count_mismatch(tok, n_claude_total)) {
        count_problems <- c(count_problems, sprintf(
          "%s:%d: '%s' does not match real count %d", relf, i, mm, n_claude_total))
      }
    }
    ## forward-looking: a doc claiming "Change N is the latest/most recent"
    for (mm in regmatches(line, gregexpr(
        "Change ([0-9]+)[^.]{0,25}(latest|most recent)|((latest|most recent)[^.]{0,25})Change ([0-9]+)",
        line, ignore.case = TRUE))[[1]]) {
      digs <- as.integer(regmatches(mm, regexpr("[0-9]+", mm)))
      if (!is.na(n_latest_change) && !identical(digs, n_latest_change)) {
        count_problems <- c(count_problems, sprintf(
          "%s:%d: '%s' does not match the real latest Change number %d",
          relf, i, mm, n_latest_change))
      }
    }
  }
}

if (length(count_problems)) {
  fail("FAIL (assertion 4 -- counts match reality): %d problem(s):\n", length(count_problems))
  for (p in unique(count_problems)) cat(sprintf("  %s\n", p))
} else {
  ok("OK (assertion 4): asserted counts (35/25/9, CLAUDE.md count, latest Change) match reality\n")
}

## ── Assertion 5: cards/INDEX.md matches card frontmatter ────────────────────

gen_script <- file.path(ROOT, "scripts/gen_card_index.R")

## Resolve uvr's interpreter from .r-version, the way Makefile does (ENV-23), instead of
## hardcoding an R.framework path. gen_card_index.R touches no Bioconductor, so either
## 4.5.3 install can run it -- but bare `Rscript` on this machine is 4.6.1, which the
## project .Rprofile's version guard rejects outright. Falling straight back to it made
## assertion 5 fail for a reason that has nothing to do with card drift. Order: uvr's R
## for this project's pinned version, then whatever R is running this script (guaranteed
## to satisfy the guard, since it got here), then PATH.
resolve_rscript <- function() {
  vf <- file.path(ROOT, ".r-version")
  if (file.exists(vf)) {
    ver <- trimws(readLines(vf, warn = FALSE)[1])
    uvr <- file.path(Sys.getenv("HOME"), ".uvr", "r-versions", ver, "bin", "Rscript")
    if (nzchar(ver) && file.exists(uvr)) return(uvr)
  }
  self <- file.path(R.home("bin"), "Rscript")
  if (file.exists(self)) return(self)
  "Rscript"
}
RSCRIPT <- resolve_rscript()

idx_res <- suppressWarnings(system2(RSCRIPT, c(shQuote(gen_script), "--check"),
                                     stdout = TRUE, stderr = TRUE))
idx_status <- attr(idx_res, "status")
if (is.null(idx_status)) idx_status <- 0L

if (idx_status != 0L) {
  fail("FAIL (assertion 5 -- cards/INDEX.md matches frontmatter):\n")
  cat(paste(" ", idx_res, collapse = "\n"), "\n")
} else {
  ok("OK (assertion 5): %s\n", trimws(paste(idx_res, collapse = " ")))
}

## ── Summary ───────────────────────────────────────────────────────────────────

if (pass) {
  cat("OK: verify_docs.R -- all five assertions pass\n")
  quit(status = 0)
} else {
  cat("FAIL: verify_docs.R found documentation drift (see above)\n")
  quit(status = 1)
}
