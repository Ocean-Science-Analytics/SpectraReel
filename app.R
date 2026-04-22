# ============================================================
#  Spectrogram Video Generator -- Shiny App
#  With live preview, audio playback & scrubbing
# ============================================================

required_pkgs <- c("shiny","bslib","shinyjs","shinyWidgets",
                   "av","tuneR","seewave","viridisLite")
missing_pkgs  <- required_pkgs[!required_pkgs %in% rownames(installed.packages())]
if (length(missing_pkgs) > 0)
  install.packages(missing_pkgs, repos="https://cran.rstudio.com/",
                   dependencies=TRUE, quiet=TRUE)

library(shiny); library(bslib); library(shinyjs); library(shinyWidgets)
library(av); library(tuneR); library(seewave); library(viridisLite)

source("render_utils.R")


# -- CSS ----------------------------------------------------------------------
css <- "
:root {
  --bg-deep:#09090b; --bg-card:#18181b; --bg-input:#27272a;
  --border:#3f3f46;  --accent:#8b5cf6;  --accent2:#06b6d4;
  --text:#e4e4e7;    --muted:#71717a;   --success:#22c55e;
}
body,.shiny-server-status{background:var(--bg-deep)!important;color:var(--text)}
.container-fluid{max-width:1500px;padding:0 1.2rem}
.sidebar-panel{background:var(--bg-card)!important;border:1px solid var(--border)!important;
  border-radius:12px;padding:1.2rem!important;height:fit-content}
.main-panel{padding-left:1.2rem}
.sv-card{background:var(--bg-card);border:1px solid var(--border);border-radius:10px;
  padding:1.1rem 1.3rem;margin-bottom:.9rem}
.sec-head{color:var(--accent2);font-size:.67rem;font-weight:700;letter-spacing:.1em;
  text-transform:uppercase;margin:.9rem 0 .5rem;display:flex;align-items:center;gap:.4rem}
.sec-head::after{content:'';flex:1;height:1px;background:var(--border)}
.form-control,.selectize-input,.selectize-dropdown{background:var(--bg-input)!important;
  color:var(--text)!important;border-color:var(--border)!important;border-radius:6px!important}
