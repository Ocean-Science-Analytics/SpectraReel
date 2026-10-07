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
/* ===== Ocean Science Analytics theme ===================================== */
:root {
  --osa-navy:#1E3F6E;   --osa-blue:#2D5DA8;  --osa-steel:#3A74A6;
  --osa-sea:#3796CC;    --osa-sky:#62ADD7;   --osa-foam:#99D0E5;
  --bg-page:#F3F7FA;    --bg-card:#FFFFFF;   --bg-input:#FFFFFF;
  --border:#D6E2EC;     --border-strong:#B9CCDC;
  --text:#1B2B3A;       --muted:#5F7385;     --success:#2E9E6B;
  --accent:var(--osa-blue); --accent2:var(--osa-sea);
}
body,.shiny-server-status{background:var(--bg-page)!important;color:var(--text)}
.container-fluid{max-width:1500px;padding:0 1.2rem}
h1,h2,h3,.osa-title{font-family:'Questrial','Century Gothic','Inter',sans-serif}

/* ---- Header band with subtle wave ---- */
.osa-header{position:relative;overflow:hidden;margin:1.1rem 0 1.1rem;border-radius:14px;
  background:linear-gradient(120deg,var(--osa-navy) 0%,var(--osa-blue) 55%,var(--osa-steel) 100%);
  padding:1.05rem 1.5rem 2.1rem;color:#fff;box-shadow:0 6px 22px rgba(30,63,110,.18)}
.osa-header-inner{position:relative;z-index:2;display:flex;align-items:center;gap:1.1rem}
.osa-header img{height:44px;width:auto;display:block}
.osa-header .osa-divider{width:1px;align-self:stretch;background:rgba(255,255,255,.35)}
.osa-title{color:#fff;font-size:1.65rem;font-weight:400;letter-spacing:.02em;margin:0;line-height:1.1}
.osa-sub{color:rgba(255,255,255,.82);font-size:.84rem;margin:.2rem 0 0}
.osa-wave{position:absolute;left:0;bottom:0;width:200%;height:46px;z-index:1;pointer-events:none;
  animation:osa-drift 48s linear infinite}
.osa-wave path{vector-effect:non-scaling-stroke}
@keyframes osa-drift{from{transform:translateX(0)}to{transform:translateX(-50%)}}
@media (prefers-reduced-motion:reduce){.osa-wave{animation:none}}

/* ---- Footer wave ---- */
.osa-footer{position:relative;margin:1.6rem 0 0;padding:1.4rem 0 1.1rem;text-align:center;
  color:var(--muted);font-size:.74rem;overflow:hidden}
.osa-footer svg{position:absolute;left:0;top:0;width:100%;height:28px;opacity:.55}
.osa-footer a{color:var(--osa-blue);text-decoration:none}

/* ---- Panels & cards ---- */
.sidebar-panel{background:var(--bg-card)!important;border:1px solid var(--border)!important;
  border-radius:12px;padding:1.2rem!important;height:fit-content;
  box-shadow:0 1px 3px rgba(30,63,110,.06)}
.main-panel{padding-left:1.2rem}
.sv-card{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;
  padding:1.1rem 1.3rem;margin-bottom:.9rem;box-shadow:0 1px 3px rgba(30,63,110,.06)}
.sec-head{color:var(--osa-blue);font-size:.68rem;font-weight:700;letter-spacing:.11em;
  text-transform:uppercase;margin:.9rem 0 .6rem;display:flex;align-items:center;gap:.45rem}
.sec-head::after{content:'';flex:1;height:1px;background:linear-gradient(90deg,var(--border-strong),transparent)}
.sec-head .ico{color:var(--osa-sea)}

/* ---- Inputs ---- */
.form-control,.selectize-input,.selectize-dropdown{background:var(--bg-input)!important;
  color:var(--text)!important;border-color:var(--border-strong)!important;border-radius:6px!important;box-shadow:none!important}
.form-control:focus,.selectize-input.focus{border-color:var(--osa-sea)!important;
  box-shadow:0 0 0 3px rgba(55,150,204,.18)!important}
.selectize-dropdown-content .option{color:var(--text);background:#fff}
.selectize-dropdown-content .option.active,.selectize-dropdown-content .option:hover{background:#E8F2F9;color:var(--osa-navy)}
label,.control-label{color:#3E5468!important;font-size:.79rem!important;font-weight:600!important}
.form-group{margin-bottom:.85rem}
.input-group .btn{background:var(--osa-steel)!important;border-color:var(--osa-steel)!important;color:#fff!important}
.progress{background:#E3ECF3;border-radius:20px;height:7px}
.progress-bar{background:linear-gradient(90deg,var(--osa-blue),var(--osa-sky));border-radius:20px}

/* Sliders */
.irs--shiny .irs-bar{background:var(--osa-blue);border-color:var(--osa-blue)}
.irs--shiny .irs-single,.irs--shiny .irs-from,.irs--shiny .irs-to{background:var(--osa-blue);font-size:.7rem}
.irs--shiny .irs-single:before,.irs--shiny .irs-from:before,.irs--shiny .irs-to:before{border-top-color:var(--osa-blue)}
.irs--shiny .irs-handle{border-color:var(--osa-blue)}
.irs--shiny .irs-line{background:#E3ECF3;border-color:#E3ECF3}
.irs--shiny .irs-min,.irs--shiny .irs-max,.irs--shiny .irs-grid-text{color:var(--muted);background:transparent}

/* ---- FIX: checkbox overlapping its box/label ----
   Shiny's BS3-compat CSS absolutely positions the checkbox with a negative
   margin, which pushes it over the panel edge / label text under BS5.  */
.shiny-input-checkboxgroup .checkbox,.shiny-input-container .checkbox{margin:.1rem 0 .35rem;padding:0}
.shiny-input-checkboxgroup .checkbox label,.shiny-input-container .checkbox label{
  display:flex!important;align-items:center;gap:.55rem;padding-left:0!important;margin:0;
  cursor:pointer;color:var(--text)!important;font-weight:500!important;font-size:.82rem!important}
.shiny-input-checkboxgroup .checkbox input[type=checkbox],.shiny-input-container .checkbox input[type=checkbox]{
  position:static!important;margin:0!important;flex:0 0 auto;width:1rem;height:1rem;
  accent-color:var(--osa-blue);cursor:pointer}

/* Smoothing switch (prettySwitch) */
.pretty{margin-right:0}
.pretty .state label{color:var(--text)!important;font-weight:600!important;font-size:.82rem!important}
.pretty.p-switch.p-fill input:checked~.state.p-primary:before{background-color:var(--osa-blue)!important;border-color:var(--osa-blue)!important}
.pretty.p-switch input:checked~.state.p-primary:before{border-color:var(--osa-blue)!important}

/* Playhead colour row: swatch + hex field aligned on one line */
.ph-row{display:flex;align-items:center;gap:6px}
.ph-row .form-group{margin:0!important;flex:1}
.ph-row input[type=color]{width:38px;height:36px;padding:2px;border-radius:6px;
  border:1px solid var(--border-strong);background:#fff;cursor:pointer;flex:0 0 auto}

/* ---- Buttons ---- */
.btn-transport{background:#fff!important;border:1px solid var(--border-strong)!important;
  color:var(--osa-navy)!important;border-radius:8px!important;padding:.4rem .9rem!important;
  font-size:1rem!important;line-height:1;transition:all .15s}
.btn-transport:hover{background:#EAF3FA!important;border-color:var(--osa-sea)!important}
.btn-play{background:var(--osa-blue)!important;border-color:var(--osa-blue)!important;color:#fff!important}
.btn-play:hover{background:var(--osa-navy)!important}
.btn-render{background:linear-gradient(135deg,var(--osa-blue),var(--osa-sea))!important;
  border:none!important;color:#fff!important;font-weight:700!important;width:100%!important;
  padding:.65rem!important;border-radius:8px!important;font-size:.9rem!important;margin-bottom:.45rem!important;
  letter-spacing:.02em;transition:box-shadow .15s,transform .1s,filter .15s!important}
.btn-render:hover{filter:brightness(1.06);box-shadow:0 0 0 3px rgba(55,150,204,.25),0 6px 18px rgba(45,93,168,.3)!important;transform:translateY(-1px)!important}
.btn-render:active{transform:translateY(0)!important}
.btn-dl,.sv-dl-btn{background:linear-gradient(135deg,var(--osa-blue),var(--osa-sea))!important;
  border:none!important;color:#fff!important;font-weight:700!important;
  padding:.65rem 1.8rem!important;border-radius:8px!important;font-size:.9rem!important;margin-top:.5rem!important;
  letter-spacing:.02em;transition:box-shadow .15s,transform .1s,filter .15s!important}
.btn-dl:hover,.sv-dl-btn:hover{filter:brightness(1.06);box-shadow:0 0 0 3px rgba(55,150,204,.25),0 6px 18px rgba(45,93,168,.3)!important;transform:translateY(-1px)!important}
.btn-dl:active,.sv-dl-btn:active{transform:translateY(0)!important}

/* ---- Status badges ---- */
.badge-idle,.badge-running,.badge-done,.badge-error,.badge-preview{padding:.28rem .85rem;border-radius:20px;font-size:.73rem;font-weight:600;border:1px solid}
.badge-idle{background:#EEF3F7;color:var(--muted);border-color:var(--border)}
.badge-running{background:#E6F1FA;color:var(--osa-blue);border-color:#9CC4E4}
.badge-done{background:#E7F6EF;color:#1F7A51;border-color:#9ED6BC}
.badge-error{background:#FDECEC;color:#B42318;border-color:#F3B5B0}
.badge-preview{background:#FFF6E5;color:#9A5B00;border-color:#F2CF8C}

/* ---- Render / download box ---- */
#sv-output-box{width:100%;min-height:270px;border-radius:12px;position:relative;overflow:hidden;
  display:flex;flex-direction:column;align-items:center;justify-content:center;
  gap:1rem;transition:all .35s ease;box-sizing:border-box;padding:1.5rem}
#sv-output-box.state-idle{display:none}
#sv-output-box.state-rendering{background:linear-gradient(160deg,#EAF3FA 0%,#fff 70%);border:1px solid #9CC4E4}
#sv-output-box.state-done{background:linear-gradient(160deg,#BFE6D1 0%,#fff 70%);border:1px solid #9ED6BC}
#sv-output-box.state-error{background:linear-gradient(160deg,#FDECEC 0%,#fff 70%);border:1px solid #F3B5B0}
.sv-box-spinner{width:52px;height:52px;border:4px solid rgba(55,150,204,.2);
  border-top-color:var(--osa-blue);border-radius:50%;animation:sv-spin .8s linear infinite}
@keyframes sv-spin{to{transform:rotate(360deg)}}
@keyframes sv-pulse{0%,100%{opacity:1}50%{opacity:.45}}
.sv-box-title{font-size:1rem;font-weight:700;letter-spacing:.04em;text-align:center}
.sv-box-sub{font-size:.76rem;color:var(--muted);text-align:center;line-height:1.5}
.sv-box-pct{font-family:'Courier New',monospace;font-size:2rem;font-weight:700;
  color:var(--osa-blue);animation:sv-pulse 1.8s ease-in-out infinite}
.sv-box-progress{width:80%;height:6px;background:#E3ECF3;border-radius:20px;overflow:hidden}
.sv-box-progress-bar{height:100%;width:0%;border-radius:20px;
  background:linear-gradient(90deg,var(--osa-blue),var(--osa-sky));transition:width .3s ease}
.sv-checkmark{font-size:2.8rem;color:var(--success)}

/* ---- Preview ---- */
.preview-wrap{position:relative;background:#000;border-radius:8px;overflow:hidden}
.preview-wrap .shiny-plot-output{display:block}
#playhead-canvas{position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none}
#scrub_slider .irs--shiny .irs-bar{background:var(--osa-sea);border-color:var(--osa-sea)}
#scrub_slider .irs--shiny .irs-single{background:var(--osa-sea)}
#scrub_slider .irs--shiny .irs-handle{border-color:var(--osa-sea);background:#C9CED4}
.time-display{font-family:'Courier New',monospace;font-size:1.05rem;font-weight:700;
  color:var(--osa-blue);letter-spacing:.05em;min-width:6rem;text-align:center}

/* ---- Settings summary / tables ---- */
pre.shiny-text-output,#settings_summary{background:#F5F9FC!important;color:#24384B!important;
  border:1px solid var(--border)!important;border-radius:8px;font-size:.76rem;line-height:1.55;margin:0;padding:.75rem .95rem!important}
.table{color:var(--text)!important}
.table th{color:var(--muted)!important;font-size:.73rem;text-transform:uppercase;border-color:var(--border)!important}
.table td{border-color:var(--border)!important;font-size:.83rem}
.file-list-scroll{max-height:180px;overflow-y:auto}
hr.sv-hr{border-color:var(--border);opacity:1;margin:.8rem 0}
.hint{color:var(--muted);font-size:.7rem;line-height:1.4}
"

# -- Subtle wave graphics (OSA brand blues) -----------------------------------
# Two copies of the same wave sit side by side so the slow drift loops seamlessly.
wave_path <- function(y, amp, color, opacity, sw) {
  d <- sprintf("M0 %d C 150 %d, 350 %d, 500 %d S 850 %d, 1000 %d S 1350 %d, 1500 %d S 1850 %d, 2000 %d",
               y, y-amp, y+amp, y, y-amp, y, y+amp, y, y-amp, y)
  tags$path(d=d, fill="none", stroke=color, `stroke-opacity`=opacity, `stroke-width`=sw,
            `stroke-linecap`="round")
}
header_wave <- tags$svg(class="osa-wave", viewBox="0 0 2000 46", preserveAspectRatio="none",
  `aria-hidden`="true",
  wave_path(14, 10, "#99D0E5", .55, 5),
  wave_path(24, 12, "#62ADD7", .45, 4),
  wave_path(34, 9,  "#3796CC", .50, 3.5),
  wave_path(42, 7,  "#ffffff", .18, 2)
)
footer_wave <- tags$svg(viewBox="0 0 2000 28", preserveAspectRatio="none", `aria-hidden`="true",
  wave_path(8,  6, "#99D0E5", .9, 3),
  wave_path(15, 7, "#62ADD7", .8, 2.5),
  wave_path(21, 5, "#2D5DA8", .7, 2)
)

# -- UI ------------------------------------------------------------------------
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$script(src = "audio_player.js"),
    tags$link(rel = "icon", type = "image/jpeg", href = "brand/osa_monogram_blue.jpg"),
    tags$style(HTML(css))
  ),
  title = "SpectraReel | Ocean Science Analytics",
  theme = bs_theme(
    version = 5,
    bg = "#F3F7FA", fg = "#1B2B3A",
    primary = "#2D5DA8", secondary = "#3A74A6", info = "#3796CC",
    success = "#2E9E6B", danger = "#C2410C",
    base_font    = font_google("Inter"),
    heading_font = font_google("Questrial")   # close match to the OSA logotype
  ),

  # -- Header -----------------------------------------------------------------
  div(class = "osa-header",
      div(class = "osa-header-inner",
          tags$img(src = "osa_monogram_white.png", alt = "Ocean Science Analytics"),
          div(class = "osa-divider"),
          div(
            h2(class = "osa-title", "SpectraReel"),
            p(class = "osa-sub", "Preview and export audio files as MP4 spectrogram videos")
          )
      ),
      header_wave
  ),

  sidebarLayout(
    # -- SIDEBAR --------------------------------------------------------------
    sidebarPanel(width=4, class="sidebar-panel",

      fileInput("audio_single","Upload Audio File",
          accept=c(".wav",".mp3",".flac",".ogg",".m4a"),
          buttonLabel="Browse..."),

      tags$hr(class="sv-hr"),
      div(class="sec-head", span(class="ico", icon("wave-square")), "FFT / Spectrogram"),

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
      div(class="sec-head", span(class="ico", icon("volume-high")), "Amplitude"),
      sliderInput("db_range","dB Range",-120,0,c(-80,0),step=5),
      sliderInput("gamma","Gamma (brighten low values)",0.2,3.0,1.0,step=0.1),

      tags$hr(class="sv-hr"),
      div(class="sec-head", span(class="ico", icon("water")), "Smoothing"),

      fluidRow(
        column(6,
          prettySwitch("smooth_on", label = "Apply smoothing",
            value = FALSE, status = "primary", fill = TRUE)
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
        tags$small(class="hint",
          "sigma = Gaussian std dev in spectrogram bins. ",
          "Higher = more blur. Set one to 1 to smooth only the other axis.")
      ),

      tags$hr(class="sv-hr"),
      div(class="sec-head", span(class="ico", icon("palette")), "Visual Style"),

      selectInput("color_scheme","Color Palette",
        choices=c("OSA Ocean *"="osa","Magma"="magma","Viridis"="viridis","Plasma"="plasma",
                  "Inferno"="inferno","Cividis"="cividis","Hot"="hot",
                  "Cool Blue"="cool","Deep Blue->White"="deepblue",
                  "Green Phosphor"="phosphor"),
        selected="osa"),

      fluidRow(
        column(6,
          selectInput("bg_color","Background",
            choices=c("Black"="#000000","OSA Deep Navy"="#0B1F3A","Deep Slate"="#0f172a",
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
            tags$label("Playhead Color", class="control-label", style="display:block;margin-bottom:.5rem"),
            tags$div(class="ph-row",
              tags$input(id="bar_color_swatch", type="color", value="#00ff88"),
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
      div(class="sec-head", span(class="ico", icon("film")), "Output (MP4)"),
      fluidRow(
        column(6, numericInput("vid_width", "Width (px)", 1280,min=640,max=3840,step=64)),
        column(6, numericInput("vid_height","Height (px)", 720,min=360,max=2160,step=64))
      ),
      sliderInput("framerate","Framerate (fps)",5,60,25,step=5),

      tags$hr(class="sv-hr"),
      actionButton("btn_render",HTML("&#9654;&nbsp; Export MP4"), class="btn btn-render")
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
        div(class="sec-head", span(class="ico", icon("eye")), "Live Preview"),

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
        div(class="sec-head", span(class="ico", icon("sliders")), "Settings Summary"),
        verbatimTextOutput("settings_summary")
      ),

      # -- OUTPUT BOX (invisible until render clicked) -------------------------
      div(id="sv-output-box", class="state-idle",

        # Rendering state contents
        div(id="sv-box-rendering",
          style="display:none;flex-direction:column;align-items:center;gap:1rem;width:100%",
          div(class="sv-box-spinner"),
          div(class="sv-box-title", style="color:#2D5DA8", "Rendering MP4 File"),
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
          div(class="sv-box-sub", style="font-size:1rem", "Your spectrogram video is ready to download."),
          uiOutput("dl_button_ui")
        ),

        # Error state contents
        div(id="sv-box-error",
          style="display:none;flex-direction:column;align-items:center;gap:.8rem;width:100%",
          div(style="font-size:2.5rem", HTML("&#9888;")),
          div(class="sv-box-title", style="color:#B42318;font-size:1.25rem", "Render Failed"),
          uiOutput("error_msg_ui")
        )
      )
    )
  ),

  # -- Footer -----------------------------------------------------------------
  div(class = "osa-footer", footer_wave,
      HTML("SpectraReel &middot; <a href='https://oceanscienceanalytics.com' target='_blank'>Ocean Science Analytics</a>"))
)

# -- SERVER --------------------------------------------------------------------
server <- function(input, output, session) {

  rv <- reactiveValues(
    status        = "idle",
    progress      = 0,
    output_files  = NULL,
    error_msg     = NULL,
    cur_file      = "",
    nyquist   = 96000,
    freq_min  = 0,
    freq_max  = 96000,
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
      freq_min = rv$freq_min,
      freq_max = rv$freq_max,
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
    # message("=== spec_data firing ===")
    # message("audio_path: ", rv$audio_path)
    # message("freq_min: ", s$freq_min)
    # message("freq_max: ", s$freq_max)
    # message("fft_size: ", s$fft_size)

    withProgress(message="Computing spectrogram...", value=0.3, {
      wave <- load_audio(rv$audio_path)
      sr   <- wave@samp.rate
      nyq  <- sr / 2
      fmin <- max(0, s$freq_min)
      fmax <- min(nyq, s$freq_max); if(fmax <= fmin) fmax <- nyq

      spec <- tryCatch(
        spectro(wave, f=sr, wl=s$fft_size, wn=s$window_fn, ovlp=s$overlap,
                plot=FALSE, norm=FALSE), #flim=c(fmin/1000, fmax/1000),
        error = function(e) { message("spectro() ERROR: ", e$message); NULL }
      )
      req(!is.null(spec))
      # Subset frequency range manually -- much safer than passing flim
      freq_hz  <- spec$freq * 1000        # spec$freq is in kHz
      keep     <- freq_hz >= fmin & freq_hz <= fmax
      if (sum(keep) < 2) keep <- rep(TRUE, length(freq_hz))  # fallback: show all
      spec$freq <- spec$freq[keep]
      spec$amp  <- spec$amp[keep, , drop=FALSE]
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
    rv$audio_path <- input$audio_single$datapath
    rv$audio_name <- input$audio_single$name
    
    # -- Update freq_max to match file's Nyquist frequency --------------------
    tryCatch({
      info <- av::av_media_info(input$audio_single$datapath)
      sr   <- as.integer(info$audio$sample_rate[1])
      nyq  <- sr / 2L
      rv$nyquist  <- nyq
      rv$freq_max <- nyq
      rv$freq_min <- 0
      updateNumericInput(session, "freq_max", value = nyq, max = nyq)
      updateNumericInput(session, "freq_min", value = 0,   min = 0)
    }, error = function(e) {
      message("Could not read sample rate: ", e$message)
    })
    
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
  
  # -- Changes to frequency scale ---------------------------------------------------------
  observeEvent(input$freq_max, {
    req(!is.null(input$freq_max))
    rv$freq_max <- min(input$freq_max, rv$nyquist)
  }, ignoreInit = TRUE)
  
  observeEvent(input$freq_min, {
    req(!is.null(input$freq_min))
    rv$freq_min <- max(0, input$freq_min)
  }, ignoreInit = TRUE)

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
      tags$span(style="color:#2E9E6B;font-size:.72rem;font-weight:700",
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
      tags$span(style="color:#2D5DA8;font-size:.72rem;font-weight:700",
                sprintf("Hop = %d samp", hop)),
      tags$br(),
      tags$span(style="color:#5F7385;font-size:.68rem",
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
           col="#99D0E5", cex=1.1, family="sans")
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
      tags$small(style="color:#5F7385",
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
    tags$p(style="color:#B42318;font-size:1rem;text-align:center;word-break:break-word",
           rv$error_msg)
  })

  output$dl_single <- downloadHandler(
    filename = function() rv$output_files[[1]]$name,
    content  = function(file) file.copy(rv$output_files[[1]]$path, file)
  )
}

options(shiny.maxRequestSize = 1000 * 1024^2)  # 1 GB upload limit

shinyApp(ui, server)
