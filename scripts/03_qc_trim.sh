#!/usr/bin/env bash
# Project 1, Stage 1 - raw-read QC and the trimming experiment.
# Questions: P2, P3, P5, T17, T20, T21.
#
# Four fastp "arms" per sample; all go forward to alignment in Stage 2:
#   A adapter   - adapter trimming only (adapters found from read-pair overlap)
#   B tail20    - A + trim the 3' end back until a 4-bp window has mean Q >= 20; keep reads >= 50 bp
#   C window20  - A + sliding window from the 5' end, cut at the FIRST 4-bp window with mean Q < 20;
#                 keep reads >= 50 bp (same logic as Trimmomatic SLIDINGWINDOW:4:20)
#   D window30  - deliberately over-trimmed: sliding windows from both ends at mean Q30; keep reads >= 30 bp
# fastp's default read filter (drop reads with >40% bases below Q15, or >5 N) applies to every arm.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p qc/fastqc_raw qc/fastp trimmed
T=2

# 1. FastQC on raw reads
fastqc -q -t $T -o qc/fastqc_raw fastq/*_R[12].fastq.gz

# 2. fastp arms
declare -A ARM=(
  [A_adapter]=""
  [B_tail20]="--cut_tail --cut_tail_window_size 4 --cut_tail_mean_quality 20 --length_required 50"
  [C_window20]="--cut_right --cut_right_window_size 4 --cut_right_mean_quality 20 --length_required 50"
  [D_window30]="--cut_front --cut_right --cut_window_size 4 --cut_mean_quality 30 --length_required 30"
)
for S in HG002 HG003 HG004; do
  for A in A_adapter B_tail20 C_window20 D_window30; do
    # shellcheck disable=SC2086
    fastp -w $T -i fastq/${S}_R1.fastq.gz -I fastq/${S}_R2.fastq.gz \
          -o trimmed/${S}_${A}_R1.fastq.gz -O trimmed/${S}_${A}_R2.fastq.gz \
          --detect_adapter_for_pe ${ARM[$A]} \
          -j qc/fastp/${S}_${A}.json -h qc/fastp/${S}_${A}.html 2> qc/fastp/${S}_${A}.log
  done
done
echo "stage 1 done"
