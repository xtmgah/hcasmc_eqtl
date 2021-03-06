library(stringr)
library(cowplot)
library(data.table)
#------ 160715 -----
#' format the result of DESeq2
#' @param res result from DESeq2
#' @param row_data contains two columns, gene_id and gene_name
#' @return a `data.table` ordered by pvalue. 
format_result=function(res,row_data){
	# cast result into data.table:
	res2=data.table(as.data.frame(res),keep.rownames=T)
	setnames(res2,'rn','gene_id')


	# add gene_name column to result: 
	res3=merge(res2,row_data,by='gene_id',all.x=T)
	setcolorder(res3,c(1,ncol(res3),2:(ncol(res3)-1)))


	# sort result by pvalue:
	resOrdered=res3%>%arrange(pvalue)


	# return: 
	return(resOrdered)
}


#' decompose a gct count file:
#' a gct count files' first and second columns are ENSEMBL ID and gene name
#' @return res (list) with three elements: count, col_data and row_data 
decompose_gct=function(gct){
	gct=as.data.frame(gct)
	row_data=gct[,1:2]
	col_data=data.frame(sample=colnames(gct[,-c(1,2)]))
	count=gct[,-c(1,2)]
	rownames(count)=gct[,1]
	res=list(count=count,col_data=col_data,row_data=row_data)
	return(res)
}

#' subsample a gct dataframe 
#' @param size (integer) the number of samples to keep
#' @return subsampled gct dataframe 
subsample_gct=function(gct,size,seed=1){
	set.seed(seed)
	gct=as.data.frame(gct)
	samples=colnames(gct)[-c(1,2)]
	selected_samples=sample(samples,size)
	selected_samples=c(colnames(gct)[c(1,2)],selected_samples)
	gct=gct[,selected_samples]
	return(gct)
}


#' rank values by row or column
#' @param x (matrix) matrix of values to be ranked 
#' @param dimension 1 (row-wise) or 2 (column-wise)
getRank=function(x,dimension=1){
	stopifnot(dimension%in%c(1,2))
	ranks=matrix(0,nrow=nrow(x),ncol=ncol(x),dimnames=list(rownames(x),colnames(x)))
	if (dimension==1){
		M=nrow(x)
		for (i in 1:M){
			ranks[i,]=rank(x[i,],ties.method='random')
		}
	} else {
		N=ncol(x)
		for (j in 1:N){
			ranks[,j]=rank(x[,j],ties.method='random')
		}
	}
	return(ranks)
}


#' calculate p-value for a test of ranked values
#' Given a list of N numbers 1:N and a second list of n numbers L,
#' what is the probability that the maximum member of an arbitrary list 
#' of lengh n does not exceed the maximum memeber of the list L
#' p=choose(max(L),n)/choose(N,n)
#' @param rank_max (integer()) a list of ranks
#' @param N (integer) the total number of ranks
#' @paran n (integer) the length of list L
#' @return pvalue
getPvalue=function(rank_max,N,n){
	M=length(rank_max)
	pvalue=numeric(length=M)
	names(pvalue)=names(rank_max)
	total_combination=choose(N,10)
	for (i in 1:M){
		pvalue[i]=choose(rank_max[i],10)/total_combination
	}
	return(pvalue)
}

#------ 160527 -----
#' inverse rank normalization
getInverseNormal <- function(x){
	x <- as.numeric(x)
	xx2<-qnorm((rank(x,na.last = "keep") - 0.5) / sum(!is.na(x)))
	return(xx2)
}

#------ 30_compare_9052004_samples.R ------
#' make pairs upper panel show correlation:
#' taken from help file of pairs()
panel.cor <- function(x, y, digits = 2, prefix = "", cex.cor, ...)
{
    usr <- par("usr"); on.exit(par(usr))
    # par(usr = c(0, 1, 0, 1))
    par(usr = c(0, 1, 0, 1), xlog = FALSE, ylog = FALSE)

    r <- abs(cor(x, y))
    txt <- format(c(r, 0.123456789), digits = digits)[1]
    txt <- paste0(prefix, txt)
    if(missing(cex.cor)) cex.cor <- 0.8/strwidth(txt)
    text(0.5, 0.5, txt, cex = cex.cor * r)
}


#------ convert_imput2_output_to_genotype.R -----
#' convert impute2 output to genotype:
#' @param impute2 (data.table(i,j)) impute2 output
#' @return genotypes (matrix(i,(j-5)/3)) genotypes
convImpute2ToGeno=function(impute2){
	n_samples=(ncol(impute2)-5)/3
	stopifnot(as.integer(n_samples)==n_samples)
	n_snps=nrow(impute2)
	genotypes=matrix(ncol=n_samples,nrow=n_snps)
	colnames(genotypes)=1:n_samples
	for (j in seq(1,n_samples)){
		temp=impute2[,((j-1)*3+1+5):(j*3+5),with=F]
		genotypes[,j]=max.col(temp)-1
	}
	return(genotypes)
}


