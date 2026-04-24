# ============================================================
#  install_packages.R
#  Run this ONCE locally before launching or deploying the app
# ============================================================

pkgs <- c(
  # Shiny + UI
  "shiny",
  "bslib",
  "shinyjs",
  "shinyWidgets",

  # Audio I/O + video encoding
  "av",          # ffmpeg-backed video encoding  (ropensci)
  "tuneR",       # read WAV / audio files
  "seewave",     # FFT / spectrogram computation

  # Color palettes
  "viridisLite",

  # Zip for batch download
  "zip"
)

missing <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing) > 0) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cran.rstudio.com/")
}

message("All packages ready!")

# ── NOTE ON av / ffmpeg ────────────────────────────────────────────────────────
# The `av` package requires a system-level ffmpeg installation on Linux/macOS.
# On shinyapps.io (Ubuntu), ffmpeg IS pre-installed on most tiers.
# To verify locally: av::av_encoders() — should list available codecs.
#
# On shinyapps.io you may also need to specify the CRAN binaries for Linux.
# The DESCRIPTION file below handles this automatically via rsconnect.
