# Background: genome annotation files

*Read this before the exercise. About five minutes.*

---

## 1. The biology in one paragraph

A **genome** is the complete DNA sequence of an organism — for the mouse, about
2.7 billion letters of A, C, G and T, split across chromosomes. The sequence on
its own is just letters. An **annotation** is the map that goes with it: it says
which stretches of those letters are genes, where each one starts and stops, and
what it makes. The sequence rarely changes; the annotation is rebuilt every few
months as people learn more. So a genome comes as two files — the sequence, and
the map.

## 2. The words you need

**Gene** — a stretch of DNA that is copied out and used for something. Not all
genes make protein.

**Transcript** — the RNA copy made from a gene. One gene often has **several**
transcripts, because different pieces of it can be stitched together in
different combinations. Each version is called an **isoform**.

**Exon** — a piece of a gene that is kept in the finished transcript.
**Intron** — a piece that is cut out and thrown away. A typical mammalian gene
is mostly intron: the exons are small islands in a long sea of discarded
sequence.

**CDS** (coding sequence) — the part of the exons that is actually translated
into protein, read three letters at a time. **UTR** (untranslated region) — the
exon parts at either end that are kept in the RNA but not translated.
**Start codon** and **stop codon** — the three-letter signals that mark where
translation begins and ends.

**Strand** — DNA has two complementary strands, and a gene is read along one of
them. `+` means the gene runs left to right along the reference sequence, `-`
means right to left.

**Biotype** — the category a gene falls into. `protein_coding` is the familiar
one. Others include **pseudogene** (a broken copy of a real gene that is no
longer used), and several kinds of non-coding RNA — `miRNA`, `snRNA`, `snoRNA`,
`lincRNA` — which are transcribed and do a job as RNA without ever becoming
protein. Most annotated genes are *not* protein-coding.

## 3. The file: GTF

**GTF** (Gene Transfer Format) is the standard plain-text annotation file. Each
line describes **one feature** — one gene, or one transcript, or one exon — as
**nine tab-separated columns**:

| # | Column | Example | Meaning |
|---|---|---|---|
| 1 | seqname | `1` | which chromosome |
| 2 | source | `protein_coding` | who or what produced the line |
| 3 | **feature** | `exon` | what kind of thing this line describes |
| 4 | **start** | `3054233` | first base |
| 5 | **end** | `3054733` | last base |
| 6 | score | `.` | usually unused |
| 7 | **strand** | `+` | which strand |
| 8 | frame | `.` | reading-frame offset, only for CDS |
| 9 | **attribute** | `gene_id "ENSMUSG…"; gene_name "Xkr4"; …` | everything else, as `key "value";` pairs |

Two things about coordinates: they are **1-based and inclusive**, so the length
of a feature is `end - start + 1`, not `end - start`. And **start is always the
smaller number**, even on the `-` strand.

### The part that trips everyone up

The file is **hierarchical, flattened into lines**. One gene is not one line.
A gene with 5 transcripts of 20 exons each produces 1 gene line, 5 transcript
lines, 100 exon lines, plus CDS, UTR and codon lines — and *every one of those
lines repeats the gene name*. Counting lines is almost never the same as
counting genes.

The attribute column is the other awkward part: it is a single column holding a
variable list of `key "value";` pairs, and **it contains spaces**. That is why
you pull values out of it with `sed` and a capture group rather than by counting
fields.

> **GFF3** is the same idea with a different attribute syntax (`key=value;`
> instead of `key "value";`). Everything else carries over.

## 4. Questions people actually ask of these files

- How many genes are on this chromosome, and how many are protein-coding?
- How long is this gene, and how much of it is actually coding?
- How many exons does it have? How many isoforms?
- Which genes overlap this region — say, a variant I found or a peak I called?
- Give me the coordinates of every exon, so I can count reads falling in them.
- How does last year's annotation differ from this year's?

## 5. Pitfalls

1. **`grep -c "gene"` does not count genes.** The word `gene` appears in
   `gene_id`, `gene_name`, `gene_source` and `gene_biotype` on *every* line.
   Genes are lines where **column 3 is exactly `gene`**.
2. **`awk '{print $9}'` does not print the attributes.** The attribute column
   contains spaces, so whitespace splitting cuts it into pieces and `$9` gives
   you the literal word `gene_id`. Use `awk -F"\t"` or `cut -f9`.
3. **Exons are listed once per transcript.** Counting exon lines for a gene
   counts the same exon again for every isoform that uses it. Deduplicate on
   coordinates first.
4. **Length is `end - start + 1`.** Forgetting the `+1` is an off-by-one that
   silently propagates into every downstream number.
5. **A gene's span is not its coding content.** Most of a mammalian gene is
   intron; the two can differ by more than a hundredfold.
6. **Header lines start with `#`** and must be removed before any counting.
7. **Not every gene is protein-coding.** Filter on `gene_biotype` when you mean
   protein-coding genes, or you will quietly include pseudogenes and RNA genes.
8. **Annotations are versioned.** Gene counts, names and coordinates differ
   between releases and between genome builds. Always record which release you
   used.

## 6. What people commonly do with a GTF

- **Summarise** — counts of genes per biotype, per chromosome, per strand.
- **Extract coordinates** — pull out all exons, or all CDS, as input to the next
  tool.
- **Measure** — gene lengths, exon counts, coding fraction.
- **Intersect** — find which genes a set of positions falls in (usually with
  `bedtools` once the regions get complicated).
- **Count reads** — in RNA-seq, the GTF is what tells the counting program which
  reads belong to which gene. A quiet error in the annotation becomes a quiet
  error in every expression value downstream.

---

**The data used in the exercise:** chromosome 1 of the Ensembl mouse annotation,
release 75, genome build GRCm38. 81,231 lines, 2,027 genes.