#' report error if multi-allelic sites are found. 
#' @param genotypes (data.table) genotypes with samples as columns and variants as rows
#' @return reports error and aborts if multi-allelic loci are found. 
detectMultiAllelicLoci = function(genotypes){
	genotypes_long = melt(genotypes, id.vars = c('CHROM','POS'), variable.name = 'ID', value.name = 'genotype')
	genotype_list = names(table(genotypes_long$genotype))
	if (!all(genotype_list %in% c('0/0','0/1','1/1','0|0','0|1','1|0','1|1'))) {
		stop('multi-allelic loci found!')
	} else {
		message('no multi-allelic loci.')
	}
}


#' remove multi allelic loci (e.g. 0/2, 1/2)
#' @param genotypes (data.table) genotypes with samples as columns and variants as rows
#' @return (data.table) genotypes with only the following genotypes: 0/0, 0/1, 1/1, 0|0, 0|1, 1|0, 1|1. 
removeMultiAllelicLoci = function(genotypes){
	genotypes_long = melt(genotypes, id.vars = c('CHROM','POS'), variable.name = 'sample', value.name = 'genotype')
	genotype_counts = table(genotypes_long$genotype)
	all_genotypes = names(genotype_counts)
	multiallelic_genotypes = all_genotypes[!all_genotypes %in% c('0/0','0/1','1/1','0|0','0|1','1|0','1|1')]

	for (s in multiallelic_genotypes){
		multi = unique(which(genotypes == s, arr.ind = T)[,'row'])
		if (length(multi) == 0){
			message(sprintf("%s not found in the remaining loci",s))
		} else {
			genotypes = genotypes[-multi,]
		}
	}
	return(genotypes)
}




#' convert genotypes to dosages
#' @param genotypes (data.table) genotypes with samples as columns and variants as rows; should only have biallalic variants (e.g. 0/0, 0/1, 1/1); the first and second columns should be 'CHROM' and 'POS'. 
#' @return (numeric matrix) dosages correspond to the genotypes; 'CHROM' and 'POS' column are turned into rownames. 
genotypeToDosage = function(genotypes){
	stopifnot('data.table' %in% class(genotypes))
	for (s in c('0/2','1/2','2/2','0|2','2|0','1|2','2|1','2|2')) {stopifnot(length(which(genotypes == s)) == 0)}
	# genotype_long = melt(data = genotypes, id.vars = c('CHROM','POS'))
	dosages = matrix(0, nrow = nrow(genotypes), ncol = ncol(genotypes))
	colnames(dosages) = colnames(genotypes)
	rownames(dosages) = genotypes[,paste(CHROM, POS, sep = '_')]
	for (s in c('0/0','0/1','1/1','0|0','0|1','1|0','1|1')){
		dosage = as.integer(strsplit(s, split = "/|\\|")[[1]])
		dosage = sum(dosage)
		idx = which(genotypes == s)
		dosages[idx] = dosage
	}
	dosages = dosages[,!(colnames(dosages) %in% c('CHROM','POS'))]
	return(dosages)
}



#' remove missing genotypes
#' @param genotypes (data.table) genotypes with samples as columns and variants as rows
#' @return genotypes but rows with missing values (i.e. ./.) are removed 
removeMissingGenotypes = function(genotypes){
	missing = unique(which(genotypes == "./.", arr.ind=T)[,'row'])
	stopifnot(length(unique(missing)) == length(missing))
	if (length(missing) == 0) {
		message('no missing genotypes')
	} else {
		genotypes = genotypes[-missing,]
	} # remove rows with missing genotypes
	return(genotypes)
}

#' read sample list
#' @param filename (character) a file with one line per sample
#' @return (character vector) of samples
readSampleList = function(filename){
	sample_list = read.table(filename, header = FALSE, stringsAsFactors = FALSE)
	sample_list = unlist(sample_list)
	stopifnot(class(sample_list) == 'character')
	return(sample_list)
}

#' calculate reference ratio 
#' @param sample (data.table) table with columns refCount, refCount, totalCount, other columns will be ignored. 
#' @return a data.table with an addition column refRatio
calcRefRatio = function(sample){
	stopifnot('data.table' %in% class(sample))
	sample[, refRatio := refCount/totalCount]
	return(sample[])
}


#' @param assays (data.table) table with columns ID (variant ID), type (alt, ref or totalCount), and count. 
#' @param sample_name the name of the sample
#' @return a wide data.table with columns ID, refCount, altCount, totalCount 
getSample = function(assays, sample_name){
	stopifnot('data.table' %in% class(assays))
	sample = assays[sample == sample_name, ]
	sample = data.table::dcast(sample, ID ~ type, value.var = 'count')
	return(sample)
}

#' @param assays table with columns ID (variant ID), type (alt, ref or totalCount), and count. 
#' @param countType one of totalCount, altCount or refCount
#' @return a wide data.table with an ID column, and column for each sample
getCount = function(assays, countType = c('totalCount', 'altCount','refCount')){
	countType = match.arg(countType)
	stopifnot('data.table' %in% class(assays))
	count = assays[type == countType, ]
	count = data.table::dcast(count, ID ~ sample, value.var = 'count')
	return(count)
}

