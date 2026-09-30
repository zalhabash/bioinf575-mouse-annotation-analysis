# BIOINF 575 — Genome annotation, bash and GitHub

**A 40-minute exercise, done on your own, with AI assistance**

Read `gtf_background.md` first if you have not.

---

## What you will do

You will download a real genome annotation, keep the analysis in a GitHub
repository, and answer **four questions** about mouse chromosome 1.

Every question needs **`grep`, `sed` and `awk` used together**, because each one
does a different job here and none of them can do the work alone:

- **`grep`** picks whole lines by pattern — drop the headers, keep one biotype.
- **`awk`** works on **columns** — test column 3, do arithmetic on columns 4
  and 5.
- **`sed`** works **inside** a column — reach into the attribute blob and pull
  the gene name out of it with a capture group.

You are not asked to write programs inside `awk` or `sed`. Each one stays to a
single condition, a single substitution or a single sum; the work is done by
**chaining them**.

**Timing**

| Part                                                             | Minutes |
| ---------------------------------------------------------------- | ------- |
| 0. Set up the repository and get the data                        | 7       |
| 1. Question 1 — what is annotated here                           | 7       |
| 2. Question 2 — the biggest genes, and how little of them codes  | 9       |
| 3. Question 3 — exon counts, and why the obvious answer is wrong | 8       |
| 4. Question 4 — use AI, then check it                            | 5       |
| 5. Pull request and wrap-up                                      | 4       |

---

## Before you start

- a terminal (macOS/Linux Terminal, or Git Bash / WSL on Windows)
- `git` installed and your GitHub account set up with an SSH key
- **VS Code** with the _GitHub Copilot_ and _GitHub Copilot Chat_ extensions,
  **or** **UMGPT** at <https://umgpt.umich.edu>

---

## Part 0 — Set up the repository and get the data (7 min)

**On GitHub**, create a **public** repository called `mouse-annotation-analysis`,
ticking _Add a README file_.

**In your terminal** (use your own username):

```bash
git clone git@github.com:YOUR_USERNAME/mouse-annotation-analysis.git
cd mouse-annotation-analysis
```

Download the annotation and uncompress it:

```bash
curl -O https://raw.githubusercontent.com/vsbuffalo/bds-files/master/chapter-07-unix-data-tools/Mus_musculus.GRCm38.75_chr1.gtf.gz
gzip -d Mus_musculus.GRCm38.75_chr1.gtf.gz
```

This is **chromosome 1 of the Ensembl mouse annotation, release 75, genome build
GRCm38** — a real production annotation file, not a teaching toy.

**Always look before you compute:**

```bash
ls -lh Mus_musculus.GRCm38.75_chr1.gtf
wc -l Mus_musculus.GRCm38.75_chr1.gtf
grep "^#" Mus_musculus.GRCm38.75_chr1.gtf
head -2 Mus_musculus.GRCm38.75_chr1.gtf
```

The file is about 26 MB and 81,231 lines, of which 5 are header lines starting
with `#`.

Look at the feature types in column 3 before anything else — this tells you what
kinds of line you are dealing with:

```bash
grep -v "^#" Mus_musculus.GRCm38.75_chr1.gtf | cut -f3 | sort | uniq -c | sort -nr
```

**Do not commit the data file.** It is public and one command re-creates it, so
what belongs in the repository is the _command_:

```bash
echo "*.gtf" > .gitignore
echo "curl -O https://raw.githubusercontent.com/vsbuffalo/bds-files/master/chapter-07-unix-data-tools/Mus_musculus.GRCm38.75_chr1.gtf.gz" > get_data.sh
echo "gzip -d Mus_musculus.GRCm38.75_chr1.gtf.gz" >> get_data.sh

git add .gitignore get_data.sh
git commit -m "Added download script and ignored the annotation file"
git push
```

Run `git status`. The `.gtf` file should not be listed.

From here, put every command into a script called `analyze_annotation.sh`, and
**commit after each question**.

---

## Question 1 — What is actually annotated on this chromosome? (7 min)

- **a.** How many **genes** are annotated? (Not how many lines contain the word
  `gene` — see the pitfalls.)
