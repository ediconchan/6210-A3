##load packages to be used in this analysis

library(tidyverse)
library(dbplyr)
library(ape)
library(muscle)
library(DECIPHER)
library(rentrez)
library(Biostrings)
library(ggplot2)
library(ggtext)
library(cluster)
library(factoextra)
library(viridis)

# Listing global variables to be searched in NCBI Genback
# nucleotide database. In this case, NOTCH3 and BRCA1
# genes from the Cetacea family were searched against a
# certain length range to isolate gene sequences rather
# than genomes.

family <- "Cetacea"
min_len_NOTCH3 <- 6000
max_len_NOTCH3 <- 9000
min_len_BRCA1 <- 5000
max_len_BRCA1 <- 8000

# Function to search and fetch genes using the rentrez
#package, and create a dataframe containing gene
#sequences. Also creates global variables for quality
#control purposes.
create_dfGene <- function(family_name, gene, gene_min, gene_max) {
  # Search NCBI nucleotide database for genes of a given length
  gene_search <- entrez_search(db = "nuccore",
                               term = paste0(family_name, "[ORGN] AND ", gene,
                                             "[Gene] AND ", gene_min, ":",
                                             gene_max, "[SLEN]"), retmax = 1000)
  # Fetch fasta files corresponding to search parameters
  gene_fetch <- entrez_fetch(db = "nuccore",
                             id = gene_search$ids,
                             rettype = "fasta")

  # write to file, separate and remove Ns from sequence data
  write(gene_fetch, paste0(gene, "_fetch.fasta"), sep = "\n")

  # Rewriting to a DNA string set from the .fasta file
  # without any Ns in the sequences
  fasta_name <- paste0(gene, "_fetch.fasta")
  gene_string <- readDNAStringSet(fasta_name)

  # Creating a data frame from our stringset taking values(names)
  # from stringset and plugging them into data frame
  dfGene <- data.frame(title = names(gene_string),
                       sequence = paste(gene_string))

  # Creating the column names for the dataframe
  gene_title <- paste0(gene, "_Title")
  gene_sequence <- paste0(gene, "_Sequence")
  names(dfGene)[1:2] <- c(gene_title, gene_sequence)

  ## Creating global variables for each gene for quality control purposes

  # Entrez fetch variable
  assign(paste0(gene, "_fetch"), gene_fetch, parent.frame())
  # Gene DNAStringSet Object using Biostrings package
  assign(paste0(gene, "_string"), gene_string, parent.frame())
  # Create Gene Data frame
  assign(paste0("df", gene), dfGene, parent.frame())
}

# Fetch NOTCH3 sequences and create data frame
create_dfGene(family_name = family, gene = "NOTCH3",
              gene_min = min_len_NOTCH3, gene_max = max_len_NOTCH3)
# Fetch BRCA1 sequences and create data frame
create_dfGene(family_name = family, gene = "BRCA1",
              gene_min = min_len_BRCA1, gene_max = max_len_BRCA1)

##Check class to ensure it is a character vector

class(NOTCH3_fetch)

class(BRCA1_fetch)

##Having a look at the data to ensure we have the right sequence data

head(BRCA1_fetch)

head(NOTCH3_fetch)

##Checking data, ensuring we have proper class and viewing our data
class(NOTCH3_string)
head(names(NOTCH3_string))

class(BRCA1_string)
head(names(BRCA1_string))

##This is some name editing to clean up sequence names
# and remove unwanted words from species names,
# and rearranging data frame columns

clean_df <- function(dfGene, gene_name) {

  dfGene$Species_Name <- word(dfGene[, 1], 3L, 4L)
  colnames <- c(paste0(gene_name, "_Title"),
                "Species_Name",
                paste0(gene_name, "_Sequence"))
  return(dfGene[, colnames])

}

dfNOTCH3 <- clean_df(dfNOTCH3, "NOTCH3")
dfBRCA1 <- clean_df(dfBRCA1, "BRCA1")

##Checking dimensions of the dataframe as quality control

dim(dfBRCA1)

dim(dfNOTCH3)

##Checking names of dataframe as quality control
names(dfBRCA1)

names(dfNOTCH3)

