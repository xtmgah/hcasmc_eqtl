# command args: 
in_dir=$1
out_dir=$2
echo "input directory: $in_dir"
echo "output directory: $out_dir"

# in_dir=/srv/persistent/bliu2/HCASMC_eQTL/processed_data/eCAVIAR/eCAVIAR_input/
# out_dir=/srv/persistent/bliu2/HCASMC_eQTL/processed_data/eCAVIAR/eCAVIAR_output/


# path to 1000 Genome European sample IDs:
eur_sample=/srv/persistent/bliu2/HCASMC_eQTL/processed_data//eCAVIAR/eur_samples.txt
eqtl_vcf=/srv/persistent/bliu2/HCASMC_eQTL/processed_data/160604_phasing/phased_and_imputed_gprobs/phased_and_imputed.all.rename.dr2.hwe.indellt51.rnasample.GRCh37.rsid.vcf.new.gz


# loop over every SNP list: 
for snp_list in $(ls $in_dir/*.id); do
	base=$(basename $snp_list)
	# if [[ ! "$base" == "ENSG00000272097.1_RP11-421M1.8.id" ]]; then continue; fi # for debugging
	if [[ -f $out_dir/${base/.id/.ecaviar_col} ]]; then continue; fi
	echo "SNP list: $snp_list" 


	# decide what in_file is:
	i=$(head -n1 $snp_list | awk 'BEGIN{FS="_"}{print $1}')
	in_file=/srv/persistent/bliu2/shared/1000genomes/phase1v3/ALL.chr$i.integrated_phase1_v3.20101123.snps_indels_svs.genotypes.rsid.vcf.gz


	# split snp into chr and pos: 
	cat $snp_list | awk 'BEGIN{FS="_";OFS="\t"}{print $1,$2}' > ${snp_list}.tmp
	cat $eur_sample | awk '{print $1}' > $eur_sample.tmp


	# subset to relevant variants: 
	echo "#### subsetting 1000G vcf..."
	bcftools view -R ${snp_list}.tmp -S $eur_sample.tmp -Ov -o ${snp_list/.id/.gwas.vcf} $in_file

	echo "#### subsetting eQTL vcf..."
	bcftools view -R ${snp_list}.tmp -Ov -o ${snp_list/.id/.eqtl.vcf} $eqtl_vcf
	


	# remove vcf record longer than 16000 characters: 
	mv ${snp_list/.id/.gwas.vcf} ${snp_list/.id/.gwas.vcf.bak}
	cat ${snp_list/.id/.gwas.vcf.bak} | awk '{if (length($3)<=16000) print $0}' | uniq > ${snp_list/.id/.gwas.vcf}
	


	# generate bed bim fam:
	echo "#### generating bed, bim and fam files for GWAS..."
	plink --vcf ${snp_list/.id/.gwas.vcf} \
		--keep-allele-order \
		--make-bed \
		--double-id \
		--extract $snp_list \
		--out ${snp_list/.id/.gwas}


	echo "#### generating bed, bim and fam files for eQTL..."
	plink --vcf ${snp_list/.id/.eqtl.vcf} \
		--keep-allele-order \
		--make-bed \
		--double-id \
		--extract $snp_list \
		--out ${snp_list/.id/.eqtl}


	# remove variants from gwas and eqtl zscore file if they are not in the bim file: 
	mv ${snp_list/.id/.eqtl.zscore} ${snp_list/.id/.eqtl.zscore.bak}
	grep -f <(cut -f2,2 ${snp_list/.id/.eqtl.bim}) ${snp_list/.id/.eqtl.zscore.bak} > ${snp_list/.id/.eqtl.zscore}
	mv ${snp_list/.id/.gwas.zscore} ${snp_list/.id/.gwas.zscore.bak}
	grep -f <(cut -f2,2 ${snp_list/.id/.gwas.bim}) ${snp_list/.id/.gwas.zscore.bak} > ${snp_list/.id/.gwas.zscore}

	# calculate LD:
	echo "#### calculating LD for GWAS..."
	plink -bfile ${snp_list/.id/.gwas} \
		--r square \
		--out ${snp_list/.id/.gwas}

	echo "#### calculating LD for eQTL..."
	plink -bfile ${snp_list/.id/.eqtl} \
		--r square \
		--out ${snp_list/.id/.eqtl}


	# run eCAVIAR:
	echo "#### running eCAVIAR..."
	base=$(basename $snp_list)
	if [[ ! -d $out_dir ]]; then mkdir -p $out_dir; fi
	/srv/persistent/bliu2/tools/caviar/CAVIAR-C++/eCAVIAR \
		-o $out_dir/${base/.id/.ecaviar} \
		-l ${snp_list/.id/.gwas.ld} \
		-l ${snp_list/.id/.eqtl.ld} \
		-z ${snp_list/.id/.gwas.zscore} \
		-z ${snp_list/.id/.eqtl.zscore} \
		-r 0.95

	# cleanup: 
	rm ${snp_list/.id/.gwas.vcf.bak}
	rm ${snp_list/.id/.eqtl.zscore.bak}
	rm ${snp_list/.id/.gwas.zscore.bak}
	rm ${snp_list}.tmp
done