- **b.** Break the genes down by **biotype**, most common first.
- **c.** What fraction of annotated genes are protein-coding? Is that what you
  expected?

**The shape of the pipeline**

```
grep    drop the header lines
  |
awk     keep only the lines whose 3rd column is exactly  gene
  |
sed     replace the whole attribute column with just the biotype value
  |
sort | uniq -c | sort -nr
```

**Hints**

- `grep -v "^#"` removes lines that start with `#`.
- `awk -F"\t" '$3=="gene"'` keeps gene lines. The `-F"\t"` matters — see
  Question 4 for what happens without it.
- The attribute column contains `gene_biotype "protein_coding";`. To pull out
  just the value:

  ```
  sed 's/.*gene_biotype "\([^"]*\)".*/\1/'
  ```

  Reading that: match anything (`.*`), then the literal text
  `gene_biotype "`, then **capture** everything that is not a quote
  (`\([^"]*\)`), then the closing quote and anything after. Replace the whole
  line with the captured piece (`\1`). This is the same capture-group idea you
  used on FASTA headers, applied to a longer string.

Commit:

```bash
git add analyze_annotation.sh
git commit -m "Added the gene biotype breakdown"
```

---

## Question 2 — Which genes span the most DNA, and how much of that codes? (9 min)

- **a.** Find the **five protein-coding genes with the largest genomic span**,
  and report the span in base pairs together with the gene name and strand.
  Remember a feature's length is `end - start + 1`.
- **b.** Take the longest one. How many base pairs of it are actually **coding**
  (`CDS`)? Deduplicate the CDS coordinates first, because they are repeated for
  every transcript.
- **c.** What percentage of that gene is coding sequence? What is the rest?

**The shape of the pipeline for (a)**

```
grep    drop the headers
  |
awk     keep lines whose 3rd column is  gene
  |
grep    keep only  gene_biotype "protein_coding"
  |
sed     replace the attribute column with just the gene name, keeping columns 1-8
  |
awk     print  end - start + 1,  the gene name, the strand
  |
sort -nr | head -5
```

**Hints**

- To replace **only the attribute column** and keep the rest of the line intact:

  ```
  sed 's/\t[^\t]*gene_name "\([^"]*\)".*/\t\1/'
  ```

  This matches a tab, then the whole last column, and puts back a tab plus just
  the captured name. After it, the line still has 9 tab-separated fields, and
  field 9 is now the gene name — so `awk` can use it directly.

- Be specific in the `grep`. Searching for `protein_coding` on its own also
  matches other columns; `gene_biotype "protein_coding"` means what you mean.
- For (b), you need a **sum**. One short `awk` will do it:

  ```
  awk -F"\t" '{total = total + $2 - $1 + 1} END {print total}'
  ```

  `END` runs once, after the last line. Deduplicate with `cut -f4,5 | sort -u`
  **before** summing.

Commit:

```bash
git add analyze_annotation.sh
git commit -m "Added the longest gene and coding fraction analysis"
```

---

## Question 3 — Which gene has the most exons? (8 min)

- **a.** Rank genes by the number of **exon lines** they have. Report the top 5.
- **b.** That answer is wrong, and the reason is in the background reading. Pick
  the top gene and compare three numbers: how many exon **lines** it has, how
  many **distinct exons** it has (unique start/end pairs), and how many
  **transcripts** it has. Explain the relationship.
- **c.** Redo the ranking correctly, counting each exon once per gene. Does the
  top 5 change — and does it change _order_, or does it change _membership_?

**Hints**

- For (a): `grep` headers out, `awk` to keep `exon` lines, `sed` to reduce the
  attribute column to the gene name, then `sort | uniq -c | sort -nr | head -5`.
- For (c) the trick is what you deduplicate on. An exon is identified by its
  coordinates _and_ its gene, so cut out start, end and the gene name, use
  `sort -u` to collapse repeats, and only then count per gene.
- `uniq` only collapses **adjacent** duplicate lines, so `sort` always has to
  come first. This is the single most common cause of wrong counts in a bash
  pipeline.

