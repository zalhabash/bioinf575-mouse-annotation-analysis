# Question 1

# a
grep -v "^#!" Mus_musculus.GRCm38.75_chr1.gtf | awk -F"\t" '$3 == "gene"' | w
c -l

# b
grep -v "^#!" Mus_musculus.GRCm38.75_chr1.gtf | awk -F"\t" '$3 == "gene"' | sed 's/.*gene_biotype "\([^"]*\)".*/\1/' | sort | uniq -c | sort -nr

# c
awk 'BEGIN { print 1240/2027 }'
#   The proportion was about 61%. This is surprising. I expected about that amount of non-coding genes, not protein-coding.
