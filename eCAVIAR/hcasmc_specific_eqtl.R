# library: 
library(data.table)
library(dplyr)
library(stringr)
library(cowplot)


# command args: 
args=commandArgs(T)
in_file=args[1]
fig_dir=args[2]
out_file1=args[3]
out_file2=args[4]
tissue=args[5]
in_file='/srv/persistent/bliu2/HCASMC_eQTL/processed_data/160805/metasoft_output_subsample_52/metasoft_output.6.mcmc.txt'
# fig_dir='../figures/hcasmc_specific_eqtl/Liver/'
# out_file1='../processed_data/hcasmc_specific_eqtl/Liver/stat.chr20.txt'
# out_file2='../processed_data/hcasmc_specific_eqtl/Liver/tissue_specific_eqtl.chr20.txt'
# tissue='Liver'

# constants: 
N_TISSUE=45


# read metasoft result: 
header=scan(in_file,what='character',nlines=1,sep='\t')
metasoft=fread(in_file,skip=1)


# remove the extra column (issue due to white space)
metasoft[,V107:=NULL]
# n_col=ncol(metasoft) 
# metasoft=metasoft[,1:(n_col-1),with=F]


# read tissue name (study name):
study_name=unlist(fread('/srv/persistent/bliu2/HCASMC_eQTL/processed_data/160805/Metasoft_tissue_order.alphabetical.txt',header=F))


# set metasoft column names:
col_names=c(paste('pvalue',study_name,sep='_'),paste('mvalue',study_name,sep='_'))
col_names=c(header[1:16],col_names)
stopifnot(ncol(metasoft)==length(col_names))
setnames(metasoft,col_names)


# subset to mvalues: 
mvalue=metasoft%>%dplyr::select(contains('mvalue'))%>%as.data.frame()
stopifnot(ncol(mvalue)==N_TISSUE)
rownames(mvalue)=metasoft$RSID
colnames(mvalue)=str_replace(colnames(mvalue),'mvalue_','')



# subset to pvalues: 
pvalue=metasoft%>%dplyr::select(contains('pvalue'))%>%dplyr::select(-c(1:5))%>%as.data.frame()
rownames(pvalue)=metasoft$RSID
colnames(pvalue)=str_replace(colnames(mvalue),'pvalue_','')

rownames(mvalue)
which(rownames(mvalue)=='ENSG00000118526.6_6_134206805_A_G_b37')
which(rownames(mvalue)=='ENSG00000118526.6_6_134209837_T_C_b37')

mvalue[which(rownames(mvalue)=='ENSG00000118526.6_6_134206805_A_G_b37'),]
plot(mvalue[which(rownames(mvalue)=='ENSG00000118526.6_6_134206805_A_G_b37'),]%>%unlist(),-log10(pvalue[which(rownames(pvalue)=='ENSG00000118526.6_6_134206805_A_G_b37'),])%>%unlist())
text(mvalue[which(rownames(mvalue)=='ENSG00000118526.6_6_134206805_A_G_b37'),]%>%unlist(),-log10(pvalue[which(rownames(pvalue)=='ENSG00000118526.6_6_134206805_A_G_b37'),])%>%unlist(),colnames(mvalue))
# select rows where HCASMC has maximum m-value: 
is_max_mval=(mvalue[,tissue]==apply(mvalue,1,max,na.rm=T))
# there will be warning about -Inf values due to the fact that only 1 tissue has zscore/pvalue for the SNP-gene pair. 
# it can be ignored safely. 


# select rows where HCASMC has m-value >= 0.9:
is_eqtl=mvalue[,tissue]>=0.9


# select rows where GTEx tissues all have m-values < 0.9:
col_idx=which(colnames(mvalue)==tissue)
max_mval_besides_this_tissue=apply(mvalue[,-col_idx],1,max,na.rm=T)
is_not_eqtl_besides_this_tissue=max_mval_besides_this_tissue<0.9


# select hcasmc-specific eQTLs:
tissue_specific_eqtl_idx=which(is_eqtl&is_max_mval&is_not_eqtl_besides_this_tissue)
n_spec_eqtl=length(tissue_specific_eqtl_idx)
message(paste0(n_spec_eqtl,'/',length(which(is_eqtl)),' tissue specific eqtls.'))
# output1=data.frame(tissue=tissue,n_spec_eqtl=n_spec_eqtl,n_eqtl=length(is_eqtl))
output1=data.frame(tissue=tissue,n_spec_eqtl=n_spec_eqtl,n_eqtl=length(which(is_eqtl)))
if (!dir.exists(dirname(out_file1))) dir.create(dirname(out_file1))
write.table(output1,file=out_file1,quote=F,sep='\t',row.names=F,col.names=F)


# make PM plot:
if (!dir.exists(fig_dir)) dir.create(fig_dir)
for (idx in tissue_specific_eqtl_idx){
	to_plot=data.frame(mvalue=unlist(mvalue[idx,]),pvalue=-log10(unlist(pvalue[idx,])))
	to_plot$tissue=rownames(to_plot)
	p=ggplot(to_plot,aes(mvalue,pvalue,label=tissue))+geom_point()+geom_text(angle=45)+theme_bw()+geom_vline(xintercept=0.9,color='red',linetype='dashed')
	save_plot(paste0(fig_dir,'/',rownames(mvalue[idx,]),'.pdf'),p,base_width=6,base_height=6)
}


# write hcasmc-specific eQTL to text file: 
output2=as.data.frame(str_split_fixed(names(tissue_specific_eqtl_idx),"_",n=2))
setnames(output2,c('pid','sid'))
write.table(output2,file=out_file2,sep='\t',row.names=F,quote=F,col.names=F)