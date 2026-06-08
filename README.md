# NinjaSeq

Scripts and notebooks to reproduce the **NinjaSeq** analysis: an Oxford Nanopore
(ONT) long-read sequencing workflow for characterising synthetic DNA pools
(library QC, restriction-site profiling, read-level statistics, and
random-access experiments).

The repository ships only the analysis code and the reference designs; raw
POD5 / BAM / FASTQ files are expected to live alongside the repo in a
sibling `data/` (and `raw_data/`) folder.

## Repository layout

```
NinjaSeq/
├── preprocessing/                # Processing (basecalling * trimming * mapping)
│   ├── run_dorado_basecaller.sh
│   ├── run_cutadapt.sh
│   └── run_minimap2.sh
├── references/                   # Reference FASTAs for the three pool designs
│   ├── f1_data_after_indices_two_files.fasta   # F1 pool   (~110 000 sequences)
│   ├── p2_design.fasta                         # P2 pool   (~1 000 sequences)
│   └── data_genomika_constrained_indexed.fasta # C1 pool   (~1 644 sequences)
└── notebooks/                    # Downstream analysis (Python + DuckDB)
    ├── 01_qc_stats.ipynb         # Raw read QC (length, qscore, channel, time)
    ├── 02_read_re_stats.ipynb    # Restriction-site (GGATG / CATCC) profiling
    ├── 03_read_stats.ipynb       # Per-read alignment statistics (C1 pool)
    ├── 04_rand_access.ipynb      # Random-access / size-selection experiment
    └── 04_rrs_screen.ipynb       # RRS (restriction-recognition site) screen
```

## Expected working directory

The shell scripts and notebooks use **relative paths**. They assume the
following layout, with `NinjaSeq/` checked out next to `raw_data/` and `data/`:

```
<project_root>/
├── NinjaSeq/        # this repository
├── raw_data/        # ONT runs: <run>/<sample>/pod5/*.pod5
├── data/            # basecalled / trimmed / mapped BAMs (created by the pipeline)
└── results/         # parquet tables produced by the notebooks
```

Sample-name conventions used throughout:

| Short key | Pool | Sample folder(s) | Reference FASTA                           |
| --------- | ---- | ---------------- | ----------------------------------------- |
| `hp_f1`   | F1   | `BEGONIA_2`      | `f1_data_after_indices_two_files.fasta`   |
| `nj_f1`   | F1   | `BEGONIA_4`      | `f1_data_after_indices_two_files.fasta`   |
| `hp_p2`   | P2   | `CAMELLIA_007`   | `p2_design.fasta`                         |
| `nj_p2`   | P2   | `CAMELLIA_008`   | `p2_design.fasta`                         |
| `hp_c1`   | C1   | `CAMELLIA_11`    | `data_genomika_constrained_indexed.fasta` |
| `nj_c1`   | C1   | `CAMELLIA_17`    | `data_genomika_constrained_indexed.fasta` |

The `hp_` / `nj_` prefixes denote the two library-preparation protocols being
compared (HP vs NinjaSeq).

## Requirements

System tools (must be on `$PATH`):

