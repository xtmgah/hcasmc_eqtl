# 160725
# bosh liu
# find hcasmc specific genes:

# library:
library(gap)
library(qvalue)
library(DESeq2)
library(gplots)

# function:
# all functions moved to utils.R 


# read residuals: 
residuals=read.table('/srv/persistent/bliu2/HCASMC_eQTL/processed_data/160715/residuals.txt',check.names=F,row.names=1)


# get ranks of residuals: 
ranks=getRank(-residuals,dimension=1)


# load col_data:
col_data=read.table('/srv/persistent/bliu2/HCASMC_eQTL/processed_data/160715/col_data.txt',header=T)


# get ranks of HCASMC samples for each gene:
idx=which(col_data$tissue=='HCASMC')
rank_max=apply(ranks[,idx],1,max)


# get p-values:
N=nrow(col_data)
n=length(idx)
pvalue=getPvalue(rank_max,N,n)


# permutation pvalues:
M=length(rank_max)
random_rank_max=numeric(length=M)
set.seed(2)
for (i in 1:M) random_rank_max[i]=max(sample(1:510,10))
perm_pvalue=getPvalue(random_rank_max,N,n)



# make qqplot for p-values:
pdf('/srv/persistent/bliu2/HCASMC_eQTL/figures/160715/qqplot_pvalues.pdf')
qqunif(pvalue)
to_plot=qqunif(perm_pvalue,plot.it=F)
points(to_plot)
legend('topleft',legend=c('nominal','permuted'),col=c('blue','black'),pch=19)
dev.off()


# get q-values:
padjust=p.adjust(pvalue,method='BH')
sum(padjust<0.05) # 5151


# output pvalues:
temp=read.table('/srv/persistent/bliu2/HCASMC_eQTL/processed_data/160715/combined.count',header=T,check.names=F)%>%dplyr::select(gene_id=Name,gene_name=Description)
output=data.frame(gene_id=names(pvalue),pvalue=pvalue,padjust=padjust)
output=merge(output,temp,by='gene_id')
setcolorder(output,c('gene_id','gene_name','pvalue','padjust'))
output=output%>%arrange(pvalue)
write.table(output,file='/srv/persistent/bliu2/HCASMC_eQTL/processed_data/160715/hcasmc_specific_genes.txt',quote=F,row.names=F,sep='\t')