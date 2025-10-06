results_dir=results_20240816 ##name of high-level directory with sub-directory fastq 
out_dir="$results_dir/fastqpr" ## output directory umi-extracted reads
if [ ! -d "$out_dir" ]; then
else
  echo "Directory '$out_dir' does not exist."
  mkdir -p "$out_dir"
  echo "Created directory '$out_dir'."
fi
fastq=$(ls $results_dir/fastq/*.fastq.gz | sort) 
while read r1 r2; do ## assumes paired end reads
        r1pr=$results_dir/fastqpr/$(basename "$r1"| cut -d. -f1).pr.fastq.gz
        r2pr=$results_dir/fastqpr/$(basename "$r2"| cut -d. -f1).pr.fastq.gz
        umi_tools extract --stdin=$r1 --read2-in=$r2 --bc-pattern=NNNNN --bc-pattern2=NNNNN --stdout=$r1pr --read2-out=$r2pr
done < <(echo $fastq | xargs -n2)
