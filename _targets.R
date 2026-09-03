## Created by use_targets().
## Follow the comments below to fill in this target script.
## Then follow the manual to check and run the pipeline:
##   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline
## Load packages required to define the pipeline:
library(targets)
library(tarchetypes) # Load other packages as needed.
library(conflicted)
conflicts_prefer(
  dplyr::select,
  dplyr::filter,
  dplyr::rename,
  dplyr::mutate,
  dplyr::summarize,
  dplyr::summarise,
  dplyr::count,
  dplyr::arrange,
  dplyr::desc,
  dplyr::lag,
  ggplot2::geom_rect,
  .quiet = TRUE
)
tar_option_set(packages=c("hallberg2025.base",
                          "hallberg2025.meth.data",
                          "SummarizedExperiment",
                          "tidyverse", "knitr",
                          "magrittr", "survival",
                          "ComplexHeatmap", "circlize",
                          "MASS"),
               imports="hallberg2025.base")
## Set target options:
## Functions are in the hallberg2025.base package (manuscript.R module, Phase 2 2026-06-23).
## Replace the target list below with your own:

## Mutations table (card MAN-01): consolidation logic (PGDx/Strelka Excel
## reports + Strelka reruns + private manifest -> canonical mutation calls)
## now lives in named, tested functions in hallberg2025.base/R/mutations.R
## (consolidate_mutation_calls()/build_mutations_tbl()), not inline in an
## edited-and-rerun Rmd. 12 WGS tumor samples -- CGOV463T, CGOV467T,
## CGOV469T, CGOV470T, CGOV471T, CGOV474T, CGOV477T, CGOV478T, CGOV480T,
## CGOV484T, CGOV485T, CGOV487T -- are deliberately excluded from the
## Strelka rerun calls; see hallberg2025.base::EXCLUDED_STRELKA_RERUN_SAMPLES
## for why (published-analysis reproducibility, not a bug).
##
## The private raw sources this needs (hallberg2025.base/inst/extdata/
## manifest.rds, extdata/mutation_reports/*.xlsx) are never published (root
## CLAUDE.md privacy table) and `output/` is dropped wholesale by
## scripts/build_public.sh, so this pipeline cannot unconditionally recompute
## mutations_tbl from raw sources and stay reproducible in the public
## release -- the same reason the facets.file/facets.wgs targets a few lines
## up are commented out rather than left as a hard dependency. When the
## private raw sources are present (this private repo), compute
## mutations_tbl in memory directly from them, so the computation is a real,
## versioned _targets.R target rather than a hand-rerun step; otherwise (a
## fresh public clone) fall back to the frozen, already-public
## extdata/mutations.tsv. Both paths were confirmed to produce byte-identical
## output when this target was ported -- see this card's Notes/log.
.man01_private_manifest <- here::here("hallberg2025.base", "inst", "extdata", "manifest.rds")
.man01_report_dir       <- here::here("extdata", "mutation_reports")
.man01_rerun_dir        <- here::here("extdata", "strelka_reruns")
mutations_targets <-
  if (file.exists(.man01_private_manifest) && dir.exists(.man01_report_dir)) {
    list(
      tar_target(private_manifest_file, .man01_private_manifest, format = "file"),
      tar_target(pgdx_report_file,
                 file.path(.man01_report_dir, "pgdx-compiled.xlsx"),
                 format = "file"),
      tar_target(strelka_report_file,
                 file.path(.man01_report_dir, "strelka-compiled.xlsx"),
                 format = "file"),
      tar_target(strelka_rerun_files,
                 list.files(.man01_rerun_dir, full.names = TRUE),
                 format = "file"),
      tar_target(mutations_tbl,
                 build_mutations_tbl(
                   report_dir = dirname(pgdx_report_file),
                   rerun_dir  = dirname(strelka_rerun_files[1]),
                   manifest   = readRDS(private_manifest_file)
                 ))
    )
  } else {
    list(
      tar_target(mut_file,
                 here::here("extdata", "mutations.tsv"),
                 format = "file"),
      tar_target(mutations_tbl, read_mutations(mut_file))
    )
  }

