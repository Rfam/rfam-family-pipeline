#!/usr/bin/env Rscript
library(R4RNA)

args <- commandArgs(TRUE)

args[1]

if (length(args) != 2) {
        stop("Usage: ./stockholmToArc Rfam.stockholm output.png\nAssumes only 1 alignment in input file with dot-bracket structure on a #=GC SS_cons line")
}


# Simple Stockholm parser
readStockholm <- function(file) {
        file <- R4RNA:::openFileOrConnection(file)
        on.exit(close(file))
        
        slurp <- readLines(file)

        # Fast forward until start of content
        for(line in slurp) {
                if (length(grep("^\\#\\s*STOCKHOLM\\s+", line)) == 1) {
                        break;
                }
        } 

        fasta <- c()
        struct <- NULL
        # Processing body
        for(line in slurp) {
                if (length(grep("^//", line)) == 1) {
                        # Ending
                        break
                }               
                if (length(grep("^\\#=([A-Z]{2})\\s+([^\n]+?)\\s*$", line, perl = TRUE) == 1)) {
                        # Metadata, currently ignored except for #=GC SS_cons
                        if (length(grep("SS_cons", line, perl = TRUE) == 1)) {
                                tokens <- unlist(strsplit(line, "\\s+"))
                                if (is.null(struct)) {
                                        struct <- tokens[3]
                                } else {
                                        struct <- paste(struct, tokens[3], sep = "")
                                }
                        }
                        next
                }
                if (length(grep("^([^\\#]\\S+)\\s+([^\\s]+)\\s*", line, perl = TRUE) == 1)) {
                        # Sequence line, concatenated to growing fasta sequences
                        tokens <- unlist(strsplit(line, "\\s+"))
                        if (is.null(fasta[tokens[1]]) || is.na(fasta[tokens[1]])) {
                                fasta[tokens[1]] <- tokens[2]
                        } else {
                                fasta[tokens[1]] <- paste(fasta[tokens[1]], tokens[2], sep = "")
                        }
                        next
                        }
                        warnings("Ignore invalid line")
                }

                if (!is.null(struct)) {
                        fasta["SS_cons"] <- struct
                }

                return(fasta)
}

# Reading alignment and structure
msa <- readStockholm(args[1])

# replace WUSS unpaired symbols with '-'
ss <- gsub('[~_:,.]', '-', msa[length(msa)])

# Check if the family has secondary structure
if (length(grep("\\<", ss, perl=TRUE)) == 0) {
	warnings("Skipping family without secondary structure")
} else {

	struct <- viennaToHelix(ss)
	msa <- msa[-length(msa)]
	msa <- gsub("[.]", "-", msa)

	# Sort sequences by structure conformity and gaps
	msa <- msa[order(structureMismatchScore(msa, struct), alignmentPercentGaps(msa))]
	# Aesthetic clipping
	if (length(msa) > 500) {
			msa <- msa[sort(sample(length(msa), 500))]
	}

	# Colour arcs
	struct <- colourByCanonical(struct, msa, get = TRUE)

	# Plot arcs to output file
	output <- args[2]
	plotCovariance(msa, struct, legend = FALSE, grid = TRUE, lwd = 6, cex = 1.5, png = output, pad = c(1, 0, 3, 0))

	null <- dev.off()
}