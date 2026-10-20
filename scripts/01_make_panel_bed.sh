#!/usr/bin/env bash
# Project 1 - build the target BED for a 14-gene hereditary-cancer panel.
# Source: GENCODE v50 basic annotation (Ensembl 116), MANE Select transcript per gene.
# Targets = coding exons (CDS) +/- 20 bp, so canonical splice sites are inside the target.
#
# COORDINATES (interview question F11):
#   GTF is 1-based, closed:      exon at GTF 100..200 covers bases 100,101,...,200
#   BED is 0-based, half-open:   the same bases are written 99..200
#   So: BED_start = GTF_start - 1 ; BED_end = GTF_end
set -euo pipefail
cd "$(dirname "$0")/../annot"

GENES='BRCA1|BRCA2|TP53|PALB2|ATM|CHEK2|MLH1|MSH2|MSH6|PMS2|APC|PTEN|CDH1|STK11'
PAD=20

zcat gencode.v50.basic.annotation.gtf.gz \
 | awk -F'\t' '$3=="CDS" && $9 ~ /tag "MANE_Select"/' \
 | grep -E "gene_name \"($GENES)\";" > panel_mane_cds.gtf

# GTF -> BED (note the -1 on the start), add padding, name each interval GENE_exonN
awk -F'\t' -v pad=$PAD 'BEGIN{OFS="\t"}{
    match($9,/gene_name "[^"]+"/);   g=substr($9,RSTART+11,RLENGTH-12)
    match($9,/exon_number [0-9]+/);  e=substr($9,RSTART+12,RLENGTH-12)
    s=$4-1-pad; if(s<0) s=0
    print $1, s, $5+pad, g"_exon"e
}' panel_mane_cds.gtf \
 | sort -k1,1V -k2,2n \
 | bedtools merge -i - -c 4 -o distinct > panel_targets.bed

# "Bait" regions = targets +/- 100 bp. In hybrid capture, any DNA fragment that overlaps a
# bait is pulled down, so reads (and their mates) can extend well beyond the bait.
bedtools slop -i panel_targets.bed -g ../ref/GRCh38.fa.fai -b 100 \
 | bedtools merge -i - > panel_baits_100bp.bed

# Wider "capture" regions (+/- 300 bp): the area where we expect useful depth; used for benchmarking.
bedtools slop -i panel_targets.bed -g ../ref/GRCh38.fa.fai -b 300 \
 | bedtools merge -i - > panel_capture_300bp.bed

# "Fetch" regions (+/- 1500 bp): only used to download reads AND their mates from the GIAB BAMs.
bedtools slop -i panel_targets.bed -g ../ref/GRCh38.fa.fai -b 1500 \
 | bedtools merge -i - > panel_fetch_1500bp.bed

for b in panel_targets panel_baits_100bp panel_capture_300bp panel_fetch_1500bp; do
  printf "%-22s %4d intervals %8d bp\n" $b $(wc -l < $b.bed) $(awk '{s+=$3-$2}END{print s}' $b.bed)
done
