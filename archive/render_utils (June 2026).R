?# ============================================================
#  render_utils.R  --  Spectrogram video rendering engine
#  Used by app.R; sourced automatically.
# ============================================================

library(av)
library(tuneR)
library(seewave)
library(viridisLite)
library(grDevices)

# -- Color palettes -------------------------------------------------------------
get_palette <- function(name, n = 512) {
  switch(name,
    viridis  = viridis(n),
    magma    = magma(n),
    plasma   = plasma(n),
    inferno  = inferno(n),
    cividis  = cividis(n),
    hot      = colorRampPalette(c("#000000","#1a0000","#7f0000",
                                   "#cc2200","#ff6600","#ffcc00","#ffffff"))(n),
    cool     = colorRampPalette(c("#000000","#001f3f","#0077b6",
                                   "#00b4d8","#90e0ef","#ffffff"))(n),
    deepblue = colorRampPalette(c("#000000","#03045e","#0077b6",
                                   "#00b4d8","#caf0f8","#ffffff"))(n),
    phosphor = colorRampPalette(c("#000000","#001a00","#003300",
                                   "#00cc00","#66ff66","#ccffcc"))(n),
    magma(n)
  )
}


# -- Spectrogram smoothing -----------------------------------------------------
#
#  amp     : matrix [freq_bins x time_bins] of dB values
#  method  : "gaussian" | "2d_box" | "time_gauss" | "freq_gauss"
#            "time_med" | "freq_med"
#  sigma_t : Gaussian sigma along time axis  (bins)
#  sigma_f : Gaussian sigma along freq axis  (bins)
#  domain  : "linear" (smooth power, convert back) | "db" (smooth dB directly)
#  db_min  : floor used when converting back from linear (avoids log(0))
#
smooth_spectrogram <- function(amp, method, sigma_t, sigma_f, domain="linear",
                               db_min=-120) {
  if (method == "none" || (sigma_t <= 1 && sigma_f <= 1)) return(amp)

  # -- Convert to linear power if requested ----------------------------------
  if (domain == "linear") {
    amp_work <- 10^(amp / 10)          # dB -> linear power
  } else {
    amp_work <- amp
  }

  # -- Gaussian kernel for a given sigma (returns normalised vector) ---------
  make_gauss <- function(sigma) {
    if (sigma <= 1) return(1)           # identity kernel
    r <- ceiling(sigma * 3)            # radius = 3*sigma
    x <- seq(-r, r)
    g <- exp(-x^2 / (2 * sigma^2))
    g / sum(g)
  }

  # -- 1-D convolution with edge padding -------------------------------------
  conv1d <- function(x, g) {
    if (length(g) == 1) return(x)
    r   <- (length(g) - 1L) %/% 2L
    # Reflect-pad edges so borders aren't darkened
    xp  <- c(rev(x[seq_len(r)]), x, rev(x[(length(x)-r+1):length(x)]))
    out <- stats::filter(xp, g, sides=2)
    out <- as.numeric(out[(r+1):(length(out)-r)])
    # fill any residual NAs at boundaries
    out[is.na(out)] <- x[is.na(out)]
    out
  }

  gt <- make_gauss(sigma_t)     # time kernel
  gf <- make_gauss(sigma_f)     # freq kernel

  switch(method,

    # -- Anisotropic Gaussian: separable 2-D convolution ---------------------
    gaussian = {
      # Along time (rows of amp = freq bins -> operate on columns)
      if (sigma_t > 1)
        for (r in seq_len(nrow(amp_work)))
          amp_work[r, ] <- conv1d(amp_work[r, ], gt)
      # Along freq
      if (sigma_f > 1)
        for (co in seq_len(ncol(amp_work)))
          amp_work[, co] <- conv1d(amp_work[, co], gf)
      amp_work
    },

    # -- Box (uniform) on both axes -------------------------------------------
    `2d_box` = {
      box_t <- if(sigma_t>1) rep(1/(sigma_t*2+1), sigma_t*2+1) else 1
      box_f <- if(sigma_f>1) rep(1/(sigma_f*2+1), sigma_f*2+1) else 1
      if (sigma_t > 1)
        for (r in seq_len(nrow(amp_work))) amp_work[r,] <- conv1d(amp_work[r,], box_t)
      if (sigma_f > 1)
        for (co in seq_len(ncol(amp_work))) amp_work[,co] <- conv1d(amp_work[,co], box_f)
      amp_work
    },

    # -- Gaussian time-only ---------------------------------------------------
    time_gauss = {
      if (sigma_t > 1)
        for (r in seq_len(nrow(amp_work))) amp_work[r,] <- conv1d(amp_work[r,], gt)
      amp_work
    },

    # -- Gaussian freq-only ---------------------------------------------------
    freq_gauss = {
      if (sigma_f > 1)
        for (co in seq_len(ncol(amp_work))) amp_work[,co] <- conv1d(amp_work[,co], gf)
      amp_work
    },

    # -- Median time-only (impulse / click removal) ---------------------------
    time_med = {
      k <- max(3L, as.integer(sigma_t) * 2L + 1L)
      if (k %% 2 == 0) k <- k + 1L
      for (r in seq_len(nrow(amp_work)))
        amp_work[r,] <- runmed(amp_work[r,], k, endrule="keep")
      amp_work
    },

    # -- Median freq-only (narrow-band interference removal) ------------------
    freq_med = {
      k <- max(3L, as.integer(sigma_f) * 2L + 1L)
      if (k %% 2 == 0) k <- k + 1L
      for (co in seq_len(ncol(amp_work)))
        amp_work[,co] <- runmed(amp_work[,co], k, endrule="keep")
      amp_work
    },

    amp_work   # fallback
  ) -> amp_out

  # -- Convert back to dB if we worked in linear domain ---------------------
  if (domain == "linear") {
    amp_out <- pmax(amp_out, 1e-30)     # guard against log(0)
    amp_out <- 10 * log10(amp_out)
    amp_out[!is.finite(amp_out)] <- db_min
  }

  amp_out
}