Commit and push:

```bash
git add analyze_annotation.sh
git commit -m "Added the exon count analysis with deduplication"
git push
```

---

## Question 4 — Use AI, then check it (5 min)

### Set up your tool

**Copilot in VS Code** — Extensions (`Ctrl+Shift+X` / `Cmd+Shift+X`) → install
_GitHub Copilot_ and _GitHub Copilot Chat_ → sign in. Copilot has a free tier,
and students can verify for more at <https://education.github.com> with a
`@umich.edu` address. Then **File → Open Folder** on your repository folder —
this matters, because Copilot can only reason about files it can see. Chat opens
with `Ctrl+Alt+I` (`Cmd+Ctrl+I` on Mac).

**UMGPT** — <https://umgpt.umich.edu>, sign in with your uniqname. Use this when
the data should not go to a consumer service. This annotation is public, so
either is fine here, but build the habit now.

### Ask well

A good prompt gives the **format**, **real example lines**, the **exact
question**, and the **constraint**. Paste this:

> I have an Ensembl GTF annotation file. It has 9 tab-separated columns, and the
> 9th column is a single field containing `key "value";` pairs separated by
> semicolons — so it contains spaces. Here is one real line:
>
> ```
> 1	processed_transcript	exon	3213609	3216344	.	-	.	gene_id "ENSMUSG00000051951"; transcript_id "ENSMUST00000162897"; exon_number "1"; gene_name "Xkr4"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; exon_id "ENSMUSE00000858910";
> ```
>
> Write ONE bash pipeline that counts how many exon lines belong to each gene,
> most common first. Use grep, awk and sed — keep each of them to a single
> condition or substitution, no multi-line programs. Explain each stage.

Now ask the **same question in a new chat**, but **leave out** the sentence
explaining that the 9th column contains spaces.

### Check two things it is likely to get wrong

**Trap 1 — the attribute column.** Run both of these:

```bash
grep -v "^#" Mus_musculus.GRCm38.75_chr1.gtf | awk '{print $9}' | sort | uniq -c | head
grep -v "^#" Mus_musculus.GRCm38.75_chr1.gtf | cut -f9 | head -1
```

Both run without error. Do they show the same thing? What exactly did the first
one print, and why?

**Trap 2 — counting genes.** Compare:

```bash
grep -c "gene" Mus_musculus.GRCm38.75_chr1.gtf
grep -v "^#" Mus_musculus.GRCm38.75_chr1.gtf | awk -F"\t" '$3=="gene"' | wc -l
```

Both are valid commands. Only one answers the question that was asked. By what
factor is the wrong one wrong, and where do the extra matches come from?

### The three rules

1. **Ask for the command, not the answer.** A number you cannot check is worth
   nothing. A pipeline you can run, read and verify is worth a lot.
2. **Give the tool the format.** It cannot see your file. The column layout, one
   real line, and the constraint on which tools to use are what turn a guess
   into a correct answer.
3. **Verify with a second, independent method.** A command that runs cleanly is
   not a command that is right — both traps above produce clean output and a
   confident wrong number.

---

## Part 5 — Branch, pull request, wrap-up (4 min)

```bash
git checkout -b ai_crosscheck
```

Add the Question 4 commands to `analyze_annotation.sh`, write your four answers
in your own words in `ANSWERS.md`, then:

```bash
git add analyze_annotation.sh ANSWERS.md
git commit -m "Added the AI cross-check and the written answers"
git push --set-upstream origin ai_crosscheck
```

On GitHub, click **Compare & pull request**, describe in one line what the
cross-check found, and **Create pull request**. Look at the **Files changed**
tab before merging — that is what a reviewer sees, and it is why small,
well-described commits are worth the trouble. **Merge pull request**, then:

```bash
git checkout main
git pull
git log --oneline --graph
```

---

## Self-check

- `git log --oneline` shows at least five commits whose messages say what changed
- `git status` is clean and the `.gtf` file was never committed
- `ANSWERS.md` answers all four questions in your own words
- your pull request is merged and `main` has everything

Nothing is submitted. The solutions script has every command and every expected
number.
