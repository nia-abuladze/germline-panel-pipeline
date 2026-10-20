# Germline hereditary-cancer panel pipeline — validated on the GIAB Ashkenazi trio

A clinical-style germline NGS pipeline, **raw FASTQ → filtered, annotated VCF**, for a 14-gene hereditary-cancer panel. It is benchmarked against the Genome in a Bottle (GIAB) truth sets for the Ashkenazi trio: HG002 (son), HG003 (father) and HG004 (mother).

The point is the same as a lab validation: measure precision and recall against an independent answer key before trusting the pipeline on patients.

> Status: work in progress, built stage by stage (see [Progress](#progress)).

## Panel

| Syndrome | Genes |
|---|---|
| Hereditary breast & ovarian cancer | BRCA1, BRCA2, PALB2, ATM, CHEK2 |
| Lynch syndrome | MLH1, MSH2, MSH6, PMS2 |
| Li-Fraumeni / Cowden / hereditary diffuse gastric / Peutz-Jeghers / FAP | TP53, PTEN, CDH1, STK11, APC |

Targets are the coding exons of each gene's **MANE Select** transcript ± 20 bp, so the canonical splice sites are included. They come from GENCODE v50 (Ensembl 116): 256 intervals, 67 kb. The BED files in [`annot/`](annot/) are:

| File | Definition | Size | Used for |
|---|---|---|---|
| `panel_targets.bed` | CDS ± 20 bp | 67 kb | coverage QC, reporting |
| `panel_baits_100bp.bed` | targets ± 100 bp | 116 kb | simulated capture (read selection) |
| `panel_capture_300bp.bed` | targets ± 300 bp | 206 kb | benchmarking (wider region) |
| `panel_fetch_1500bp.bed` | targets ± 1.5 kb | 556 kb | download only (reads + mates) |

## Data

| What | Source |
|---|---|
| Reads | GIAB Ashkenazi trio, Illumina HiSeq 2500, 2×148 bp (NIST/NHGRI 300× GRCh38 alignments, NCBI FTP) |
| Reference | GRCh38 no-alt analysis set (NCBI), `chr`-prefixed names |
| Annotation | GENCODE v50 basic |
| Truth | GIAB NISTv4.2.1 benchmark VCF + confident-region BED, GRCh38, per sample |

Read pairs after simulated capture: HG002 262,533 · HG003 267,987 · HG004 290,126.

Truth variants inside the 67 kb coding targets: HG002 32 · HG003 39 · HG004 30. Inside the 206 kb capture regions: 190 · 217 · 171.

### Honest caveat: how the FASTQs were made

Aligning whole-genome FASTQs (hundreds of GB) is not possible on a 2-CPU workspace, so the panel data were **simulated from real reads**:

1. Every read pair with at least one read touching a bait (targets ± 100 bp) was taken from the public GIAB alignments.
2. Those pairs were converted back to raw paired FASTQ with `samtools fastq`. This restores the original read orientation and the soft-clipped bases.

From that point on the data behave like raw capture-panel reads. Two limits remain:

- The reads were pre-selected by another aligner (novoalign), so reads from distant paralogs are under-represented.
- WGS coverage is more uniform than hybrid capture, so capture and GC bias will look milder than in a real panel.

See [`scripts/02_make_panel_fastq.sh`](scripts/02_make_panel_fastq.sh).

## Pipeline

| Stage | Step | Tools |
|---|---|---|
| 1 | Raw-read QC, adapter/quality trimming (normal vs over-aggressive) | FastQC, fastp |
| 2 | Alignment with read groups; SAM vs BAM vs CRAM | BWA-MEM, samtools |
| 3 | Duplicate marking (PCR vs optical) | Picard MarkDuplicates |
| 4 | Coverage QC: mean/median depth, breadth at 20×/100×, uniformity, weakest exons | mosdepth |
| 5 | Variant calling: per sample, then GVCF + joint genotyping of the trio; Mendelian check | GATK 4.6.2.0 HaplotypeCaller, GenotypeGVCFs |
| 6 | Hard filtering; benchmark vs GIAB (precision, recall, F1) | GATK VariantFiltration, RTG Tools 3.13 vcfeval |
| 7 | Gene/exon annotation and report | bcftools, GENCODE |
| Bonus | In-silico tumour (20 % son into 80 % father) + somatic calling | GATK Mutect2 |

Pathway context for the panel genes (homologous recombination, mismatch repair and others): [docs/kegg-maps.md](docs/kegg-maps.md).

## Reproduce

Tested on Ubuntu 24.04 with 2 CPUs and 8 GB RAM. You need root for `apt-get` and about 25 GB of disk.

```bash
bash scripts/00_setup.sh          # tools, GRCh38 + BWA index, GENCODE, GIAB truth (~10-15 min)
bash scripts/01_make_panel_bed.sh # panel BED files
bash scripts/02_make_panel_fastq.sh   # trio panel FASTQs (~10 min)
```

Large data (FASTQ, BAM, reference, VCF) are not stored in this repository; see `.gitignore`.

## Progress

- [x] Setup: reference, panel BED, trio FASTQs, truth sets
- [ ] Stage 1: raw-read QC and trimming
- [ ] Stage 2: alignment
- [ ] Stage 3: duplicates
- [ ] Stage 4: coverage QC
- [ ] Stage 5: variant calling and joint genotyping
- [ ] Stage 6: filtering and benchmark
- [ ] Stage 7: annotation and report

## Data credits

- Genome in a Bottle Consortium, NIST. Zook et al., *Sci Data* 2016 (doi:10.1038/sdata.2016.25); Wagner et al., *Cell Genomics* 2022 (doi:10.1016/j.xgen.2022.100128) for v4.2.1.
- GENCODE: Frankish et al., *Nucleic Acids Res* 2021 (doi:10.1093/nar/gkaa1087).
- MANE: Morales et al., *Nature* 2022 (doi:10.1038/s41586-022-04558-8).
