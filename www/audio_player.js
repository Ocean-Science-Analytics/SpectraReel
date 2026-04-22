var _audio = null;
var _duration = 0;
var _canvas = null;
var _ctx = null;
var _plotMargins = null;   // {left, right, top, bottom} as fractions of canvas size
var _barColor = "#00ff88";
var _barWidth = 2;
var _colorbar = false;
var _shade = false;
var _animFrame = null;

// Draw the playhead line on the canvas
function drawPlayhead(t) {
  if (!_ctx || !_canvas || _duration <= 0) return;
  var w = _canvas.width, h = _canvas.height;
  _ctx.clearRect(0, 0, w, h);

  var ml = Math.round(w * 0.062);
  var mr = _colorbar ? Math.round(w * 0.08) : Math.round(w * 0.025);
  var mt = Math.round(h * 0.08);
  var mb = Math.round(h * 0.115);
  var plotW = w - ml - mr;
  var plotH = h - mt - mb;

  var frac = Math.min(1, Math.max(0, t / _duration));
  var x = ml + frac * plotW;

  // Shade played region
  if (_shade && frac > 0) {
    _ctx.fillStyle = "rgba(255,255,255,0.24)";
    _ctx.fillRect(ml, mt, x - ml, plotH);
  }

  // Glow
  _ctx.strokeStyle = hexToRgba(_barColor, 0.22);
  _ctx.lineWidth = _barWidth * 4;
  _ctx.beginPath(); _ctx.moveTo(x, mt); _ctx.lineTo(x, mt + plotH); _ctx.stroke();

  // Line
  _ctx.strokeStyle = _barColor;
  _ctx.lineWidth = _barWidth;
  _ctx.beginPath(); _ctx.moveTo(x, mt); _ctx.lineTo(x, mt + plotH); _ctx.stroke();
}

function hexToRgba(hex, alpha) {
  var r = parseInt(hex.slice(1,3),16),
      g = parseInt(hex.slice(3,5),16),
      b = parseInt(hex.slice(5,7),16);
  return "rgba("+r+","+g+","+b+","+alpha+")";
}

function animLoop() {
  if (_audio && !_audio.paused && !_audio.ended) {
    drawPlayhead(_audio.currentTime);
    _animFrame = requestAnimationFrame(animLoop);
  }
}

function startAnim() {
  if (_animFrame) cancelAnimationFrame(_animFrame);
  _animFrame = requestAnimationFrame(animLoop);
}

function stopAnim() {
  if (_animFrame) { cancelAnimationFrame(_animFrame); _animFrame = null; }
}

function initCanvas() {
  _canvas = document.getElementById("playhead-canvas");
  if (!_canvas) return;
  _ctx = _canvas.getContext("2d");
  // Match canvas resolution to its CSS size
  var rect = _canvas.getBoundingClientRect();
  _canvas.width  = rect.width  || _canvas.offsetWidth;
  _canvas.height = rect.height || _canvas.offsetHeight;
}

Shiny.addCustomMessageHandler("loadAudio", function(src) {
  stopAnim();
  if (_audio) { _audio.pause(); _audio.src = ""; _audio = null; }
  _audio = new Audio();

  // Throttled sync back to Shiny -- only once per second while playing
  var _lastShinySync = -1;
  _audio.addEventListener("timeupdate", function() {
    var t = _audio.currentTime;
    var now = Math.floor(t);
    if (now !== _lastShinySync) {
      _lastShinySync = now;
      Shiny.setInputValue("js_audio_time", t, {priority:"event"});
    }
  });
  _audio.addEventListener("ended", function() {
    stopAnim();
    drawPlayhead(0);
    Shiny.setInputValue("js_audio_ended", true, {priority:"event"});
  });
  _audio.addEventListener("loadedmetadata", function() {
    _duration = _audio.duration;
    Shiny.setInputValue("js_audio_duration", _audio.duration, {priority:"event"});
    initCanvas();
  });
  _audio.addEventListener("error", function(e) {
    console.error("Audio error:", e, _audio.error);
  });
  _audio.src = src;
  _audio.load();
});

Shiny.addCustomMessageHandler("audioPlay", function(_) {
  if (_audio) {
    _audio.play().catch(function(e){ console.warn("play() blocked:", e); });
    initCanvas();
    startAnim();
  }
});
Shiny.addCustomMessageHandler("audioPause", function(_) {
  if (_audio) _audio.pause();
  stopAnim();
});
Shiny.addCustomMessageHandler("audioSeek", function(t) {
  if (_audio) {
    _audio.currentTime = t;
    drawPlayhead(t);
  }
});
Shiny.addCustomMessageHandler("setPlayheadStyle", function(cfg) {
  if (cfg.color) _barColor = cfg.color;
  if (cfg.width) _barWidth = cfg.width;
  if (typeof cfg.colorbar !== "undefined") _colorbar = cfg.colorbar;
  if (typeof cfg.shade   !== "undefined") _shade   = cfg.shade;
});