.selectize-dropdown-content .option{color:var(--text);background:var(--bg-input)}
.selectize-dropdown-content .option:hover{background:#3f3f46}
label{color:#a1a1aa!important;font-size:.79rem!important;font-weight:500!important}
.irs--shiny .irs-bar{background:var(--accent);border-color:var(--accent)}
.irs--shiny .irs-single,.irs--shiny .irs-from,.irs--shiny .irs-to{background:var(--accent);font-size:.7rem}
.irs--shiny .irs-handle{border-color:var(--accent)}
.irs--shiny .irs-line{background:var(--border)}

/* Transport buttons */
.btn-transport{background:var(--bg-input)!important;border:1px solid var(--border)!important;
  color:var(--text)!important;border-radius:8px!important;padding:.4rem .9rem!important;
  font-size:1rem!important;line-height:1;transition:all .15s}
.btn-transport:hover{background:#3f3f46!important;border-color:var(--accent)!important}
.btn-play{background:var(--accent)!important;border-color:var(--accent)!important;color:#fff!important}
.btn-play:hover{opacity:.85!important}

/* Render buttons */
.btn-render{background:linear-gradient(135deg,var(--accent),#7c3aed)!important;
  border:none!important;color:#fff!important;font-weight:700!important;width:100%!important;
  padding:.6rem!important;border-radius:8px!important;font-size:.88rem!important;margin-bottom:.45rem!important;
  transition:opacity .15s,box-shadow .15s,transform .1s!important}
.btn-render:hover{opacity:.88!important;box-shadow:0 0 0 3px rgba(139,92,246,.35),0 4px 18px rgba(124,58,237,.45)!important;transform:translateY(-1px)!important}
.btn-render:active{opacity:1!important;transform:translateY(0)!important}
.btn-batch{background:linear-gradient(135deg,#059669,var(--success))!important;
  border:none!important;color:#fff!important;font-weight:700!important;width:100%!important;
  padding:.6rem!important;border-radius:8px!important;font-size:.88rem!important;margin-bottom:.45rem!important}
.btn-dl{background:linear-gradient(135deg,#0891b2,var(--accent2))!important;
  border:none!important;color:#fff!important;font-weight:700!important;
  padding:.5rem 1.3rem!important;border-radius:8px!important;font-size:.83rem!important}

/* Badges */
.badge-idle{background:#27272a;color:#71717a;border:1px solid #3f3f46;padding:.28rem .85rem;border-radius:20px;font-size:.73rem;font-weight:600}
.badge-running{background:#1e1b4b;color:#a5b4fc;border:1px solid #4338ca;padding:.28rem .85rem;border-radius:20px;font-size:.73rem;font-weight:600}
.badge-done{background:#052e16;color:#86efac;border:1px solid #16a34a;padding:.28rem .85rem;border-radius:20px;font-size:.73rem;font-weight:600}
.badge-error{background:#450a0a;color:#fca5a5;border:1px solid #b91c1c;padding:.28rem .85rem;border-radius:20px;font-size:.73rem;font-weight:600}
.badge-preview{background:#1c1917;color:#fcd34d;border:1px solid #92400e;padding:.28rem .85rem;border-radius:20px;font-size:.73rem;font-weight:600}

/* Progress */
.progress{background:var(--bg-input);border-radius:20px;height:7px}
.progress-bar{background:linear-gradient(90deg,var(--accent),var(--accent2));border-radius:20px}

/* Scrub slider -- make it look like a timeline */
#scrub_slider .irs--shiny .irs-bar{background:var(--accent2);border-color:var(--accent2)}
#scrub_slider .irs--shiny .irs-single{background:var(--accent2)}
#scrub_slider .irs--shiny .irs-handle{border-color:var(--accent2);background:#fff}

/* Square render/download box */
#sv-output-box{width:100%;min-height:270px;border-radius:10px;
  display:flex;flex-direction:column;align-items:center;justify-content:center;
  gap:1rem;transition:all .35s ease;box-sizing:border-box;padding:1.5rem}
#sv-output-box.state-idle{display:none}
#sv-output-box.state-rendering{
  background:linear-gradient(135deg,#1a1033 0%,#18181b 100%);
  border:1px solid rgba(139,92,246,.4)}
#sv-output-box.state-done{
  background:linear-gradient(135deg,#052e16 0%,#18181b 100%);
  border:1px solid rgba(34,197,94,.4)}
#sv-output-box.state-error{
  background:linear-gradient(135deg,#2d0a0a 0%,#18181b 100%);
  border:1px solid rgba(185,28,28,.4)}
.sv-box-spinner{width:52px;height:52px;border:4px solid rgba(139,92,246,.2);
  border-top-color:var(--accent);border-radius:50%;
  animation:sv-spin .8s linear infinite}
@keyframes sv-spin{to{transform:rotate(360deg)}}
@keyframes sv-pulse{0%,100%{opacity:1}50%{opacity:.4}}
.sv-box-title{font-size:1rem;font-weight:700;letter-spacing:.04em;text-align:center}
.sv-box-sub{font-size:.75rem;color:var(--muted);text-align:center;line-height:1.5}
.sv-box-pct{font-family:'Courier New',monospace;font-size:2rem;font-weight:700;
  color:var(--accent);animation:sv-pulse 1.8s ease-in-out infinite}
.sv-box-progress{width:80%;height:6px;background:var(--bg-input);border-radius:20px;overflow:hidden}
.sv-box-progress-bar{height:100%;width:0%;border-radius:20px;
  background:linear-gradient(90deg,var(--accent),var(--accent2));transition:width .3s ease}
.sv-dl-btn{background:linear-gradient(135deg,#0891b2,var(--accent2))!important;
  border:none!important;color:#fff!important;font-weight:700!important;
  padding:.65rem 1.8rem!important;border-radius:8px!important;font-size:.9rem!important;
  margin-top:.5rem!important}
.sv-checkmark{font-size:2.8rem;color:var(--success)}

/* Preview plot container */
.preview-wrap{position:relative;background:#000;border-radius:8px;overflow:hidden}
.preview-wrap .shiny-plot-output{display:block}

/* Canvas playhead overlay */
.preview-wrap{position:relative;background:#000;border-radius:8px;overflow:hidden}
.preview-wrap .shiny-plot-output{display:block}
#playhead-canvas{position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none}

/* Time display */
.time-display{font-family:'Courier New',monospace;font-size:1.05rem;font-weight:700;
  color:var(--accent2);letter-spacing:.05em;min-width:6rem;text-align:center}

/* File table */
.table{color:var(--text)!important}
.table th{color:var(--muted)!important;font-size:.73rem;text-transform:uppercase;border-color:var(--border)!important}
.table td{border-color:var(--border)!important;font-size:.83rem}

.app-title h2{color:var(--text);font-size:1.5rem;font-weight:700;margin:0}
.app-title p{color:var(--muted);font-size:.83rem;margin:.2rem 0 0}
.file-list-scroll{max-height:180px;overflow-y:auto}
hr.sv-hr{border-color:var(--border);margin:.8rem 0}
"

# -- UI ------------------------------------------------------------------------
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$script(src = "audio_player.js"),
    tags$style(HTML(css))
  ),
  theme = bs_theme(bootswatch="darkly", base_font=font_google("Inter")),

  div(style="padding:1.2rem 0 .8rem",
      div(class="app-title",
          div(style="display:flex;align-items:center;gap:.85rem",
              tags$img(src = "white_square_OSA_med.jpg", style = "height:52px;..."),
              div(
                h2(HTML("SpectraReel")),
                p("Preview and download audio files to MP4")
              )
          )
      )
  ),

  sidebarLayout(
    # -- SIDEBAR --------------------------------------------------------------
    sidebarPanel(width=4, class="sidebar-panel",

      fileInput("audio_single","Upload Audio File",
          accept=c(".wav",".mp3",".flac",".ogg",".m4a"),
          buttonLabel="Browse..."),

      tags$hr(class="sv-hr"),
      div(class="sec-head", HTML("&#127897; FFT / SPECTROGRAM")),

      selectInput("fft_size","FFT Window Size",
        choices=c("64"=64,"128"=128,"256"=256,"512"=512,
                  "1024 *"=1024,"2048"=2048,
                  "4096"=4096,"8192"=8192),
        selected=1024),

      selectInput("window_fn","Window Function",
        choices=c("Hanning *"="hanning","Hamming"="hamming",
                  "Blackman"="blackman","Bartlett"="bartlett",
                  "Rectangle"="rectangle","Flattop"="flattop"),
        selected="hanning"),

      fluidRow(
        column(8,
          selectInput("hop_frac","Hop Size (fraction of FFT)",
            choices=c(
              "1/2 -- 50% overlap"               = "0.5",
              "1/4 -- 75% overlap *"  = "0.25",
              "1/8 -- 87.5% overlap"             = "0.125",
              "1/16 -- 93.75% overlap"           = "0.0625",
              "3/4 -- 25% overlap"               = "0.75",
              "1/1 -- 0% overlap (fastest)"      = "1.0"
            ), selected="0.25")
        ),
        column(4,
          tags$div(style="margin-top:1.6rem",
            uiOutput("hop_info")
          )
        )
      ),

      fluidRow(
        column(6, numericInput("freq_min","Min Freq (Hz)",0,    min=0,    max=20000,step=50)),
        column(6, numericInput("freq_max","Max Freq (Hz)",16000, min=100,  max=96000,step=100))
      ),

      tags$hr(class="sv-hr"),
      div(class="sec-head", HTML("&#128266; AMPLITUDE")),
      sliderInput("db_range","dB Range",-120,0,c(-80,0),step=5),
      sliderInput("gamma","Gamma (brighten low values)",0.2,3.0,1.0,step=0.1),

      tags$hr(class="sv-hr"),
      div(class="sec-head", HTML("&#127327; SMOOTHING")),

      fluidRow(
        column(6,
          prettyToggle("smooth_on",
            label_on  = "Smoothing ON",
            label_off = "Smoothing OFF",
            value     = FALSE,
            status_on = "success", status_off = "default",
            icon_on   = icon("check"), icon_off = icon("times"))
        ),
        column(6,
          conditionalPanel("input.smooth_on == true",
            uiOutput("smooth_preview_label")
          )
        )
      ),

      conditionalPanel("input.smooth_on == true",
        selectInput("smooth_type","Smoothing Method",
          choices = c(
            "Anisotropic Gaussian * (separate time/freq sigma)" = "gaussian",
            "2D Box (fast, uniform)"                            = "2d_box",
            "Time only -- Gaussian"                              = "time_gauss",
            "Frequency only -- Gaussian"                         = "freq_gauss",
            "Time only -- Median (removes clicks)"               = "time_med",
            "Frequency only -- Median (removes tones)"           = "freq_med"
          ), selected = "gaussian"),

        selectInput("smooth_domain","Apply smoothing in",
          choices = c(
            "Linear power domain * (more natural)" = "linear",
            "dB domain (sharper edges)"            = "db"
          ), selected = "linear"),

        fluidRow(
          column(6,
            sliderInput("smooth_t","Time smoothing (sigma)",
              min=1, max=15, value=3, step=1, ticks=FALSE)
          ),
          column(6,
            sliderInput("smooth_f","Freq smoothing (sigma)",
              min=1, max=15, value=2, step=1, ticks=FALSE)
          )
        ),
        tags$small(style="color:#71717a;font-size:.7rem;line-height:1.4",
          "sigma = Gaussian std dev in spectrogram bins. ",
          "Higher = more blur. Set one to 1 to smooth only the other axis.")
      ),

      tags$hr(class="sv-hr"),
      div(class="sec-head", HTML("&#127912; VISUAL STYLE")),

      selectInput("color_scheme","Color Palette",
        choices=c("Magma *"="magma","Viridis"="viridis","Plasma"="plasma",
                  "Inferno"="inferno","Cividis"="cividis","Hot"="hot",
                  "Cool Blue"="cool","Deep Blue->White"="deepblue",
                  "Green Phosphor"="phosphor"),
        selected="magma"),

      fluidRow(
        column(6,
          selectInput("bg_color","Background",
            choices=c("Black"="#000000","Deep Slate"="#0f172a",
                      "Dark Charcoal"="#1a1a2e","White"="#ffffff"),
            selected="#000000")
        ),
        column(6,
          selectInput("text_color","Axis / Text",
            choices=c("White"="#ffffff","Light Gray"="#cccccc",
                      "Cyan"="#00e5ff","Black"="#000000"),
            selected="#ffffff")
        )
      ),

      fluidRow(
        column(6,
          tags$div(
            tags$label("Playhead Color", style="display:block;color:#a1a1aa!important;font-size:.79rem!important;font-weight:500!important;margin-bottom:4px"),
            tags$div(style="display:flex;align-items:center;gap:6px",
              tags$input(id="bar_color_swatch", type="color", value="#00ff88",
                style="width:36px;height:32px;padding:2px;border-radius:6px;border:1px solid #3f3f46;background:#27272a;cursor:pointer"),
              textInput("bar_color",NULL,value="#00ff88",placeholder="#00ff88",width="100%")
            ),
            tags$script(HTML("
              $(document).on('shiny:sessioninitialized',function(){
                $('#bar_color_swatch').on('input',function(){
                  $('#bar_color').val(this.value).trigger('change');
                  Shiny.setInputValue('bar_color',this.value);
                });
                $('#bar_color').on('input',function(){
                  if(/^#[0-9a-fA-F]{6}$/.test(this.value))
                    $('#bar_color_swatch').val(this.value);
                });
              });
            "))
          )
        ),
        column(6,
          numericInput("bar_width","Playhead Width (px)",2,min=1,max=8)
        )
      ),

      checkboxGroupInput("visual_opts","Visual Options",
        choices=c("Shade played region"="shade","Show filename title"="title",
                  "Show colorbar"="colorbar"), #"Show elapsed time"="time_label",
        selected=c("title")),

      tags$hr(class="sv-hr"),
      div(class="sec-head", HTML("&#127909; OUTPUT (MP4)")),
      fluidRow(
        column(6, numericInput("vid_width", "Width (px)", 1280,min=640,max=3840,step=64)),
        column(6, numericInput("vid_height","Height (px)", 720,min=360,max=2160,step=64))
      ),
      sliderInput("framerate","Framerate (fps)",5,60,25,step=5),

      tags$hr(class="sv-hr"),
      actionButton("btn_render",HTML("&#9654;  Export MP4"),        class="btn btn-render"),

    ),

    # -- MAIN PANEL ------------------------------------------------------------
    mainPanel(width=8, class="main-panel",

      # Status row
      fluidRow(column(12,
        div(style="display:flex;align-items:center;gap:.9rem;margin-bottom:.8rem",
          uiOutput("status_badge"),
          uiOutput("file_info_text")
        )
      )),

      # -- LIVE PREVIEW CARD --------------------------------------------------
      div(class="sv-card",
        div(class="sec-head", HTML("&#128065; LIVE PREVIEW")),

        # Spectrogram plot
        div(class="preview-wrap",
            plotOutput("preview_plot",
                       height="420px",
                       click="plot_click"),
            tags$canvas(id="playhead-canvas", height="420")
        ),

        tags$br(),

        # Scrub slider
        div(id="scrub_slider",
          uiOutput("scrub_ui")
        ),

        # Transport controls
        div(style="display:flex;align-items:center;gap:.6rem;margin-top:.7rem;flex-wrap:wrap",
          actionButton("btn_play",  HTML("&#9654;"),  class="btn btn-transport btn-play",
                       title="Play"),
          actionButton("btn_pause", HTML("&#9646;&#9646;"), class="btn btn-transport",
                       title="Pause"),
          actionButton("btn_stop",  HTML("&#9632;"),  class="btn btn-transport",
                       title="Stop / rewind"),
          div(style="width:1px;height:28px;background:var(--border);margin:0 .2rem"),
          div(class="time-display", uiOutput("time_display_ui")),
          div(style="flex:1"),
          tags$small(style="color:var(--muted);font-size:.72rem",
            "Click spectrogram to seek")
        )
      ),

      # Settings summary
      div(class="sv-card",
        div(class="sec-head","SETTINGS SUMMARY"),
        verbatimTextOutput("settings_summary")
      ),

      # -- OUTPUT BOX (invisible until render clicked) -------------------------
      div(id="sv-output-box", class="state-idle",

        # Rendering state contents
        div(id="sv-box-rendering",
          style="display:none;flex-direction:column;align-items:center;gap:1rem;width:100%",
          div(class="sv-box-spinner"),
          div(class="sv-box-title", style="color:#a5b4fc", "Rendering MP4 File"),
          div(class="sv-box-pct", id="sv-box-pct-text", "0%"),
          div(class="sv-box-progress",
            div(class="sv-box-progress-bar", id="sv-box-prog-bar")
          ),
          div(class="sv-box-sub", id="sv-box-frame-text", "Starting...")
        ),

        # Done state contents
        div(id="sv-box-done",
          style="display:none;flex-direction:column;align-items:center;gap:.8rem;width:100%",
          div(class="sv-checkmark", HTML("&#10003;")),
          div(class="sv-box-title", style="color:var(--success)", "MP4 Ready!"),
          div(class="sv-box-sub", "Your spectrogram video is ready to download."),
          uiOutput("dl_button_ui")
        ),

        # Error state contents
        div(id="sv-box-error",
          style="display:none;flex-direction:column;align-items:center;gap:.8rem;width:100%",
          div(style="font-size:2.5rem", HTML("&#9888;")),
          div(class="sv-box-title", style="color:#fca5a5", "Render Failed"),
          uiOutput("error_msg_ui")
        )
      )
    )
  )
)

# -- SERVER --------------------------------------------------------------------
server <- function(input, output, session) {

  rv <- reactiveValues(
    status        = "idle",
    progress      = 0,
    output_files  = NULL,
    error_msg     = NULL,
    cur_file      = "",
    # preview state
    playhead      = 0,
    duration      = 0,
    playing       = FALSE,
    audio_url     = NULL,
    audio_path    = NULL,   # explicit file path -- drives spec_data invalidation
    audio_name    = ""      # display name for title overlay
  )

  # -- Reactive: current settings list -----------------------------------------
  settings <- reactive({
    list(
      fft_size     = as.integer(input$fft_size),
      window_fn    = input$window_fn,
      hop_frac    = as.numeric(input$hop_frac),
      overlap     = round((1 - as.numeric(input$hop_frac)) * 100),
      freq_min     = input$freq_min,
      freq_max     = input$freq_max,
      db_min       = input$db_range[1],
      db_max       = input$db_range[2],
      gamma        = input$gamma,
      color_scheme = input$color_scheme,
      bg_color     = input$bg_color,
      text_color   = input$text_color,
      bar_color    = input$bar_color,
      bar_width    = input$bar_width,
      shade        = "shade"      %in% input$visual_opts,
      show_title   = "title"      %in% input$visual_opts,
      #show_time    = "time_label" %in% input$visual_opts,
      colorbar     = "colorbar"   %in% input$visual_opts,
      width        = input$vid_width,
      height       = input$vid_height,
      framerate    = input$framerate,
      smooth_on     = isTRUE(input$smooth_on),
      smooth_type   = (if(isTRUE(input$smooth_on)) input$smooth_type   else "none"),
      smooth_domain = (if(isTRUE(input$smooth_on)) input$smooth_domain else "db"),
      smooth_t      = (if(isTRUE(input$smooth_on)) as.integer(input$smooth_t) else 1L),
      smooth_f      = (if(isTRUE(input$smooth_on)) as.integer(input$smooth_f) else 1L)
    )
  })

  # -- Reactive: compute spectrogram (expensive -- only on file/FFT changes) ---
  spec_data <- reactive({
    req(rv$audio_path)          # depends on explicit rv value -- always updates
    s <- settings()

    withProgress(message="Computing spectrogram...", value=0.3, {
      wave <- load_audio(rv$audio_path)
      sr   <- wave@samp.rate
      nyq  <- sr / 2
      fmin <- max(0, s$freq_min)
      fmax <- min(nyq, s$freq_max); if(fmax<=fmin) fmax <- nyq

      spec <- spectro(wave,
                      f=sr, wl=s$fft_size, wn=s$window_fn, ovlp=s$overlap,
                      flim=c(fmin/1000, fmax/1000),
                      plot=FALSE, norm=FALSE)
      incProgress(0.6)

      amp <- spec$amp
      amp[!is.finite(amp)] <- s$db_min
      amp <- pmax(pmin(amp, s$db_max), s$db_min)

      # Smooth (domain + method aware)
      if (s$smooth_on)
        amp <- smooth_spectrogram(amp, s$smooth_type, s$smooth_t, s$smooth_f,
                                  s$smooth_domain, s$db_min)

      rng <- s$db_max - s$db_min
      amp_disp <- ((amp - s$db_min)/rng)^(1/max(.01,s$gamma)) * rng + s$db_min

      list(t=spec$time, f=spec$freq, amp=amp_disp,
           duration=max(spec$time),
           sr=sr)
    })
  })

  # -- Load audio into browser when file uploaded -----------------------------
  observeEvent(input$audio_single, {
    req(input$audio_single)
    rv$playing    <- FALSE
    rv$playhead   <- 0
    rv$duration   <- 0
    rv$audio_path <- input$audio_single$datapath   # triggers spec_data recompute
    rv$audio_name <- input$audio_single$name

    # Convert to wav for base64 encoding
    src  <- input$audio_single$datapath
    ext  <- tolower(tools::file_ext(src))
    dest <- file.path(tempdir(), paste0("preview_audio.wav"))

    tryCatch({
      # Convert to WAV if needed
      if (ext == "wav") {
        file.copy(src, dest, overwrite=TRUE)
      } else {
        av::av_audio_convert(src, dest, format="wav", channels=1)
      }
      # Encode as base64 data URI -- works on any host without URL routing
      raw_bytes <- readBin(dest, "raw", n=file.info(dest)$size)
      b64       <- jsonlite::base64_enc(raw_bytes)
      data_uri  <- paste0("data:audio/wav;base64,", b64)
      rv$audio_url <- data_uri
      session$sendCustomMessage("loadAudio", data_uri)
      session$sendCustomMessage("setPlayheadStyle",
                                list(color = input$bar_color, width = input$bar_width))
    }, error=function(e) message("Audio load error: ", e$message))
  })
  
  observeEvent(c(input$bar_color, input$bar_width), {
    session$sendCustomMessage("setPlayheadStyle",
                              list(color = input$bar_color, width = input$bar_width))
  }, ignoreInit = TRUE)
  
  observeEvent(input$visual_opts, {
    session$sendCustomMessage("setPlayheadStyle",
                              list(color = input$bar_color,
                                   width = input$bar_width,
                                   colorbar = "colorbar" %in% input$visual_opts,
                                   shade    = "shade"    %in% input$visual_opts))
  }, ignoreInit = TRUE)

  # -- Sync duration when browser reports it ----------------------------------
  observeEvent(input$js_audio_duration, {
    rv$duration <- input$js_audio_duration
  })

  # -- Sync playhead from browser timeupdate ----------------------------------
  observeEvent(input$js_audio_time, {
    rv$playhead <- input$js_audio_time
    # Update scrub slider without triggering a seek loop
    updateSliderInput(session,"scrub_pos",
                      value = round(input$js_audio_time, 2))
  })

  # -- Audio ended -> reset playing state --------------------------------------
  observeEvent(input$js_audio_ended, {
    rv$playing  <- FALSE
    rv$playhead <- 0
    updateSliderInput(session,"scrub_pos", value=0)
  })

  # -- Transport: Play ---------------------------------------------------------
  observeEvent(input$btn_play, {
    req(rv$audio_url)
    rv$playing <- TRUE
    session$sendCustomMessage("audioPlay", list())
  })

  # -- Transport: Pause --------------------------------------------------------
  observeEvent(input$btn_pause, {
    rv$playing <- FALSE
    session$sendCustomMessage("audioPause", list())
  })

  # -- Transport: Stop ---------------------------------------------------------
  observeEvent(input$btn_stop, {
    rv$playing  <- FALSE
    rv$playhead <- 0
    session$sendCustomMessage("audioPause", list())
    session$sendCustomMessage("audioSeek", 0)
    updateSliderInput(session,"scrub_pos", value=0)
  })

  # -- Scrub slider -> seek -----------------------------------------------------
  scrub_debounce <- debounce(reactive(input$scrub_pos), 80)
  observeEvent(scrub_debounce(), {
    req(!is.null(input$scrub_pos))
    t <- input$scrub_pos
    if (abs(t - rv$playhead) > 0.15) {   # only seek if moved meaningfully
      rv$playhead <- t
      session$sendCustomMessage("audioSeek", t)
    }
  }, ignoreInit=TRUE)

  # -- Click on spectrogram to seek -------------------------------------------
  observeEvent(input$plot_click, {
    req(rv$duration > 0)
    spec <- tryCatch(spec_data(), error=function(e) NULL)
    req(!is.null(spec))
    t_click <- input$plot_click$x
    t_click <- max(0, min(rv$duration, t_click))
    rv$playhead <- t_click
    session$sendCustomMessage("audioSeek", t_click)
    updateSliderInput(session, "scrub_pos", value=round(t_click,2))
  })

  # -- Smooth preview label ------------------------------------------------------
  output$smooth_preview_label <- renderUI({
    req(input$smooth_on, input$smooth_type, input$smooth_t, input$smooth_f)
    dom <- if(!is.null(input$smooth_domain)) input$smooth_domain else "linear"
    tags$div(style="margin-top:1.55rem",
      tags$span(style="color:#22c55e;font-size:.72rem;font-weight:700",
        sprintf("st=%d sf=%d [%s]",
                as.integer(input$smooth_t),
                as.integer(input$smooth_f),
                (if(dom=="linear") "lin" else "dB")))
    )
  })

  # -- Hop size info display ----------------------------------------------------
  output$hop_info <- renderUI({
    fft  <- as.integer(input$fft_size)
    frac <- as.numeric(input$hop_frac)
    hop  <- round(fft * frac)
    ovlp <- round((1 - frac) * 100)
    tags$div(
      tags$span(style="color:#06b6d4;font-size:.72rem;font-weight:700",
                sprintf("Hop = %d samp", hop)),
      tags$br(),
      tags$span(style="color:#71717a;font-size:.68rem",
                sprintf("(%d%% overlap)", ovlp))
    )
  })

    # -- Scrub UI (dynamic max) --------------------------------------------------
  output$scrub_ui <- renderUI({
    dur <- if(rv$duration > 0) rv$duration else 100
    sliderInput("scrub_pos","",
                min=0, max=round(dur,2), value=0,
                step=0.01, width="100%",
                ticks=FALSE)
  })

  # -- Time display ------------------------------------------------------------
  output$time_display_ui <- renderUI({
    t   <- rv$playhead
    dur <- rv$duration
    mm  <- floor(t/60); ss <- t%%60
    dm  <- floor(dur/60); ds <- dur%%60
    HTML(sprintf("%02d:%05.2f&nbsp;<span style='color:var(--muted);font-size:.75rem'>/ %02d:%05.2f</span>",
                 mm, ss, dm, ds))
  })

  # -- Live preview plot --------------------------------------------------------
  output$preview_plot <- renderPlot({
    t_now <- isolate(rv$playhead)   # isolate -- playhead drawn by canvas JS
    s     <- settings()
    spec  <- tryCatch(spec_data(), error=function(e) NULL)

    # No file loaded
    if (is.null(spec)) {
      par(bg=s$bg_color, mar=c(0,0,0,0))
      plot.new()
      text(.5,.5,"Upload an audio file to see the preview",
           col="#71717a", cex=1.1, family="sans")
      return(invisible())
    }

    pal     <- get_palette(s$color_scheme, 512)
    top_mar <- if(s$show_title) 2.6 else 1.2 #|| s$show_time
    rt_mar  <- if(s$colorbar) 5.2 else 1.2

    par(bg=s$bg_color, mar=c(3.6,3.8,top_mar,rt_mar),
        mgp=c(1.6, 0.5, 0),
        col.axis=s$text_color, col.lab=s$text_color,
        fg=s$text_color, family="sans", cex.lab=1.1)

    image(spec$t, spec$f, t(spec$amp),
          col=pal, zlim=c(s$db_min,s$db_max),
          xlab="Time (s)", ylab="Frequency (kHz)",
          axes=FALSE, useRaster=TRUE,
          xaxs="i", yaxs="i")

    axis(1,col=s$text_color,col.ticks=s$text_color,col.axis=s$text_color,cex.axis=.9,tcl=-.25,
         at=pretty(c(0, spec$duration)))
    axis(2,col=s$text_color,col.ticks=s$text_color,col.axis=s$text_color,cex.axis=.9,tcl=-.25,las=1)
    box(col=adjustcolor(s$text_color,.28))

    # Shade played region
    # if (s$shade && t_now > min(spec$t))
    #   rect(min(spec$t), min(spec$f),
    #        min(t_now,max(spec$t)), max(spec$f),
    #        col=adjustcolor("#ffffff",.07), border=NA)

    # Colorbar
    if (s$colorbar) draw_colorbar(pal, s$db_min, s$db_max, s$text_color)

    # Playhead glow + line
    # px <- min(t_now, max(spec$t))
    # abline(v=px, col=adjustcolor(s$bar_color,.22), lwd=s$bar_width*4)
    # abline(v=px, col=s$bar_color, lwd=s$bar_width)

    # Title
    if (s$show_title)
      mtext(rv$audio_name, side=3,
            line= .3, # (if(s$show_time) 1.3 else 
            col=s$text_color, cex=.72, adj=0, font=2)

    # Time
    # if (s$show_time)
    #   mtext(fmt_time(t_now), side=3, line=.25,
    #         col=adjustcolor(s$bar_color,.95), cex=.7, adj=1, font=2)

  }, bg="#000000")

  # -- Status badge / file info -------------------------------------------------
  output$status_badge <- renderUI({
    cls <- switch(rv$status,
      idle="badge-idle", rendering="badge-running",
      done="badge-done", error="badge-error", "badge-idle")
    lbl <- switch(rv$status,
      idle="Ready", rendering="Rendering...",
      done="Done",  error="Error", "Ready")
    if (!is.null(input$audio_single) && rv$status=="idle")
      lbl <- "Preview ready"
    tags$span(class=cls, lbl)
  })

  output$file_info_text <- renderUI({
    if(!is.null(input$audio_single))
      tags$small(style="color:#71717a",
        input$audio_single$name," (",
        round(input$audio_single$size/1024,1)," KB",
        (if(rv$duration>0) paste0(" · ",round(rv$duration,2),"s") else ""),
        ")")
  })

  # -- Settings summary ---------------------------------------------------------
  output$settings_summary <- renderPrint({
    s <- settings()
    cat(sprintf(
"FFT Window   : %d samples  |  Function: %s  |  Hop: 1/%d (%d%% overlap)
Freq Range   : %d to %d Hz
Amplitude    : %d dB to %d dB  |  Gamma: %.1f
Smoothing    : %s
Color Palette: %s  |  Background: %s
Playhead     : color %s, width %dpx
Video        : %d x %d px @ %d fps
Options      : %s",
      s$fft_size, s$window_fn, round(1/s$hop_frac), s$overlap,
      s$freq_min, s$freq_max,
      s$db_min, s$db_max, s$gamma,
      (if(s$smooth_on) sprintf("%s  st=%d sf=%d [%s]",
        s$smooth_type, s$smooth_t, s$smooth_f, s$smooth_domain) else "off"),
      s$color_scheme, s$bg_color,
      s$bar_color, s$bar_width,
      s$width, s$height, s$framerate,
      paste(Filter(Negate(is.null), list(
              if(s$shade)"shade", if(s$show_title)"title",
              if(s$colorbar)"colorbar")), # if(s$show_time)"time",
            collapse=", ")))
  })

  # -- Progress + box state helpers ---------------------------------------------
  show_box_state <- function(state) {
    # state: "rendering" | "done" | "error"
    runjs(sprintf('
      var box = document.getElementById("sv-output-box");
      box.className = "state-%s";
      ["sv-box-rendering","sv-box-done","sv-box-error"].forEach(function(id){
        var el = document.getElementById(id);
        if(el) el.style.display = "none";
      });
      var active = document.getElementById("sv-box-%s");
      if(active) active.style.display = "flex";
    ', state, state))
  }

  update_progress <- function(frac, label="") {
    rv$progress <- frac; rv$cur_file <- label
    pct <- round(frac * 100)
    runjs(sprintf('
      var pb = document.getElementById("sv-box-prog-bar");
      var pt = document.getElementById("sv-box-pct-text");
      var ft = document.getElementById("sv-box-frame-text");
      if(pb) pb.style.width = "%d%%";
      if(pt) pt.textContent = "%d%%";
      if(ft) ft.textContent = "%s";
    ', pct, pct, label))
  }

  # -- Single export ------------------------------------------------------------
  observeEvent(input$btn_render, {
    req(rv$audio_path)
    rv$playing <- FALSE
    session$sendCustomMessage("audioPause", list())
    rv$status <- "rendering"; rv$output_files <- NULL; rv$error_msg <- NULL
    runjs("document.getElementById('btn_render').classList.add('btn-render-spinning')")
    show_box_state("rendering")
    update_progress(0, "Starting...")
    s        <- settings()
    out_file <- tempfile(fileext=".mp4")
    withProgress(message="Rendering MP4...", value=0, {
      tryCatch({
        render_spectrogram_video(
          audio_file  = rv$audio_path,
          output_file = out_file,
          fname       = input$audio_single$name,
          settings    = s,
          progress_cb = function(frac, msg="") update_progress(frac, msg)
        )
        rv$output_files <- list(list(
          path = out_file,
          name = sub("\\.[^.]+$",".mp4",rv$audio_name)))
        rv$status <- "done"
        update_progress(1, "Complete!")
        runjs("document.getElementById('btn_render').classList.remove('btn-render-spinning')")
        show_box_state("done")
      }, error=function(e) {
        rv$status <- "error"
        rv$error_msg <- conditionMessage(e)
        runjs("document.getElementById('btn_render').classList.remove('btn-render-spinning')")
        show_box_state("error")
      })
    })
  })

  # -- Download button + error msg (rendered into the box) ----------------------
  output$dl_button_ui <- renderUI({
    req(rv$output_files)
    downloadButton("dl_single", HTML("&#128229;&nbsp; Download MP4"), class="btn sv-dl-btn")
  })

  output$error_msg_ui <- renderUI({
    req(rv$error_msg)
    tags$p(style="color:#fca5a5;font-size:.75rem;text-align:center;word-break:break-word",
           rv$error_msg)
  })

  output$dl_single <- downloadHandler(
    filename = function() rv$output_files[[1]]$name,
    content  = function(file) file.copy(rv$output_files[[1]]$path, file)
  )
}

options(shiny.maxRequestSize = 1000 * 1024^2)  # 1 GB upload limit

shinyApp(ui, server)
