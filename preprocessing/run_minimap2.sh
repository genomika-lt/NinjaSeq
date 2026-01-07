#!/bin/bash

# get refseqs
fastas=($(find "$PWD/references" -type f -name "*.fasta"))

# get ubams
ubams=($(find "$PWD/data" -type f -name "*5_trim_filter_9.bam"))

# loop over each BAM
for ubam in "${ubams[@]}"; do

    # parent folder
    out=$(dirname "$ubam")

    # sample name
    name=$(basename "$out")

    # init
    ref=""

    # pick reference
    for fasta in "${fastas[@]}"; do
        if [[ "$name" == BEGONIA_* && "$fasta" == *f1_data_after_indices_two_files.fasta ]]; then
            ref="$fasta"
            break
        elif [[ "$name" == CAMELLIA_007 || "$name" == CAMELLIA_008 ]] && [[ "$fasta" == *p2_design.fasta ]]; then
            ref="$fasta"
            break
        elif [[ "$name" == CAMELLIA_11 || "$name" == CAMELLIA_17 ]] && \
              [[ "$fasta" == *data_genomika_constrained_indexed.fasta ]]; then
            ref="$fasta"
            break
        fi
    done

    echo "ubam: $ubam"
    echo "out: $out"
    echo "name: $name"
    echo "ref: $ref"

    
    # run minimap2
    samtools fastq -@ 8 "$ubam" | \
      minimap2 -ax sr \
        -L --MD -t8 -Y --eqx \
        -k10 -w5 -m10 --secondary=yes \
        "$ref" - | \
      samtools view -u - | samtools sort -o "$out/${name,,}_trim_filter_9_mapped.bam"

    samtools index "$out/${name,,}_trim_filter_9_mapped.bam"


done
