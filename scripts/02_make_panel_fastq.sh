#!/usr/bin/env bash
# Project 1 - create "panel sequencing" FASTQs for the GIAB Ashkenazi trio.
#
# Honest note (say this in the interview if asked):
#   We cannot afford to align whole-genome FASTQs (hundreds of GB) on a 2-CPU workspace,
#   so we take the public GIAB 300x Illumina HiSeq 2x148 alignments and imitate hybrid capture:
#   keep every read PAIR in which at least one read touches a bait (targets +/- 100 bp),
#   then turn those pairs back into raw paired FASTQ.
#   samtools fastq restores the original read orientation and the soft-clipped bases,
#   so from here on the data behave like raw reads from a capture panel.
#   Caveats: (1) reads were pre-selected by someone else's aligner, so reads from distant
#   paralogs are under-represented; (2) WGS coverage is more even than real capture,
#   so capture/GC bias (P15, T24) will look milder than in a real panel.
#
# Source: GIAB, NIST HiSeq 2500 2x148, NHGRI novoalign GRCh38 BAMs (public, NCBI FTP).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p fastq logs work

BASE=https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio
declare -A BAM=(
  [HG002]=$BASE/HG002_NA24385_son/NIST_HiSeq_HG002_Homogeneity-10953946/NHGRI_Illumina300X_AJtrio_novoalign_bams/HG002.GRCh38.300x.bam
  [HG003]=$BASE/HG003_NA24149_father/NIST_HiSeq_HG003_Homogeneity-12389378/NHGRI_Illumina300X_AJtrio_novoalign_bams/HG003.GRCh38.300x.bam
  [HG004]=$BASE/HG004_NA24143_mother/NIST_HiSeq_HG004_Homogeneity-14572558/NHGRI_Illumina300X_AJtrio_novoalign_bams/HG004.GRCh38.300x.bam
)

for S in HG002 HG003 HG004; do
  echo "[$S] 1/3 downloading reads in fetch regions (targets +/- 1500 bp)"
  # -F 0x900 : drop secondary (0x100) and supplementary (0x800) records so each read appears once
  samtools view -b -F 0x900 -M -L annot/panel_fetch_1500bp.bed -o work/${S}_fetch.bam "${BAM[$S]}"
  samtools index work/${S}_fetch.bam

  echo "[$S] 2/3 choosing pairs that touch a bait"
  samtools view -L annot/panel_baits_100bp.bed work/${S}_fetch.bam | cut -f1 | sort -u > work/${S}_names.txt

  echo "[$S] 3/3 writing paired FASTQ"
  samtools view -u -N work/${S}_names.txt work/${S}_fetch.bam \
   | samtools collate -u -O - work/tmp_$S \
   | samtools fastq -1 fastq/${S}_R1.fastq.gz -2 fastq/${S}_R2.fastq.gz \
                    -s /dev/null -0 /dev/null -c 6 - 2> logs/fastq_$S.log
  echo "[$S] pairs: $(( $(zcat fastq/${S}_R1.fastq.gz | wc -l) / 4 ))   $(grep -o 'discarded [0-9]* singletons' logs/fastq_$S.log)"
done
