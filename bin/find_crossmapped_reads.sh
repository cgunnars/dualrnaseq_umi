#!/bin/bash

alignment=$1
extract_crossmapped_reads_script_path=$2
host_reference=$3
pathogen_reference=$4
out_name=$5


samtools view -F 4 -h $alignment | fgrep -vw NH:i:1 | $extract_crossmapped_reads_path/extract_crossmapped_reads.py -h_ref $host_reference -p_ref $pathogen_reference -o $out_name