##Getting a summary of sequence lengths to ensure sequence length is appropriate

summary(nchar(dfBRCA1$BRCA1_Sequence))

summary(nchar(dfNOTCH3$NOTCH3_Sequence))

# Coding for a histogram displaying the distribution of sequence lengths,
# to ensure quality control and identify any errors or outliers

create_plot <- function(dfGene, gene_name, family_name, gene_min, gene_max) {

  plot_title <- paste0("Frequency of Sequence Length of ",
                       gene_name, " in ", family_name)

  hist_plot <- ggplot(data = dfGene,
                      mapping = aes(x = nchar(dfGene[, 3]))) +
    geom_histogram(breaks = seq(gene_min, gene_max, by = 75),
                   col = "blue", aes(fill = ..count..)) +
    scale_fill_distiller(palette = "Spectral") +
    labs(title = plot_title, x = "Sequence Length", y = "Number of Species")  +
    theme_bw()

  return(hist_plot)
}

NOTCH3PLOT <- create_plot(dfGene = dfNOTCH3,
                          gene_name = "NOTCH3",
                          family_name = family,
                          gene_min = min_len_NOTCH3,
                          gene_max = max_len_NOTCH3)

BRCA1PLOT <- create_plot(dfGene = dfBRCA1,
                         gene_name = "BRCA1",
                         family_name = family,
                         gene_min = min_len_BRCA1,
                         gene_max = max_len_BRCA1)

##Plotting the plot to visualize

plot(NOTCH3PLOT)

plot(BRCA1PLOT)

# Alignment Function
run_alignment <- function(dfGene, gene) {
  #Create new column name
  colname <- paste0(gene, "_Sequence2")
  #Add DNAStringSet sequences to new column
  sequences <- dfGene[, 3]
  dfGene[[colname]] <- DNAStringSet(sequences)
  #Assign species name to each sequence for alignment
  names(dfGene[[colname]]) <- dfGene$Species_Name
  #Align using MUSCLE
  dfGene.alignment <- DNAStringSet(muscle::muscle(dfGene[[colname]]),
                                   use.names = TRUE)
  # Update data frame global variable
  assign(paste0("df", gene), dfGene, parent.frame())
  # Return sequence alignment
  return(dfGene.alignment)
}

##Create alignments for NOTCH3 and BRCA1
dfNOTCH3.alignment <- run_alignment(dfGene = dfNOTCH3, gene = "NOTCH3")
dfBRCA1.alignment <- run_alignment(dfGene = dfBRCA1, gene = "BRCA1")

##checking class -> string set
class(dfNOTCH3$NOTCH3_Sequence2)

class(dfBRCA1$BRCA1_Sequence2)

# Double checking that the names have
# transferred in and checking they are cleaned up
names(dfNOTCH3$NOTCH3_Sequence2)

names(dfBRCA1$BRCA1_Sequence2)

##Checking that alignment worked, with species names

dfBRCA1.alignment

dfNOTCH3.alignment

##Opening an alignment in the browser to double check alignment quality

BrowseSeqs(dfBRCA1.alignment)

BrowseSeqs(dfNOTCH3.alignment)

# Changing alignment class to DNA bin to be used in a
# distance matrix for subsequent cluster analysis
cluster_alignments <- function(dna_alignment, gene_name,
                               chosen_model, clustering_threshold,
                               clustering_method) {
  #Changing alignment class to DNA bin
  dnaBin_gene <- as.DNAbin(dna_alignment)
  ##Creating distance matrices
  distanceMatrixgene <- dist.dna(dnaBin_gene,
                                 model = chosen_model,
                                 as.matrix = TRUE,
                                 pairwise.deletion = TRUE)
  # -Clustering my data using previously chosen cluster values
  clusters_gene <- DECIPHER::TreeLine(myDistMatrix = distanceMatrixgene,
                                      method = clustering_method,
                                      cutoff = clustering_threshold,
                                      showPlot = TRUE,
                                      type = "both",
                                      verbose = TRUE)
  # numbering species names making each a unique name
  # to use as a unique data point on our plot
  rownames(distanceMatrixgene) <- make.names(rownames(distanceMatrixgene),
                                             unique = TRUE)
  # Outputting bin class and distance matrix global variables
  assign(paste0("dnaBin.", gene_name),
         dnaBin_gene, parent.frame())
  assign(paste0("distanceMatrix", gene_name),
         distanceMatrixgene, parent.frame())
  # Return a cluster grouped by distance matrix similarity
  return(clusters_gene)
}

