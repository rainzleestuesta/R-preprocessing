library(data.table)
library(fs)
library(cli)

meta_file <- path("data", "processed", "metadata_clean.csv")
spec_dir  <- path("data", "processed", "spectrograms")

stopifnot(
  file_exists(meta_file),
  dir_exists(spec_dir)
)

#metadata define
meta <- fread(meta_file)

meta[, clip_prefix := tolower(gsub("\\.", "", `File ID`))]

meta <- meta[, .(clip_prefix, species_norm, termite_flag)]

#spectrogram index  ->  clip_id + clip_prefix

spec_files <- dir_ls(spec_dir, glob = "*_orig.npy")      # only originals

spec_dt <- data.table(
  file_path   = spec_files,
  clip_id     = tolower(
    sub("_(orig)$", "",                    
        path_file(path_ext_remove(spec_files)))
  ),
  clip_prefix = tolower(
    sub("-.*$", "",                       
        path_file(path_ext_remove(spec_files)))
  )
)

#join and verify completeness
dt <- merge(
  spec_dt,
  meta,
  by = "clip_prefix",
  all.x = TRUE
)

if (anyNA(dt$species_norm)) {
  missing <- dt[is.na(species_norm), clip_id]
  stop(
    "Metadata missing for ", length(missing), " clip(s) – check IDs.\n",
    "Example(s): ", paste(head(missing, 5), collapse = ", ")
  )
}
-
#random 80 / 10 / 10 split
n   <- nrow(dt)               
idx <- sample(n)

train <- dt[idx[1:floor(0.80 * n)]]
val   <- dt[idx[(floor(0.80 * n) + 1):floor(0.90 * n)]]
test  <- dt[idx[(floor(0.90 * n) + 1):n]]

#columns to keep in the CSV
keep <- c("clip_id", "file_path", "species_norm", "termite_flag")

#write CSVs
out_dir <- path("data", "processed")
fwrite(train[, ..keep], path(out_dir, "train.csv"))
fwrite(val[  , ..keep], path(out_dir, "val.csv"))
fwrite(test[ , ..keep], path(out_dir, "test.csv"))
