in_file=$1
out_file=$2
if [[ ! -d $(dirname $out_file) ]]; then mkdir $(dirname $out_file); fi
zcat $in_file | grep -v "gene_id" | awk 'BEGIN{FS="[\t_]";OFS="\t"} {print $1,$2,$3,$4,$5,$7,$8,$9,$10}' > $out_file