clusters.NOTCH3 <- cluster_alignments(dna_alignment = dfNOTCH3.alignment,
                                      gene_name = "NOTCH3",
                                      chosen_model = "TN93",
                                      clustering_threshold = 0.03,
                                      clustering_method = "UPGMA")

clusters.BRCA1 <- cluster_alignments(dna_alignment = dfBRCA1.alignment,
                                     gene_name = "BRCA1",
                                     chosen_model = "TN93",
                                     clustering_threshold = 0.03,
                                     clustering_method = "UPGMA")

##Checking that it worked and is now DNA bin class

class(dnaBin.NOTCH3)

class(dnaBin.BRCA1)

##Ensuring that it worked

head(distanceMatrixBRCA1)

head(distanceMatrixNOTCH3)

##Checking class, viewing and checking length of clusters for quality control

class(clusters.BRCA1)

clusters.BRCA1

length(clusters.BRCA1)


class(clusters.NOTCH3)

clusters.NOTCH3

length(clusters.NOTCH3)


##To ensure we have the right amount of clusters for our
# k-means analysis, I am creating a plot to tell us the
# optimal number of clusters for each using silhouette
# index calculations
OptNOTCH3 <- fviz_nbclust(distanceMatrixNOTCH3,
                          FUNcluster = kmeans,
                          method = "silhouette",
                          linecolor = "lightpink2")

OptBRCA1 <- fviz_nbclust(distanceMatrixBRCA1,
                         FUNcluster = kmeans,
                         method = "silhouette",
                         linecolor = "lightblue2")

##Plotting optimal cluster plot
plot(OptNOTCH3)

plot(OptBRCA1)

##Obtaining the optimal k-means cluster number from the fviz_nbclust function

maxNOTCH3 <- OptNOTCH3$data
max_cluster_NOTCH3 <- as.numeric(maxNOTCH3$clusters[which.max(maxNOTCH3$y)])

maxBRCA1 <- OptBRCA1$data
max_cluster_BRCA1 <- as.numeric(maxBRCA1$clusters[which.max(maxBRCA1$y)])

##Setting the seed for reproduction and perform kmeans clustering
set.seed(123)
kmNOTCH3 <- kmeans(distanceMatrixNOTCH3, max_cluster_NOTCH3)
set.seed(124)
kmBRCA1 <- kmeans(distanceMatrixBRCA1, max_cluster_BRCA1)

# Viewing kmeans outcomes and evaluating whether this is the
# right number of clusters

kmNOTCH3

kmBRCA1

##Creating kmeans cluster plot in ggplot style, colouring and tweaking
# default parameters to match the goal of these plots
kmeans_cluster <- function(kmGene, distanceMatrix,
                           gene_name, labelsize = 5,
                           viridis_option = "H") {
  figure_title <- paste("K-means Analysis of", gene_name)
  gene_cluster <- fviz_cluster(kmGene,
                               data = distanceMatrix,
                               geom = c("point", "text"),
                               repel = TRUE,
                               show.clust.cent = TRUE,
                               ellipse.type = "convex",
                               labelsize = 5) +
    labs(title = figure_title) +
    theme(panel.background = element_rect(fill = "darkgrey")) +
    scale_color_viridis_d(option = viridis_option)
  return(gene_cluster)
}

NOTCH3_cluster <- kmeans_cluster(kmGene = kmNOTCH3,
                                 distanceMatrix = distanceMatrixNOTCH3,
                                 gene_name = "NOTCH3",
                                 labelsize = 5,
                                 viridis_option = "H")

BRCA1_cluster <- kmeans_cluster(kmGene = kmBRCA1,
                                distanceMatrix = distanceMatrixBRCA1,
                                gene_name = "BRCA1",
                                labelsize = 8,
                                viridis_option = "A")

##Plotting and viewing of plots
plot(BRCA1_cluster)

plot(NOTCH3_cluster)
