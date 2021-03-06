unset DISPLAY XAUTHORITY

# Variables:
export annot_dir=/srv/persistent/bliu2/HCASMC_eQTL/processed_data/gwas_gene_overlap/ldscore_regression/tissue_specific_snp_annotation/
export plink_dir=/srv/persistent/bliu2/shared/ldscore/1000G_plinkfiles/
export hapmap_dir=/srv/persistent/bliu2/shared/ldscore/hapmap3_snps/
export out_dir=../processed_data/gwas_gene_overlap/ldscore_regression/ldscore/
export log_dir=../logs/gwas_gene_overlap/ldscore_regression/ldscore/
mkdir -p $out_dir $log_dir

# Functions: 
calc_ldscore(){
tissue=$1
chr=$2

echo INFO - $tissue
echo INFO - $chr

if [[ -e "$out_dir/$tissue.$chr.log" ]]; then
check_line=$(tail -n11 "$out_dir/$tissue.$chr.log" | head -n1)

if [[ $check_line == "Summary of Annotation Matrix Row Sums" ]]; then

echo "INFO - Already finished. Skipping."
return 0

fi

fi 

python ~/tools/ldsc/ldsc.py \
--l2 \
--bfile $plink_dir/1000G.mac5eur.$chr \
--ld-wind-cm 1 \
--annot "$annot_dir/$tissue.$chr.annot.gz" \
--out "$out_dir/$tissue.$chr" \
--print-snps $hapmap_dir/hm.$chr.snp

}

export -f calc_ldscore

# Get tissue names: 
ls $annot_dir/*22.annot.gz | sed "s/.22.annot.gz//" | sed "s:$annot_dir/::" | uniq | sort > $out_dir/tissue_list.txt


# Calculate LD score: 
parallel -j10 --joblog $log_dir/calc_ldscore.log calc_ldscore :::: $out_dir/tissue_list.txt ::: {1..22}
