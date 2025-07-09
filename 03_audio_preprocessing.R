library(tuneR)
library(seewave)
library(audio)
library(fs)
library(data.table)
library(reticulate)
library(dplyr)
library(progress)

raw_zip  <- path("data", "raw", "InsectSounds_2.zip")
wav_dir  <- path("data", "raw", "wav")
proc_dir <- path("data", "processed", "spectrograms")
dir_create(wav_dir, recurse = TRUE)
dir_create(proc_dir, recurse = TRUE)

if (file_exists(raw_zip) && length(dir_ls(wav_dir, glob = "*.wav")) == 0) {
  unzip(raw_zip, exdir = wav_dir)
}

clean_nd <- function(arr) np$nan_to_num(arr, nan = 0.0, posinf = 0.0, neginf = 0.0)

# Trim below threshold
trim_silence <- function(wave, threshold_db = -30) {
  env <- seewave::env(wave, plot = FALSE)
  thresh <- 10^(threshold_db/20)
  idx <- which(env > thresh)
  if (length(idx) == 0) return(wave)
  from <- max(1, min(idx) - 1)
  to   <- min(length(wave@left), max(idx) + 1)
  extractWave(wave, from = from, to = to, xunit = "samples")
}

# Normalise to target peak
normalise_wave <- function(wave, target_db = -1) {
  peak <- max(abs(wave@left))
  target <- 10^(target_db/20)
  wave@left <- wave@left / peak * target
  wave
}

# Augmentations
py <- import("librosa")
np <- import("numpy")

to_nd <- function(v) np$array(v, dtype = "float32")   # helper

augment_and_save <- function(wave, sr, base_name, out_dir) {
  y <- as.numeric(wave@left)
  y <- to_nd(y)
  
  save_spectro(y, sr, paste0(base_name, "_orig"), out_dir)

  y_stretch <- py$effects$time_stretch(y, rate = sample(c(0.92, 1.08), 1))
  save_spectro(y_stretch, sr, paste0(base_name, "_stretch"), out_dir)

  y_pitch <- py$effects$pitch_shift(y, sr = sr,
                                    n_steps = sample(c(-2, 2), 1))
  save_spectro(y_pitch, sr, paste0(base_name, "_pitch"), out_dir)

  # --- noise variant ----------------------------------------------------
  noise_wave <- seewave::noisew(d = length(y) / sr, f = sr, listen = FALSE)
  noise      <- as.numeric(noise_wave)
  noise      <- noise[seq_len(length(y))]                 # length-match
  
  sig_rms   <- sqrt(mean(y**2))
  if (!is.finite(sig_rms) || sig_rms == 0) sig_rms <- 1e-9
  
  noise_rms <- sqrt(mean(noise**2))
  if (!is.finite(noise_rms) || noise_rms == 0) noise_rms <- 1e-9
  
  scale_fac <- sig_rms * 10**(-20/20)
  noise     <- noise / noise_rms * scale_fac
  
  y_noise <- np$add(y, to_nd(noise))
  y_noise <- clean_nd(y_noise)
  save_spectro(y_noise, sr, paste0(base_name, "_noise"), out_dir)
  
}

save_spectro <- function(sig, sr, name, out_dir) {
  sig <- to_nd(sig)
  sig <- clean_nd(sig)  D
  mel <- py$feature$melspectrogram(y = sig,
                                   sr = as.integer(sr),
                                   n_mels = 128L,
                                   n_fft  = as.integer(sr * 0.025),
                                   hop_length = as.integer(sr * 0.010),
                                   power = 2.0)
  log_mel <- py$power_to_db(mel, ref = np$max)
  np$save(file = file.path(out_dir, paste0(name, ".npy")), arr = log_mel)
}

#Main
wav_files <- dir_ls(wav_dir, regexp = "\\.wav$", recurse = TRUE)
p <- progress_bar$new(total = length(wav_files),
                      format = "  :current/:total [:bar] :percent eta: :eta")

for (wf in wav_files) {
  p$tick()
  base <- path_file(path_ext_remove(wf))
  out_f <- path(proc_dir, paste0(base, "_orig.npy"))
  if (file_exists(out_f)) next

  w <- readWave(wf)
  if (w@samp.rate > 44100) {
    w <- tuneR::downsample(w, samp.rate = 44100)
  }
  w <- trim_silence(w, threshold_db = -30)
  w <- normalise_wave(w, target_db = -1)

  augment_and_save(w, 44100, base, proc_dir)
}
