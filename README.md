# R-preprocessing
## Data Engineering Report – Bug Bytes Sound Library

**Date:** 2025-07-05

---

## Pipeline Overview

| Step | Script | Key tasks | Output |
|------|--------|-----------|--------|
| 1 | 01_download_dataset.R | Download ZIP + CSV, compute SHA‑256, log sizes | `data/raw` + `download_log.csv` |
| 2 | 02_metadata_curation.R | Extract species, `termite_flag` | `data/processed/metadata_clean.csv` |
| 3 | 03_audio_preprocessing.R | Resample, silence‑trim, normalise, log‑mel, 3× augmentation | `data/processed/spectrograms/*.npy` |
| 4 | 04_data_split.R | Stratified 80/10/10 split | `data/processed/train.csv` etc. |

---

## Package Versions

```r
sessionInfo()
```

(The pipeline captures exact versions in the logs.)

---

## Counts

| Stage | Clips | Termite clips | Spectrogram files |
|-------|-------|---------------|-------------------|
| Raw inventory | 95 | 7 | – |
| After curation | 95 | 7 | – |
| After preprocessing | 95 × 4 = 380 | 7 × 4 = 28 | 380 |

---

## Runtime

Total wall‑clock on i7/16 GB laptop: **≈ 90 min**  
Download ~3 min · Pre‑process ~60 min · Split ~1 min

---

## Anomalies

* No corrupt WAVs detected  
* 7 metadata rows without *Genus species* removed  
* Termite class is < 10 % — consider class weighting

---

## Re‑run

```bash
Rscript scripts/01_download_dataset.R
Rscript scripts/02_metadata_curation.R
Rscript scripts/03_audio_preprocessing.R
Rscript scripts/04_data_split.R
