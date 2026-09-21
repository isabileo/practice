(function () {
  "use strict";

  var form = document.getElementById("form");
  var titleEl = document.getElementById("title");
  var authorEl = document.getElementById("author");
  var dateEl = document.getElementById("date");
  var bodyEl = document.getElementById("body");
  var pageSizeEl = document.getElementById("pageSize");
  var filenameEl = document.getElementById("filename");
  var previewEl = document.getElementById("preview");
  var pageMetaEl = document.getElementById("pageMeta");
  var statusEl = document.getElementById("status");
  var downloadBtn = document.getElementById("download");
  var sampleBtn = document.getElementById("sample");

  function todayLabel() {
    try {
      return new Intl.DateTimeFormat("en-GB", {
        day: "numeric",
        month: "short",
        year: "numeric",
      }).format(new Date());
    } catch (e) {
      return new Date().toISOString().slice(0, 10);
    }
  }

  if (!dateEl.value) dateEl.value = todayLabel();

  function selectedAccent() {
    var el = form.querySelector('input[name="accent"]:checked');
    return (el && el.value) || "rust";
  }

  function readDoc() {
    return {
      title: titleEl.value,
      author: authorEl.value,
      date: dateEl.value,
      body: bodyEl.value,
      pageSize: pageSizeEl.value,
      accent: selectedAccent(),
      filename: filenameEl.value,
    };
  }

  function setStatus(text, kind) {
    statusEl.textContent = text || "";
    statusEl.className = "status" + (kind ? " " + kind : "");
  }

  function renderPreview() {
    var doc = readDoc();
    var prepared = window.PatraPdf.prepareLayout(doc);
    var layout = prepared.layout;
    var size = window.PatraPdf.pageSize(doc.pageSize);
    pageMetaEl.textContent =
      layout.pages.length +
      (layout.pages.length === 1 ? " page" : " pages") +
      " · " +
      size.label;

    previewEl.innerHTML = "";
    for (var i = 0; i < layout.pages.length; i++) {
      var canvas = window.PatraPdf.drawLayoutToCanvas(layout, i, 1.35);
      canvas.className = "sheet";
      canvas.setAttribute("aria-label", "Page " + (i + 1));
      previewEl.appendChild(canvas);
    }
  }

  var previewTimer = null;
  function schedulePreview() {
    clearTimeout(previewTimer);
    previewTimer = setTimeout(renderPreview, 60);
  }

  ["input", "change"].forEach(function (evt) {
    form.addEventListener(evt, schedulePreview);
  });

  sampleBtn.addEventListener("click", function () {
    titleEl.value = "A short note";
    authorEl.value = "SARBJIT SINGH";
    dateEl.value = todayLabel();
    bodyEl.value =
      "This is a one-page PDF made in the browser.\n\n" +
      "Type a title and some body text, then press Download PDF. Optional author and date print under the title.\n\n" +
      "यह एक साधारण PDF है। Punjabi and Hindi text also work.\n\n" +
      "ਇੱਕ ਪੰਨਾ ਲਿਖੋ, PDF ਲੈ ਜਾਓ।";
    filenameEl.value = "short-note.pdf";
    setStatus("Sample filled — you can edit it, then download.");
    renderPreview();
    titleEl.focus();
  });

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    var doc = readDoc();
    if (!String(doc.title).trim() || !String(doc.body).trim()) {
      setStatus("Add a title and some body text first.", "err");
      return;
    }
    downloadBtn.disabled = true;
    setStatus("Building PDF…");
    window.PatraPdf
      .buildPdf(doc)
      .then(function (result) {
        window.PatraPdf.downloadPdf(result.bytes, result.filename);
        setStatus("Saved " + result.filename, "ok");
      })
      .catch(function (err) {
        setStatus((err && err.message) || "Could not build the PDF.", "err");
      })
      .then(function () {
        downloadBtn.disabled = false;
      });
  });

  document.addEventListener("keydown", function (e) {
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
      form.requestSubmit();
    }
  });

  renderPreview();
})();