# -- Load audio -> normalised mono Wave ----------------------------------------
load_audio <- function(path) {
  ext  <- tolower(tools::file_ext(path))
  wave <- NULL

  if (ext == "wav")
    wave <- tryCatch(readWave(path, toWaveMC = FALSE), error = function(e) NULL)

  if (is.null(wave)) {
    tmp <- tempfile(fileext = ".wav")
    on.exit(unlink(tmp), add = TRUE)
    av::av_audio_convert(path, tmp, format = "wav", channels = 1)
    wave <- readWave(tmp, toWaveMC = FALSE)
  }

  # Mix to mono if stereo
  if (wave@stereo) {
    s    <- as.integer((as.numeric(wave@left) + as.numeric(wave@right)) / 2)
    wave <- Wave(left = s, samp.rate = wave@samp.rate,
                 bit = wave@bit, pcm = wave@pcm)
  }

  # Normalise amplitude to unit range for seewave
  wave <- normalize(wave, unit = "1")
  wave
}

# -- Time formatter ------------------------------------------------------------
fmt_time <- function(t) sprintf("%02d:%05.2f", floor(t / 60), t %% 60)

# -- Gradient colorbar drawn into right margin ---------------------------------
draw_colorbar <- function(pal, db_min, db_max, text_color) {
  usr  <- par("usr")
  cx1  <- usr[2] + diff(usr[1:2]) * 0.015
  cx2  <- usr[2] + diff(usr[1:2]) * 0.045
  n    <- length(pal)
  ys   <- seq(usr[3], usr[4], length.out = n + 1)
  for (i in seq_len(n))
    rect(cx1, ys[i], cx2, ys[i+1], col = pal[i], border = NA, xpd = TRUE)
  rect(cx1, usr[3], cx2, usr[4],
       col = NA, border = adjustcolor(text_color, 0.4), xpd = TRUE)
  tks <- pretty(c(db_min, db_max), n = 5)
  tks <- tks[tks >= db_min & tks <= db_max]
  for (tk in tks) {
    yp <- usr[3] + (tk - db_min) / (db_max - db_min) * diff(usr[3:4])
    text(cx2 + diff(usr[1:2]) * 0.012, yp,
         paste0(tk, " dB"), col = text_color, cex = 0.75,
         adj = c(0, 0.5), xpd = TRUE)
  }
}

