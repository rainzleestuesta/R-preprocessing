library(httr)
library(fs)
library(openssl)
library(data.table)
library(cli)
library(progress)
library(jsonlite)
library(dplyr)

urls <- list(
  sounds_zip = "https://ndownloader.figshare.com/files/44527544",
  meta_csv   = "https://ndownloader.figshare.com/files/44527547"
)

dest_dir   <- path("data", "raw")
log_file   <- path(dest_dir, "download_log.csv")

dir_create(dest_dir, recurse = TRUE)

download_and_hash <- function(url, dest) {
  cli::cli_alert_info("Downloading {basename(dest)}...")

  tmp <- tempfile()
  on.exit(if (file_exists(tmp)) file_delete(tmp), add = TRUE)

  # stream to disk to avoid mem blow‑up
  resp <- httr::GET(url, httr::write_disk(tmp, overwrite = TRUE),
                    progress())
  stop_for_status(resp)

  file_move(tmp, dest)
  sha256 <- openssl::sha256(file(dest, "rb"))
  bytes  <- file_info(dest)$size

  list(file = basename(dest), sha256 = sha256, bytes = bytes)
}

raw_to_hex <- function(x) paste0(as.character(x), collapse = "")

# Main
records <- vector("list", length(urls))

for (i in seq_along(urls)) {
  dest <- path(dest_dir, basename(urls[[i]]))
  if (!file_exists(dest)) {
    records[[i]] <- download_and_hash(urls[[i]], dest)
  } else {
    cli::cli_alert_success("{basename(dest)} already exists – skipping download")
    sha256 <- raw_to_hex(openssl::sha256(file(dest, "rb"))) 
    bytes  <- file_info(dest)$size
    records[[i]] <- list(file = basename(dest), sha256 = sha256, bytes = bytes)
  }
}

log_dt <- rbindlist(records)
log_dt[, timestamp := format(Sys.time(), "%Y-%m-%d %H:%M:%S")]

if (file_exists(log_file)) {
  fwrite(log_dt, log_file, append = TRUE)
} else {
  fwrite(log_dt, log_file)
}

