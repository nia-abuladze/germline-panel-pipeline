#!/usr/bin/env bash
# Project 1 - build the workspace from scratch (all public data). Tested 16 Oct 2026 on
# Ubuntu 24.04, 2 CPUs: ~10-15 min, ~25 GB disk. Run from anywhere; data go next to scripts/.
# Then run 01_make_panel_bed.sh and 02_make_panel_fastq.sh.
set -euo pipefail
P=$(cd "$(dirname "$0")/.." && pwd); mkdir -p $P/{ref,annot,truth,tools,logs,fastq,work}; cd $P

# 1. Tools (Ubuntu 24.04 packages + GitHub releases)
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq samtools bcftools tabix bedtools bwa fastqc fastp \
  mosdepth picard-tools seqtk default-jre-headless unzip pigz > logs/apt.log
( cd tools
  curl -sSL -o gatk.zip https://github.com/broadinstitute/gatk/releases/download/4.6.2.0/gatk-4.6.2.0.zip && unzip -q gatk.zip && rm gatk.zip
  curl -sSL -o rtg.zip https://github.com/RealTimeGenomics/rtg-tools/releases/download/3.13/rtg-tools-3.13-nojre.zip && unzip -q rtg.zip && rm rtg.zip
  printf "RTG_TALKBACK=false\nRTG_USAGE=false\n" >> rtg-tools-3.13/rtg.cfg )

# 2. Reference: GRCh38 no-alt analysis set (NCBI) + prebuilt BWA index
B=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids
N=GCA_000001405.15_GRCh38_no_alt_analysis_set.fna
( cd ref
  curl -sS $B/$N.gz | gunzip > GRCh38.fa
  curl -sS $B/$N.fai -o GRCh38.fa.fai
  curl -sS $B/$N.bwa_index.tar.gz | tar -xz
  for e in amb ann bwt pac sa; do mv $N.$e GRCh38.fa.$e; done
  samtools dict GRCh38.fa -o GRCh38.dict
  ../tools/rtg-tools-3.13/rtg RTG_MEM=2g format -o GRCh38.sdf GRCh38.fa > ../logs/rtg_format.log )

# 3. Annotation: GENCODE v50 basic (Ensembl 116)
curl -sS -o annot/gencode.v50.basic.annotation.gtf.gz \
  https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_50/gencode.v50.basic.annotation.gtf.gz

# 4. Answer key: GIAB v4.2.1 GRCh38 benchmarks for the trio
G=https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio
( cd truth
  for s in HG002_NA24385_son HG003_NA24149_father HG004_NA24143_mother; do id=${s%%_*}
    for f in ${id}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz ${id}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi \
             ${id}_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed; do
      curl -sS -f -O $G/$s/NISTv4.2.1/GRCh38/$f; done; done )
echo "setup done"
