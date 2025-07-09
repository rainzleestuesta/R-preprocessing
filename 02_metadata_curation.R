library(data.table)
library(stringr)
library(fs)
library(dplyr)

raw_meta <- path("data", "raw", "Insect-Pest-Sounds-inventory_1.csv")
stopifnot(file_exists(raw_meta))

dest_dir <- path("data", "processed")
dir_create(dest_dir, recurse = TRUE)
out_file <- path(dest_dir, "metadata_clean.csv")

meta <- fread(raw_meta, encoding = "UTF-8")

species_regex <- "([A-Z][a-z]+ [a-z]+)"
meta[, species := str_extract(Description, species_regex)]

# Normalize
meta[, species_norm := str_to_lower(str_replace_all(species, " ", "_"))]

termite_genera <- c("Coptotermes", "Reticulitermes", "Cryptotermes",
                    "Heterotermes", "Incisitermes", "Kalotermes",
                    "Macrotermes", "Odontotermes", "Microtermes")
meta[, termite_flag := str_detect(species, paste(termite_genera, collapse = "|"))]

# Save
fwrite(meta, out_file)
