#!/bin/bash

# get pod5 dir
pod5s=($(find $PWD/raw_data/*/*/ -type d -name "pod5"))

# out dir
out="$PWD/data"

for pod5 in ${pod5s[@]}; do
	
	# get name dir
	name=$(basename $(dirname $(dirname "${pod5}")))
	
	# run dorado basecaller
	dorado basecaller sup@v5.0.0 \
		--device "cuda:all" \
		--trim "adapters" \
		$pod5 > "$out/${name}/${name,,}_sup_v5_trim_no_filter.bam"
	
    samtools view -bh -e "[qs] >= 9" \
    "$out/${name}/${name,,}_sup_v5_trim_no_filter.bam" \
    > "$out/${name}/${name,,}_sup_v5_trim_filter_9.bam"


done