# -- Main render function -------------------------------------------------------
render_spectrogram_video <- function(audio_file, output_file, fname,
                                     settings, progress_cb = NULL) {

  # 1 -- Load
  wave     <- load_audio(audio_file)
  sr       <- wave@samp.rate
  duration <- length(wave@left) / sr
  nyquist  <- sr / 2

  freq_min <- max(0, settings$freq_min)
  freq_max <- min(nyquist, settings$freq_max)
  if (freq_max <= freq_min) freq_max <- nyquist

  # 2 -- Spectrogram (seewave returns $freq in kHz, $amp in dB)
  # spec <- spectro(wave,
  #                 f    = sr,
  #                 wl   = settings$fft_size,
  #                 wn   = settings$window_fn,
  #                 ovlp = settings$overlap,
  #                 flim = c(freq_min / 1000, freq_max / 1000),
  #                 plot = FALSE,
  #                 norm = FALSE)
  
  spec <- spectro(wave, f=sr, wl=settings$fft_size, wn=settings$window_fn,
                  ovlp=settings$overlap, plot=FALSE, norm=FALSE)  # no flim
  
  freq_hz <- spec$freq * 1000
  keep    <- freq_hz >= freq_min & freq_hz <= freq_max
  if (sum(keep) < 2) keep <- rep(TRUE, length(freq_hz))
  spec$freq <- spec$freq[keep]
  spec$amp  <- spec$amp[keep, , drop=FALSE]

  t_vec <- spec$time
  f_khz <- spec$freq
  amp   <- spec$amp

  # Clean non-finite values (log(0) = -Inf from silent frames)
  amp[!is.finite(amp)] <- settings$db_min
  amp <- pmax(pmin(amp, settings$db_max), settings$db_min)

  # Smooth (domain-aware, anisotropic)
  if (!is.null(settings$smooth_on) && settings$smooth_on)
    amp <- smooth_spectrogram(amp,
             method   = settings$smooth_type,
             sigma_t  = settings$smooth_t,
             sigma_f  = settings$smooth_f,
             domain   = settings$smooth_domain,
             db_min   = settings$db_min)

  # Gamma correction on normalised [0,1] amplitude
  rng      <- settings$db_max - settings$db_min
  amp_disp <- ((amp - settings$db_min) / rng) ^ (1 / max(0.01, settings$gamma)) *
              rng + settings$db_min

  # 3 -- Palette
  pal <- get_palette(settings$color_scheme, 512)

  # 4 -- Frames
  n_frames    <- max(1L, ceiling(duration * settings$framerate))
  tmpdir      <- file.path(tempdir(), paste0("sv_", as.integer(Sys.time())))
  dir.create(tmpdir, showWarnings = FALSE, recursive = TRUE)
  fnames_png  <- file.path(tmpdir, sprintf("frame_%07d.png", seq_len(n_frames)))

  top_mar <- if (settings$show_title) 2.8 else 1.5 # || settings$show_time
  rt_mar  <- if (settings$colorbar) 5.5 else 1.5

  for (i in seq_len(n_frames)) {
    t_now <- (i - 1) / settings$framerate

    png(fnames_png[i], width = settings$width, height = settings$height,
        res = 96, bg = settings$bg_color)
    par(bg       = settings$bg_color,
        mar      = c(3.8, 4.2, top_mar, rt_mar),
        mgp      = c(1.6, 0.5, 0),
        col.axis = settings$text_color,
        col.lab  = settings$text_color,
        fg       = settings$text_color,
        family   = "sans",
        cex.lab  = 1.1)

    image(t_vec, f_khz, t(amp_disp),
          col = pal, zlim = c(settings$db_min, settings$db_max),
          xlab = "Time (s)", ylab = "Frequency (kHz)",
          axes = FALSE, useRaster = TRUE,
          xaxs = "i", yaxs = "i")

    axis(1, col = settings$text_color, col.ticks = settings$text_color,
         col.axis = settings$text_color, cex.axis = 1.0, tcl = -0.3,
         at = pretty(c(0, max(t_vec))))
    axis(2, col = settings$text_color, col.ticks = settings$text_color,
         col.axis = settings$text_color, cex.axis = 1.0, tcl = -0.3, las = 1)
    box(col = adjustcolor(settings$text_color, alpha.f = 0.3))

    if (settings$shade && t_now > min(t_vec))
      rect(min(t_vec), min(f_khz), min(t_now, max(t_vec)), max(f_khz),
           col = adjustcolor("#ffffff", 0.24), border = NA)

    if (settings$colorbar)
      draw_colorbar(pal, settings$db_min, settings$db_max, settings$text_color)

    px <- min(t_now, max(t_vec))
    abline(v = px, col = adjustcolor(settings$bar_color, 0.22),
           lwd = settings$bar_width * 4)
    abline(v = px, col = settings$bar_color, lwd = settings$bar_width)

    if (settings$show_title)
      mtext(fname, side = 3, line = 0.4, #if (settings$show_time) 1.4 else
            col = settings$text_color, cex = 0.75, adj = 0, font = 2)

    # if (settings$show_time)
    #   mtext(fmt_time(t_now), side = 3, line = 0.3,
    #         col = adjustcolor(settings$bar_color, 0.95),
    #         cex = 0.72, adj = 1, font = 2)

    dev.off()

    if (!is.null(progress_cb))
      progress_cb(i / n_frames, sprintf("frame %d / %d", i, n_frames))
  }
  
  # 5 -- Encode
  # AAC codec only supports specific sample rates.
  # Snap to the nearest valid rate to avoid "avcodec_open2 (audio): Invalid argument".
  aac_valid_rates <- c(8000L, 11025L, 12000L, 16000L, 22050L, 24000L,
                       32000L, 44100L, 48000L, 96000L)
  aac_max <- 96000L
  
  src_sr <- tryCatch({
    as.integer(av::av_media_info(audio_file)$audio$sample_rate[1])
  }, error = function(e) 44100L)
  
  if (is.null(src_sr) || is.na(src_sr)) src_sr <- 44100L
  
  # Find the nearest valid AAC sample rate (cap at 96kHz)
  capped_sr <- min(src_sr, aac_max)
  target_sr <- aac_valid_rates[which.min(abs(aac_valid_rates - capped_sr))]
  
  if (target_sr != src_sr) {
    audio_for_encode <- tempfile(fileext = ".wav")
    on.exit(unlink(audio_for_encode), add = TRUE)
    av::av_audio_convert(audio_file, audio_for_encode,
                         format = "wav", sample_rate = target_sr)
  } else {
    audio_for_encode <- audio_file
  }
  
  av_encode_video(
    input     = fnames_png,
    output    = output_file,
    framerate = settings$framerate,
    audio     = audio_for_encode,
    vfilter   = "format=yuv420p"
  )

  unlink(tmpdir, recursive = TRUE)
  invisible(output_file)
}
