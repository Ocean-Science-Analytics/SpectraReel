# Spectrogram Video Generator — README

## Overview
A Shiny app that turns audio files into customizable **MP4 spectrogram
videos** with a scrolling playhead.

---

## Files
```
spectrogram_app/
├── app.R              ← Main Shiny application (UI + server)
├── render_utils.R     ← Video rendering engine (sourced by app.R)
├── install_packages.R ← Run once to install dependencies
├── DESCRIPTION        ← For shinyapps.io deployment
└── README.md          ← This file
```

---

## Quick Start (Local)

```r
# 1. Install dependencies (run once)
source("install_packages.R")

# 2. Launch the app
shiny::runApp(".")
```

---

## Settings Reference

### FFT / Spectrogram
| Setting | Effect |
|---------|--------|
| FFT Window Size | Larger = finer frequency resolution, coarser time |
| Window Function | Hanning = best general use; Blackman = best sidelobe suppression |
| Overlap % | Higher = smoother but slower to compute |
| Freq Range | Crop display to a frequency band |

### Amplitude
| Setting | Effect |
|---------|--------|
| dB Range | Sets the dynamic range of the display |
| Gamma | < 1 = brighter low-level signals; > 1 = more contrast |

### Visual Style
| Setting | Effect |
|---------|--------|
| Color Palette | Magma/Plasma good for speech; Viridis for general use |
| Playhead Color | Bright green (#00ff88) is highly visible on all palettes |
| Shade Played Region | Subtle white overlay on left of playhead |

### Output
| Setting | Effect |
|---------|--------|
| 1280×720 @ 25fps | Good default (HD, small file) |
| 1920×1080 @ 30fps | Full HD |
| Lower framerate | Faster to render, less smooth scrolling |

---

## Supported Audio Formats
WAV, MP3, FLAC, OGG, M4A (all converted internally via ffmpeg/av)

## Batch Mode
Upload multiple files → all rendered with identical settings → download
as a single ZIP archive containing one MP4 per audio file.

---

## Render Time Estimates (1-min audio, 1280×720, 25fps = 1500 frames)

| Machine | Approx. Time |
|---------|-------------|
| MacBook Pro M2 | ~1-2 min |
| Windows i7 | ~2-3 min |
| shinyapps.io Standard | ~2–4 min |

> Tip: Use 10–15 fps + 512 FFT for fast preview renders.
> Use 25–30 fps + 1024 FFT for final exports.

---

## Troubleshooting

**"av_encode_video failed"** — ffmpeg may not be installed system-wide.
Run `av::av_encoders()` to check. On Mac: `brew install ffmpeg`.
On Ubuntu: `sudo apt install ffmpeg`.

**App times out on shinyapps.io** — Upgrade to a higher tier, or reduce
framerate / video resolution in settings.

**Stereo files** — The app takes the left channel for spectral analysis
but mixes both channels into the audio track of the MP4.
