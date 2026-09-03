all: tex pdf2

clean:
	rm *.aux *.log *.bbl *.dvi *.blg *.fls diff.*

showdiff:
	cd ../;	git show b7ea737:manuscript/hallberg_etal.tex > manuscript/cancer_research.tex
	latexdiff cancer_research.tex hallberg_etal.tex > diff.tex
	pdflatex diff.tex
	bibtex diff
	pdflatex diff
	pdflatex diff

## BROKEN AS WRITTEN, kept for reference: tag CancerResCommunications_2025-04
## contains manuscript/hallberg2.tex, not hallberg2025.tex (the rename happened
## after acceptance), so the `git show` below fails.  Use `make audit` from the
## repo root instead -- scripts/audit_manuscript.sh diffs against the *accepted*
## tag and also neutralizes the two known sources of non-scientific noise
## (the \bibliography{} filename and the commented-out \includegraphics lines).
diff:
	cd ../; git show CancerResCommunications_2025-09-accepted:manuscript/hallberg2.tex > manuscript/hallberg2_accepted.tex
	latexdiff hallberg2_accepted.tex hallberg2025.tex > diff_accepted.tex
	pdflatex diff_accepted
	bibtex diff_accepted
	pdflatex diff_accepted
	pdflatex diff_accepted


pdf:
	## Note: tar_make creates hallberg2025.tex
	cd ..; Rscript -e 'library(targets); tar_make()'
	pdflatex supplemental
	pdflatex hallberg2025
	bibtex hallberg2025
	pdflatex hallberg2025
	pdflatex hallberg2025


tex: hallberg2025.Rtex
	cd ..; Rscript -e 'library(targets); tar_make()'	

## For submission
pdf2: hallberg2025.Rtex
	## Note: tar_make creates hallberg2025.tex
	pdflatex hallberg2025
	bibtex hallberg2025
	pdflatex hallberg2025
	pdflatex hallberg2025

labdrive:
	mkdir -p to_submit;
	./to_submit.sh

labdir="~/Dropbox/Labs/CancerGenomicsLab/Projects/Ovarian_Subtypes/manuscript_2025/Resubmission\ Cancer\ Research\ Comm/to_submit"

tosubmit:
	mkdir -p to_submit
	cp fig*.eps to_submit/
	cp hallberg2025.tex to_submit/
	cp supplemental.pdf to_submit/
	cp diff_2025-04.pdf to_submit/
	cp supplemental_tables.xlsx to_submit/
	cp references.bib to_submit/

testsync:
	mkdir -p $labdir;
	rsync -nav to_submit/ $labdir/

sync:
	rsync -av to_submit/ $labdir/
