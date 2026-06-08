#!/bin/bash

# get ubams 
ubams=($(find "$PWD/data" -type f -name "*5_no_trim_filter_9.bam"))

# out dir
out="$PWD/data/trimmed_len_ont/"
mkdir -p "$out"

for ubam in "${ubams[@]}"; do
    name=$(basename "$ubam" .bam)
    echo "processing $name..."

    samtools fastq -@ 6 "$ubam" \
    | cutadapt \
	-g CCTGTACTTCGTTCAGTTACGTATTGCT \
	--cores 8 \
	--overlap 8 \
	--error-rate 0.25 \
	--revcomp \
	--discard-untrimmed \
	--minimum-length 190 \
	--output "$out/${name,,}_trimmed_ont.fastq.gz" \
	- > "$out/${name,,}_cutadapt.log"

done