c(
list(
  tar_target(mfest, get_manifest()),
  tar_target(mfest.purity.g20, purity_filter(mfest)),
  tar_target(mfest.purity.l20, purity_exclusion(mfest)),
  tar_target(hmut, get_hypermut()),
  tar_target(abstract, summarize_subtypes(mfest, hmut)),
  tar_target(downstream, summarize_subtypes(mfest.purity.g20, hmut)),
  ## number of excluded samples by facets-trellis pipeline
  ##  tar_target(facets.file,
  ##             file.path("output",
  ##                       "facets-trellis",
  ##                       "summary-stats.txt"),
  ##             format="file"),
  ##  tar_target(facets.wgs, read_facets(facets.file)),
  tar_target(facets.missing, sum(is.na(mfest.purity.l20$purity))),
  tar_target(facets.low.purity, sum(mfest.purity.l20$purity <= 20, na.rm=TRUE)),
  ## figure 6 stats
  ## MAN-03: repointed from hallberg2025.base::get_methylation_se() (which reads
  ## the base-package's own methylation_se data object) to the hallberg2025.meth.data
  ## accessor. Filtering logic mirrors get_methylation_se()'s body exactly, so
  ## the resulting object is unchanged -- MET-02a confirmed the two source
  ## copies are digest-identical.
  tar_target(meth.se, {
    se <- hallberg2025.meth.data::methylation_se()
    keep <- colnames(se) %in% mfest.purity.g20$lab_id | se$study == "TCGA"
    se[, keep]
  }),
  tar_target(ncpg, nrow(meth.se)),
  tar_target(metadata, colData(meth.se)),
  tar_target(metadata_tcga, metadata[metadata$study == "TCGA", ]),
  tar_target(nsample_tcga, nrow(metadata_tcga)),
  tar_target(ntissue_tcga, table(metadata_tcga$diagnosis)),
  tar_target(nCMtcga, ntissue_tcga[["Colorectal mucinous"]]),
  tar_target(nSMtcga, ntissue_tcga[["Stomach mucinous"]]),
  tar_target(nUEtcga, ntissue_tcga[["Uterine endometrial"]]),
  tar_target(metadata_jhu, metadata[metadata$study == "JHU", ]),
  tar_target(ntissue_jhu, table(metadata_jhu$diagnosis)),
  tar_target(nOvEjhu, ntissue_jhu[["Ovarian endometrioid"]]),
  tar_target(nOMjhu, ntissue_jhu[["Ovarian mucinous"]]),
  tar_target(nCMjhu, ntissue_jhu[["Colorectal mucinous"]]),
  tar_target(nPMjhu, ntissue_jhu[["Pancreatic mucinous"]]),
  tar_target(nSMjhu, ntissue_jhu[["Stomach mucinous"]]),
  ## methylation_analysis.R
  tar_target(se.tcga, meth.se[, meth.se$study=="TCGA"]),
  tar_target(se.jhu, meth.se[, meth.se$study=="JHU"]),  
  tar_target(nt2, number_tcga_cancers(se.tcga)),
  tar_target(n.jhu, ncol(se.jhu)),
  tar_target(n.st.pan, sum(table(se.jhu$diagnosis)[c("Stomach mucinous", "Pancreatic mucinous")])),
  ## overall approach
  tar_target(n.wes.tumors, number_wes_tumors(mfest.purity.g20)),
  tar_target(n.wgs.tumors, number_wgs_tumors(mfest.purity.g20))
),
mutations_targets,
list(
  ## Supplemental tables — outputs built by wflow_build(); used by cellularity
  ## and read_stable() which expect the formatted TSV column layout.
  tar_target(s3file,
             file.path("docs", "table", "table_s4.Rmd",
                       "table_S4.tsv"),
             format="file"),
  tar_target(s4file,
             file.path("docs", "table", "table_s5.Rmd",
                       "table_S5.tsv"),
             format="file"),
  tar_target(del_file,
             file.path("docs", "table", "table_s8.Rmd", "table_S8.csv"),
             format = "file"),
  tar_target(amp_file,
             file.path("docs", "table", "table_s6.Rmd", "table_S6.tsv"),
             format = "file"),
  tar_target(wes_cnv_file,
             file.path("docs", "table", "table_s7.Rmd", "table_S7.tsv"),
             format = "file"),
  tar_target(cnv_wes, read_wes_cnv(wes_cnv_file)),
  tar_target(wgs_del, read_wgs_deletions(del_file)),
  tar_target(wgs_amp, read_wgs_amplicons(amp_file)),
  tar_target(mutation_spectra, build_mutation_spectra(mutations_tbl)),
  tar_target(marginal_frequencies,
             build_marginal_frequencies(mutations_tbl, cnv_wes, wgs_del, wgs_amp)),
  tar_target(mafs, cellularity(s3file, s4file)),
  ## purity not estimable or low cellularity
  tar_target(low.cell, length(unique(mfest.purity.l20$subject_id))),
  tar_target(percent.low.cell, round((abstract$N-low.cell)/abstract$N, 2)*100),
  ## coverage
  tar_target(s2file, file.path("docs", "table", "table_s2.Rmd",
                               "table_S2.csv"),
             format="file"),
  tar_target(dat, read_csv(s2file, show_col_types=FALSE)),
  tar_target(coverage, median_coverage(dat)),
  tar_target(wgs.coverage, coverage$median[coverage$Platform=="WGS"]),
  tar_target(wes.coverage, coverage$median[coverage$Platform=="WES"]),
  ## ch03
  tar_target(tumortypes, tumor_types(downstream$tumors)),
  tar_target(stab3, read_stable(s3file, tumortypes, mfest.purity.g20)),
  tar_target(stab4, read_stable(s4file, tumortypes, mfest.purity.g20)),
  tar_target(stab.endo, rbind_endo(stab3, stab4)),
  tar_target(mut.oall, mutations_overall(stab3, stab4, endo=TRUE)),
  ## correlation between tumor purity and number of mutations
  tar_target(spearman.cor, purity_numbermut(stab3, stab4, mfest.purity.g20)),
  tar_seed_set(9942),
  tar_target(drivers, get_drivers()),
  tar_target(e.cancers, endo_cancers()),
  tar_target(prop,
             prop_of_tumors_with_driver(stab.endo,
                                        mfest.purity.g20,
                                        drivers,
                                        e.cancers)),
  tar_target(drivers2,
             tibble(gene=c("TP53", "CTNNB1"))),
  tar_target(n.p53.ctnnb1,
             tumors_with_drivers2(stab.endo,
                                  mfest.purity.g20,
                                  drivers2,
                                  e.cancers)),
  ## ch04
  tar_target(esr1, get_esr1(stab3)),
  tar_target(n.esr1, number_esr1(esr1)),
  tar_target(n.hotspot, number_esr1_hotspots(esr1)),
  ## ch05
  tar_target(nmut, mucinous_mutations(stab3, stab4)),
  tar_target(crc.tumor, filter(nmut, lab_id=="CGCRC254T")),
  tar_target(ov.tumor, filter(nmut, lab_id=="CGOV167T")),
  ## cnv
  tar_target(idat.muc, get_idat_muc(mfest.purity.g20)),
  tar_target(erbb2, get_erbb2(idat.muc, downstream$tumors)),
  tar_target(erbb2.n.amp, erbb2_amp(erbb2)),
  tar_target(ccnd1, get_ccnd1(idat.muc)),
  tar_target(cdkn2, get_cdkn2(idat.muc)),
  tar_target(cdkn2a, filter(cdkn2, gene=="CDKN2A")),
  tar_target(n.cdkn2.mut, number_cdkn2a_mutations(cdkn2a)),
  tar_target(tumor.types2, unique_tumortypes(erbb2, ccnd1, cdkn2a)),
  tar_target(crc, get_crc_drivers(idat.muc)),
  tar_target(ncrc2, ifelse(nrow(crc)==0, "none", stop())),
  tar_target(total.crc, number_crc_not_hypermutated(idat.muc, hmut)),
  tar_target(crc.frac, paste0(nrow(crc), "/", total.crc)),
  tar_target(ci3, crc_credible_interval(crc, downstream$types2, n.cdkn2.mut)),
  ##
  ## integrative
  ##
  tar_target(cdkn2a.alt,
             unique_alterations(idat.muc,
                                "CDKN2A",
                                c("mutation", "deletion"))),
  tar_target(ccnd1.alt,
             unique_alterations(idat.muc,
                                "CCND1", "amplification")),
  tar_target(num.alt, nrow(cdkn2a.alt) + nrow(ccnd1.alt)),
  tar_target(cc.txt, paste0(num.alt, "/", downstream$types2["ovarian mucinous"])),
  tar_target(pct_, scales::percent(num.alt/downstream$types2["ovarian mucinous"])),
  tar_target(ras, ras_alterations(idat.muc)),
  tar_target(ci.ras, ras_prev_ci(ras, downstream$types2)),
  ##
  ## mutations:  Needs to be updated
  ##
  tar_target(gene_pathway_file, file.path("data", "gene.pathway.csv"),
             format="file"),
  tar_target(bfile, file.path("output", "07-figure5.rmd", "bayes.rds"),
             format="file"),
  ## while total number of ovarian mucinous is 50, 4 are hypermutators that are excluded
  ## in this analysis and 1 sample (483T) is not present in mutation data
  ## Should we drop 483T from Table S1
  tar_target(bayes, read_bayes(bfile)),
  tar_target(betas, filter(bayes, parameter=="beta")),
  tar_target(oe.v.ue, "Ovarian endometrioid vs Uterine endometrioid"),
  tar_target(om.v.gi, "Ovarian mucinous vs GI mucinous"),
  tar_target(cdkn2a.mean, -1*posterior_mean(betas, "CDKN2A", om.v.gi)),
  tar_target(cdkn2a.ci, cdkn2a_ci(betas)),
  tar_target(tp53.mean, -1*posterior_mean(betas, "TP53", om.v.gi)),
  tar_target(tp53.ci, tp53_ci(betas)),
  tar_target(kras.mean, -1*posterior_mean(betas, "KRAS", om.v.gi)),
  tar_target(kras.ci, kras_ci(betas)),
  tar_target(erbb2.mean, -1*posterior_mean(betas, "ERBB2", om.v.gi)),
  tar_target(erbb2.ci, erbb2_ci(betas)),
  tar_target(bayes.out, update_comparison_labels(bayes)),
  tar_target(betas2, filter(bayes.out, parameter=="beta")),
  tar_target(nsignif, number_signif_differences(betas2)),
  tar_target(rndm, number_signif_random(nsignif, alpha=0.1)),
  tar_target(p4plusin9, mean(rndm >= nsignif$nsignif[1])),
  tar_target(pval.p1plusin9, mean(rndm >= nsignif$nsignif[2])),
  tar_target(p1plusin9, paste0("= ", round(pval.p1plusin9, 3))),
  ##
  ## methylated
  ##
  tar_target(mfile, file.path("output", "ext-figures",
                              "ext-figure9.Rmd",
                              "prop_methylated.rds"),
             format="file"),
  tar_target(wilcox.results, prop_methylated_anova(mfile)),
  tar_target(anovastat, wilcox.results[["anovastat"]]),
  tar_target(minp, wilcox.results[["minp"]]),
  tar_target(Fstat, round(anovastat[[1]]$`F value`[1], 1)),
  tar_target(Fstat.p, round(anovastat[[1]]$`Pr(>F)`[1], 2)),
  ##
  ## pca
  ##
  tar_target(n.samples, ncol(meth.se)),
  tar_target(n.tcga, ncol(se.tcga)),
  tar_target(n.tcga.ue, table(se.tcga$diagnosis)["Uterine endometrial"]),
  tar_target(n.st, table(se.tcga$diagnosis)["Stomach mucinous"]),
  tar_target(n.crc, table(se.tcga$diagnosis)["Colorectal mucinous"]),
  tar_target(n.pa, table(se.tcga$diagnosis)["Pancreatic mucinous"]),
  ##
  ## lda / figure 6
  ##
  ## MAN-03: bare `methylation_se` used to resolve via library(hallberg2025.base)
  ## (tar_option_set packages=) lazy-loading the base package's own data
  ## object; repointed to the hallberg2025.meth.data accessor.
  tar_target(lda_samples,
             filter_lda_samples(hallberg2025.meth.data::methylation_se(),
                                here::here("extdata", "stomach_muc_signet.csv"))),
  tar_target(lda_model,
             fit_lda_model(lda_samples$se.tcga, n_pcs = 5L)),
  tar_target(tcga_lda_proj,
             project_tcga_to_lda(lda_model$ld, lda_model$features,
                                 lda_samples$se.tcga)),
  tar_target(lda_cancer_types,
             c("Pancreatic mucinous", "Colorectal mucinous",
               "Stomach mucinous", "Ovarian endometrioid", "Ovarian mucinous")),
  tar_target(jhu_lda_groups,
             project_jhu_to_lda(lda_samples$se.jhu, lda_model$pc, lda_model$ld,
                                tcga_lda_proj$obs, lda_cancer_types)),
  tar_target(probLDA,
             project_jhu_posteriors(lda_samples$se.jhu, lda_model$pc, lda_model$ld,
                                    lda_cancer_types) %>%
               mutate(across(where(is.numeric), ~signif(.x, 4))) %>%
               process_lda_posteriors(mfest)),
  tar_target(jhu_lda_fig,
             plot_jhu_lda(jhu_lda_groups, tcga_lda_proj$ell, mfest)),
  tar_target(tcga_lda_fig,
             plot_tcga_lda(tcga_lda_proj$obs, tcga_lda_proj$ell)),
  tar_target(tcga_heatmap,
             heatmap_setup(filter_lda_samples(
               hallberg2025.meth.data::methylation_se(),
               here::here("extdata", "stomach_muc_signet.csv"),
               exclude_tcga_diagnosis = NULL,
               jhu_tumor_only = FALSE
             )$se.tcga)),
  tar_target(jhu_heatmap,
             heatmap_setup(lda_samples$se.jhu)),
  tar_target(ov.muc, ovarian_muc_lda(probLDA)),
  tar_target(endo.like, endometrial_like(ov.muc)),
  tar_target(muc.like, mucinous_like(ov.muc)),
  ##
  ## figure 3 (circos / amplicon graphs / rearrangements)
  ## circos_data is pre-computed from private FACETS-trellis output;
  ## figure3_plot_data and figure3_grobs require trellis/ggbio/svplots.
  ##
  tar_target(circos_data,
             hallberg2025.seq.data::figure3_circos_data()),
  tar_target(tx_hg18, {
      library(trellis)
      library(svfilters.hg18)
      load_tx("hg18")
  }),
  tar_target(figure3_segments2,
             segs_to_granges(circos_data[["segments"]],
                             circos_data[["deletions"]])),
  tar_target(figure3_plot_data, {
      library(ggbio)
      library(trellis)
      library(svfilters.hg18)
      build_figure3_plot_data(circos_data, figure3_segments2, tx_hg18)
  }),
  tar_target(figure3_grobs, {
      library(trellis)
      library(svfilters.hg18)
      lab_id <- c("CGOV161T", "CGOV172T")
      h <- c(0.09, 1, 0.09, 1)
      circos.grobs <- gridExtra::arrangeGrob(
          grobs   = list(grid::nullGrob(),
                         figure3_plot_data$circos_list[[lab_id[1]]],
                         grid::nullGrob(),
                         figure3_plot_data$circos_list[[lab_id[2]]]),
          heights = h)
      ag.grobs <- gridExtra::arrangeGrob(
          grobs   = list(grid::nullGrob(),
                         figure3_plot_data$ag_figs[[lab_id[1]]],
                         grid::nullGrob(),
                         figure3_plot_data$ag_figs[[lab_id[2]]]),
          heights = h)
      list(circos.grobs   = circos.grobs,
           ag.grobs       = ag.grobs,
           rearrangements = build_figure3_rearrangements(circos_data[["rlist"]]),
           leg.list       = build_amplicon_legend(
               circos_data[["amplicon_graphs"]][lab_id], lab_id),
           lab_id         = lab_id)
  }),
  ##
  ## survival
  ##
  tar_target(clindat, get_clinical(mfest.purity.g20)),
  tar_target(idat.endo, get_idat_endo(mfest.purity.g20)),
  tar_target(n.surv, number_survival(clindat)),
  tar_target(cdat, summarize_wnt_pi3k(clindat, idat.endo,
                                      idat.muc)),
  tar_target(dat.oe, filter(cdat, tumor_type=="ovarian endometrioid")),
  tar_target(dat.om, filter(cdat, tumor_type=="ovarian mucinous")),
  tar_target(fit1, survfit(Surv(os, event) ~ pi3k, data=dat.oe)),
  tar_target(d1,  survdiff(Surv(os, event) ~ pi3k, data=dat.oe)),
  tar_target(pval1, round(d1$pvalue, 3)),
  tar_target(lr1, round(d1$chisq[[1]], 2)),
  tar_target(fit2, survfit(Surv(os, event) ~ pi3k, data=dat.om)),
  tar_target(d2, survdiff(Surv(os, event) ~ pi3k, data=dat.om)),
  tar_target(pval2, round(d2$pvalue, 3)),
  tar_target(lr2, round(d2$chisq[[1]], 2)),
  tar_target(fit.ctnnb1, survfit(Surv(os, event) ~ wnt, data=dat.oe)),
  tar_target(d3, survdiff(Surv(os, event) ~ wnt, data=dat.oe)),
  tar_target(pval.ctnnb1, round(d3$pvalue, 2)),
  tar_target(lr3, round(d3$chisq, 2)),
  tar_knit(manuscript, "manuscript/hallberg2025.Rtex",
           output_file="manuscript/hallberg2025.tex")
)
)
