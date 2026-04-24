// ── Audio player: accepts either a URL or a base64 data URI ─────────────────
var _audio = null;

Shiny.addCustomMessageHandler("loadAudio", function(src) {
  if (_audio) { _audio.pause(); _audio.src = ""; _audio = null; }

  _audio = new Audio();

  _audio.addEventListener("timeupdate", function() {
    Shiny.setInputValue("js_audio_time", _audio.currentTime, {priority:"event"});
  });
  _audio.addEventListener("ended", function() {
    Shiny.setInputValue("js_audio_ended", true, {priority:"event"});
  });
  _audio.addEventListener("loadedmetadata", function() {
    Shiny.setInputValue("js_audio_duration", _audio.duration, {priority:"event"});
  });
  _audio.addEventListener("error", function(e) {
    console.error("Audio error:", e, _audio.error);
  });

  // Set src AFTER attaching listeners so we don't miss early events
  _audio.src = src;
  _audio.load();
});

Shiny.addCustomMessageHandler("audioPlay",  function(_) {
  if (_audio) _audio.play().catch(function(e){ console.warn("play() blocked:", e); });
});
Shiny.addCustomMessageHandler("audioPause", function(_) {
  if (_audio) _audio.pause();
});
Shiny.addCustomMessageHandler("audioSeek",  function(t) {
  if (_audio) { _audio.currentTime = t; }
});