- [Dorado](https://github.com/nanoporetech/dorado) ≥ 0.5 with the
  `sup@v5.0.0` basecalling model and a CUDA-capable GPU
- [samtools](https://www.htslib.org/) ≥ 1.17
- [cutadapt](https://cutadapt.readthedocs.io/) ≥ 4.0
- [minimap2](https://github.com/lh3/minimap2) ≥ 2.26

Python (for the notebooks, Python ≥ 3.10 recommended):

```bash
pip install pysam duckdb pandas numpy regex seaborn matplotlib scipy jupyter pyarrow
```

## Preprocessing pipeline

All three scripts are designed to be run from `<project_root>/` (i.e. the
parent of this repository), so that `$PWD/raw_data`, `$PWD/data`, and
`$PWD/references` resolve correctly.

### 1. Basecalling — [preprocessing/run_dorado_basecaller.sh](preprocessing/run_dorado_basecaller.sh)

Finds every `pod5/` directory under `raw_data/*/*/`, basecalls with
`dorado sup@v5.0.0` (`--trim adapters`, `--device cuda:all`), and writes two
unmapped BAMs per sample:

- `*_sup_v5_trim_no_filter.bam` — all reads
- `*_sup_v5_trim_filter_9.bam`  — reads with `[qs] >= 9`

### 2. Adapter / length trimming — [preprocessing/run_cutadapt.sh](preprocessing/run_cutadapt.sh)

Runs on the unfiltered, untrimmed BAMs (`*5_no_trim_filter_9.bam`). Pipes
`samtools fastq` into `cutadapt` to strip the 5′ adapter
`CCTGTACTTCGTTCAGTTACGTATTGCT` (also reverse-complemented), discards untrimmed
reads, enforces a minimum length of 190 bp, and writes
`data/trimmed_len_ont/<sample>_trimmed_ont.fastq.gz` plus a cutadapt log.

### 3. Mapping — [preprocessing/run_minimap2.sh](preprocessing/run_minimap2.sh)

For every `*5_trim_filter_9.bam`, picks the correct reference based on the
sample folder name (see table above) and aligns with minimap2 in short-read
mode tuned for short synthetic constructs:

```
minimap2 -ax sr -L --MD -t8 -Y --eqx -k10 -w5 -m10 --secondary=yes <ref> <fastq>
```

Output: sorted, indexed `<sample>_trim_filter_9_mapped.bam` next to the input.

## Analysis notebooks

Run from `notebooks/` (paths inside the notebooks are relative, e.g.
`../data/...`, `../references/...`, `../results/...`). Intermediate tables are
materialised as Parquet under `../results/` and queried with DuckDB.

- [notebooks/01_qc_stats.ipynb](notebooks/01_qc_stats.ipynb) — parses the raw
  (`no_trim_no_filter`) BAMs with `pysam`, extracts per-read length / qscore
  / start-time / channel tags, and emits `qc_stats_{f1,p2,c1}.parquet` for
  downstream plots.
- [notebooks/02_read_re_stats.ipynb](notebooks/02_read_re_stats.ipynb) — locates
  the `GGATG` / `CATCC` recognition motif (BseGI Type IIS site) in each
  reference, then annotates mapped reads with whether they terminate at an
  RS site, are truncated, etc.
- [notebooks/03_read_stats.ipynb](notebooks/03_read_stats.ipynb) — per-read
  alignment table (`ref_id`, `start`, `end`, CIGAR-derived width, length
  fraction) for the C1 pool, stored as `read_stats_c1.parquet`.
- [notebooks/04_rand_access.ipynb](notebooks/04_rand_access.ipynb) —
  random-access size-selection experiment (samples `CAMELLIA_21` /
  `CAMELLIA_22`); compares unfiltered vs. length-trimmed read-length
  distributions against a combined P2+C1+D1 reference
  (`combined_p2_c1_d1_ref_wo_primers.fasta`).
- [notebooks/04_rrs_screen.ipynb](notebooks/04_rrs_screen.ipynb) — scans
  mapped C1 reads for in-read RRS motifs and projects them onto reference
  coordinates to screen candidate truncation sites.

## Typical end-to-end run

```bash
# from <project_root>/
bash NinjaSeq/preprocessing/run_dorado_basecaller.sh
bash NinjaSeq/preprocessing/run_cutadapt.sh        # only needed for rand-access
bash NinjaSeq/preprocessing/run_minimap2.sh

mkdir -p results
jupyter lab NinjaSeq/notebooks/
```

Then execute the notebooks in numeric order.

## Notes

- The shell scripts hard-code thread counts (`-t8`, `--cores 8`) and the
  Dorado model (`sup@v5.0.0`); edit them to match your hardware.
- Sample-to-reference mapping in `run_minimap2.sh` is encoded as `if`
  branches on the sample folder name — extend it there when adding new
  samples.
- The notebooks assume a `../results/` directory exists; create it before
  running cell-by-cell.
