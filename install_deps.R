#!/usr/bin/env Rscript
## Bootstrap this project's dependencies via uvr (see ENV-10 in cards/).
## Equivalent of the old renv::restore() step, but declare-first: every
## package this project needs is already recorded in uvr.toml/uvr.lock,
## so this script only needs to (1) make sure the `uvr` CLI and the R
## version it's pinned to exist, (2) sync the lockfile into .uvr/library,
## and (3) install the two local-source companion packages that uvr has
## no mechanism for declaring (hallberg2025.meth.data, hallberg2025.seq.data -- both ship
## "Source": "unknown" in the old renv.lock, i.e. always installed from
## the local tree, never from a repository or GitHub remote).

uvr_bin <- Sys.which("uvr")
if (uvr_bin == "") {
  candidate <- path.expand("~/.local/bin/uvr")
  if (file.exists(candidate)) {
    uvr_bin <- candidate
  } else {
    message("uvr not found; installing via its published install.sh ...")
    status <- system("curl -fsSL https://raw.githubusercontent.com/nbafrank/uvr/main/install.sh | sh")
    if (status != 0) stop("uvr install.sh failed (exit ", status, ")")
    uvr_bin <- candidate
  }
}
message("Using uvr at: ", uvr_bin)

run_uvr <- function(...) {
  args <- c(...)
  status <- system2(uvr_bin, args)
  if (status != 0) stop("uvr ", paste(args, collapse = " "), " failed (exit ", status, ")")
  invisible(status)
}

## Homebrew's Apple-Silicon prefix isn't on the system clang's default search
## path, unlike the officially-distributed CRAN framework R build -- without
## this, compiled packages that need a Homebrew system library (e.g. git2r ->
## libgit2 -> llhttp) fail to link under uvr's managed R. Harmless no-op on a
## system without Homebrew (brew_prefix stays "").
brew_prefix <- tryCatch(
  suppressWarnings(system("brew --prefix", intern = TRUE, ignore.stderr = TRUE)),
  error = function(e) character(0)
)
if (length(brew_prefix) == 1 && nzchar(brew_prefix) && dir.exists(brew_prefix)) {
  Sys.setenv(
    LDFLAGS = paste("-L", file.path(brew_prefix, "lib"), sep = ""),
    CPPFLAGS = paste("-I", file.path(brew_prefix, "include"), sep = "")
  )
}

## uvr.toml pins R 4.5.3 and .r-version already records it (see uvr.toml,
## .r-version); `uvr sync` installs that R version on demand if it isn't
## already present, so no separate `uvr r install` call is needed here.
run_uvr("sync")

## Install the two local companion packages uvr's dependency graph doesn't
## cover, into the same project library uvr just synced.
uvr_r <- Sys.which("Rscript")
r_home_candidates <- suppressWarnings(system2(uvr_bin, c("r", "list"), stdout = TRUE))
message(paste(r_home_candidates, collapse = "\n"))
managed_rscript <- path.expand("~/.uvr/r-versions/4.5.3/bin/Rscript")
rscript_bin <- if (file.exists(managed_rscript)) managed_rscript else uvr_r

local_pkgs <- c("hallberg2025.meth.data", "hallberg2025.seq.data")
status <- system2(
  sub("Rscript$", "R", rscript_bin),
  c("CMD", "INSTALL", "--library=.uvr/library", local_pkgs)
)
if (status != 0) stop("R CMD INSTALL failed for ", paste(local_pkgs, collapse = ", "))

message("Dependencies installed. Run `Rscript tests/verify_snapshot.R` to confirm the gate passes.")
