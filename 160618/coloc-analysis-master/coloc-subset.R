library(dplyr)
library(coloc)
library(data.table)

# args = c("Adipose_Subcutaneous_Analysis.cis.eqtl.gz", "Adipose_Visceral_Omentum_Analysis.cis.eqtl.gz")
# args = c("Thyroid_Analysis.cis.eqtl", "Heart_Atrial_Appendage_Analysis.cis.eqtl")
# args = c("Heart_Atrial_Appendage_Analysis.cis.eqtl", "Thyroid_Analysis.cis.eqtl")


# Read the command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Define useful functions

## One to get the tissue type name
get_tissue <- function(filename) {
  tissuesplit <- strsplit(filename, "_")[[1]]
  tissueend <- which(tissuesplit == "Analysis.cis.eqtl") - 1
  tissue <- paste(tissuesplit[1:tissueend], collapse = "_")
}

## One to get the results of the coloc test in data frame format
ctest <- function(p1 = p.value.x, p2 = p.value.y, snp = SNP,
                  maf1 = MAF.x, maf2 = MAF.y, tissue1 = tissue1,
                  tissue2 = tissue2, tissue1N = tissue1N, tissue2N = tissue2N) {
  test <- coloc.abf(dataset1 = list(pvalues = p1,
                                    N = tissue1N,
                                    snp = snp,
                                    type = "quant",
                                    MAF = maf1),
                    dataset2 = list(pvalues = p2,
                                    N = tissue2N,
                                    snp = snp,
                                    type = "quant",
                                    MAF = maf2))
  
  tissue1 <- tissue1[1]
  tissue2 <- tissue2[1]
  maxPP <- which.max(test$results$SNP.PP.H4)
  snp <- as.character(test$results$snp)[maxPP]
  snp.pp.h4 <- as.character(test$results$SNP.PP.H4)[maxPP]
  
  
  testresult <- t(data_frame(test$summary))
  
  output <- data.frame(tissue1,
                       tissue2,
                       snp,
                       snp.pp.h4,
                       testresult)
  
  output <- data.frame(lapply(output, as.character))
  
  colnames(output) <- c("tissue1",
                        "tissue2",
                        "snp",
                        "snp.pp.H4",
                        "nsnps",
                        "pp.H0",
                        "pp.H1",
                        "pp.H2",
                        "pp.H3",
                        "pp.H4")
  
  return(output)
}

print("Checkpoint 1")

# Get the file paths
file1 <- paste0("/srv/scratch/tshimko/analysis/tmp_subset/", args[1])
file2 <- paste0("/srv/scratch/tshimko/analysis/tmp_subset/", args[2])

# Get the tissue names
tissue1 <- get_tissue(args[1])
tissue2 <- get_tissue(args[2])

# Read in the file with all of the significant SNP-gene correlations for tissue1
#genes <- fread(paste0("/srv/scratch/tshimko/meta/genes_subset/", tissue1, "_genes.txt"))

print("Checkpoint 2")

# Read in the minor allele frequencies
MAF1 <- fread(paste0("/srv/scratch/tshimko/meta/MAF_subset/", tissue1, "_MAF.txt"))
MAF2 <- fread(paste0("/srv/scratch/tshimko/meta/MAF_subset/", tissue2, "_MAF.txt"))

print("Checkpoint 3")

# Get the sample size info
tissue1N <- 57
tissue2N <- 57

print("Checkpoint 4")

# Read in the tissue data, select only the necessary columns,
# add the tissue type as a column, and
tissue_data1 <- fread(file1, select = c(1, 2, 5)) %>%
  mutate(tissue1 = tissue1) %>%
  rename(p.value = `p-value`)

print("Checkpoint 5")

tissue_data2 <- fread(file2, select = c(1, 2, 5)) %>%
  mutate(tissue2 = tissue2) %>%
  rename(p.value = `p-value`)

print("Checkpoint 6")

# Reduce the size of tissue1 data to only genes with significant snps
#tissue_data1 <- dplyr::filter(tissue_data1, gene %in% genes$gene)

print("Checkpoint 7")

# Join in the MAF data for both data sets
tissue_data1 <- dplyr::left_join(tissue_data1, MAF1, by="SNP")
tissue_data2 <- dplyr::left_join(tissue_data2, MAF2, by="SNP")

print("Checkpoint 8")

# Join the two data sets by gene and SNP
all <- dplyr::inner_join(tissue_data1, tissue_data2, by = c("SNP", "gene"))
all <- as.data.frame(all)

count <- all %>% group_by(gene) %>% summarize(count = n()) %>% filter(count != 1)
all <- all %>% filter(gene %in% count$gene)

print("Checkpoint 9")

# Get the colocalization test output
ctestdf <- all %>% group_by(gene) %>% do({print(.$gene[1]); ctest(.$p.value.x, .$p.value.y, .$SNP, .$MAF.x, .$MAF.y, tissue1, tissue2, tissue1N, tissue2N)})

ct2 <- ctestdf %>% filter(!is.na(snp))

print("Checkpoint 10")

# Write to a file
filename <- paste0("/srv/scratch/tshimko/results/subset/", tissue1, "_vs_", tissue2, "_subset.txt")
write.table(ct2, file = filename, sep = "\t", row.names = FALSE, quote = FALSE)

print("Script complete.")
