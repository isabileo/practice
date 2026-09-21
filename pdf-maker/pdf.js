/**
 * Client-side PDF builder for Patra.
 * Latin-1 text becomes selectable vector PDF; other scripts (Hindi, Punjabi, …)
 * are drawn with the browser font and embedded as page images.
 */
(function (global) {
  "use strict";

  var PAGE_SIZES = {
    a4: { width: 595.28, height: 841.89, label: "A4" },
    letter: { width: 612, height: 792, label: "Letter" },
  };

  var MARGIN = 64;
  var TITLE_SIZE = 22;
  var META_SIZE = 10;
  var BODY_SIZE = 11.5;
  var TITLE_LEADING = 28;
  var BODY_LEADING = 17;
  var FOOTER_SIZE = 9;

  // Helvetica AFM widths, 1/1000 em, WinAnsi 32–255 (gaps filled with 556).
  var HELVETICA = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
    1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
    667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
    333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
    556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584, 350,
    556, 350, 222, 556, 333, 1000, 556, 556, 333, 1000, 667, 333, 1000, 350, 611, 350,
    350, 222, 222, 333, 333, 350, 556, 1000, 333, 1000, 500, 333, 944, 350, 500, 667,
    278, 333, 556, 556, 556, 556, 260, 556, 333, 737, 370, 556, 584, 333, 737, 552,
    400, 549, 333, 333, 333, 576, 537, 278, 333, 333, 365, 556, 834, 834, 834, 611,
    667, 667, 667, 667, 667, 667, 1000, 722, 667, 667, 667, 667, 278, 278, 278, 278,
    722, 722, 778, 778, 778, 778, 778, 584, 778, 722, 722, 722, 722, 667, 667, 611,
    556, 556, 556, 556, 556, 556, 889, 500, 556, 556, 556, 556, 278, 278, 278, 278,
    556, 556, 556, 556, 556, 556, 556, 549, 611, 556, 556, 556, 556, 500, 556, 500,
  ];

  var HELVETICA_BOLD = [
    278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278,
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
    975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778,
    667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556,
    333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611,
    611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584, 350,
    556, 350, 278, 556, 556, 1000, 556, 556, 333, 1000, 667, 333, 1000, 350, 611, 350,
    350, 278, 278, 333, 333, 350, 556, 1000, 333, 1000, 500, 333, 1000, 350, 500, 667,
    278, 333, 556, 556, 556, 556, 280, 556, 333, 737, 370, 556, 584, 333, 737, 552,
    400, 549, 333, 333, 333, 576, 537, 278, 333, 333, 365, 556, 834, 834, 834, 611,
    722, 722, 722, 722, 722, 722, 1000, 722, 667, 667, 667, 667, 278, 278, 278, 278,
    722, 722, 778, 778, 778, 778, 778, 584, 778, 722, 722, 722, 722, 667, 667, 611,
    556, 556, 556, 556, 556, 556, 889, 556, 556, 556, 556, 556, 278, 278, 278, 278,
    611, 611, 611, 611, 611, 611, 611, 549, 611, 611, 611, 611, 611, 556, 611, 556,
  ];

  var INK = { r: 0.106, g: 0.141, b: 0.188 };
  var MUTED = { r: 0.42, g: 0.4, b: 0.37 };
  var ACCENTS = {
    rust: { r: 0.769, g: 0.361, b: 0.149, css: "#c45c26" },
    ink: { r: 0.145, g: 0.247, b: 0.427, css: "#25406d" },
    forest: { r: 0.176, g: 0.365, b: 0.275, css: "#2d5d46" },
  };

  function pageSize(id) {
    return PAGE_SIZES[id] || PAGE_SIZES.a4;
  }

  function contentWidth(size) {
    return size.width - MARGIN * 2;
  }

  function helveticaWidth(text, fontSize, bold) {
    var table = bold ? HELVETICA_BOLD : HELVETICA;
    var w = 0;
    for (var i = 0; i < text.length; i++) {
      var c = text.charCodeAt(i);
      if (c < 32 || c > 255) w += 556;
      else w += table[c - 32] || 556;
    }
    return (w * fontSize) / 1000;
  }

  function isWinAnsiChar(code) {
    if (code >= 32 && code <= 126) return true;
    if (code >= 160 && code <= 255) return true;
    return false;
  }

  function canUseVector(text) {
    for (var i = 0; i < text.length; i++) {
      var c = text.charCodeAt(i);
      if (c === 10 || c === 13 || c === 9) continue;
      if (!isWinAnsiChar(c)) return false;
    }
    return true;
  }

  function wrapText(text, maxWidth, fontSize, bold, measure) {
    var paragraphs = String(text || "").replace(/\r\n/g, "\n").split("\n");
    var lines = [];
    var meas =
      measure ||
      function (s) {
        return helveticaWidth(s, fontSize, bold);
      };

    function breakLong(word) {
      var chunk = "";
      for (var i = 0; i < word.length; i++) {
        var next = chunk + word.charAt(i);
        if (chunk && meas(next) > maxWidth) {
          lines.push(chunk);
          chunk = word.charAt(i);
        } else {
          chunk = next;
        }
      }
      return chunk;
    }

    for (var p = 0; p < paragraphs.length; p++) {
      var para = paragraphs[p];
      if (para === "") {
        lines.push("");
        continue;
      }
      var words = para.split(/ +/);
      var line = "";
      for (var w = 0; w < words.length; w++) {
        var word = words[w];
        var trial = line ? line + " " + word : word;
        if (meas(trial) <= maxWidth) {
          line = trial;
        } else {
          if (line) lines.push(line);
          if (meas(word) > maxWidth) {
            line = breakLong(word);
          } else {
            line = word;
          }
        }
      }
      if (line) lines.push(line);
    }
    return lines;
  }

  function layoutDocument(doc, measureFn) {
    var size = pageSize(doc.pageSize);
    var width = contentWidth(size);
    var accent = ACCENTS[doc.accent] || ACCENTS.rust;
    var yTop = size.height - MARGIN;
    var yBottom = MARGIN + 18;
    var pages = [];
    var items = [];
    var y = yTop;

    function newPage() {
      if (items.length) pages.push({ items: items });
      items = [];
      y = yTop;
    }

    function add(item) {
      items.push(item);
    }

    var title = String(doc.title || "").trim() || "Untitled";
    var titleLines = wrapText(title, width, TITLE_SIZE, true, measureFn && measureFn.bold);
    for (var t = 0; t < titleLines.length; t++) {
      if (y - TITLE_LEADING < yBottom) newPage();
      add({
        type: "text",
        text: titleLines[t],
        x: MARGIN,
        y: y,
        size: TITLE_SIZE,
        bold: true,
        color: INK,
      });
      y -= TITLE_LEADING;
    }

    var metaParts = [];
    if (doc.author && String(doc.author).trim()) metaParts.push(String(doc.author).trim());
    if (doc.date && String(doc.date).trim()) metaParts.push(String(doc.date).trim());
    if (metaParts.length) {
      y -= 4;
      add({
        type: "text",
        text: metaParts.join("  ·  "),
        x: MARGIN,
        y: y,
        size: META_SIZE,
        bold: false,
        color: MUTED,
      });
      y -= 18;
    } else {
      y -= 8;
    }

    add({
      type: "rule",
      x1: MARGIN,
      y1: y + 8,
      x2: MARGIN + width,
      y2: y + 8,
      color: accent,
    });
    y -= 16;

    var body = String(doc.body || "");
    var bodyLines = wrapText(body, width, BODY_SIZE, false, measureFn && measureFn.regular);
    if (bodyLines.length === 0) bodyLines = [""];
    for (var b = 0; b < bodyLines.length; b++) {
      if (y - BODY_LEADING < yBottom) newPage();
      add({
        type: "text",
        text: bodyLines[b],
        x: MARGIN,
        y: y,
        size: BODY_SIZE,
        bold: false,
        color: INK,
      });
      y -= BODY_LEADING;
    }

    if (items.length) pages.push({ items: items });
    if (!pages.length) pages.push({ items: [] });

    for (var i = 0; i < pages.length; i++) {
      pages[i].items.push({
        type: "text",
        text: i + 1 + " / " + pages.length,
        x: size.width / 2,
        y: MARGIN - 18,
        size: FOOTER_SIZE,
        bold: false,
        color: MUTED,
        align: "center",
      });
    }

    return {
      pageWidth: size.width,
      pageHeight: size.height,
      pages: pages,
      accent: accent,
    };
  }

  function pdfEscape(str) {
    var out = "";
    for (var i = 0; i < str.length; i++) {
      var c = str.charCodeAt(i);
      if (c === 92 || c === 40 || c === 41) out += "\\" + str.charAt(i);
      else if (c < 32 || c > 126) out += "\\" + ("00" + c.toString(8)).slice(-3);
      else out += str.charAt(i);
    }
    return out;
  }

  function pdfDate(d) {
    function z(n) {
      return (n < 10 ? "0" : "") + n;
    }
    return (
      "D:" +
      d.getFullYear() +
      z(d.getMonth() + 1) +
      z(d.getDate()) +
      z(d.getHours()) +
      z(d.getMinutes()) +
      z(d.getSeconds())
    );
  }

  function concatBytes(parts) {
    var total = 0;
    for (var i = 0; i < parts.length; i++) total += parts[i].length;
    var out = new Uint8Array(total);
    var o = 0;
    for (var j = 0; j < parts.length; j++) {
      out.set(parts[j], o);
      o += parts[j].length;
    }
    return out;
  }

  function utf8(str) {
    return new TextEncoder().encode(str);
  }

  function padOffset(n) {
    var s = String(n);
    while (s.length < 10) s = "0" + s;
    return s;
  }

  function buildVectorPdf(doc, layout) {
    var enc = new TextEncoder();
    var objects = [];
    objects.push(null);

    function addObj(body) {
      objects.push(typeof body === "string" ? enc.encode(body) : body);
      return objects.length - 1;
    }

    var infoId = addObj(
      "<< /Title (" +
        pdfEscape(doc.title || "Untitled") +
        ") /Author (" +
        pdfEscape(doc.author || "") +
        ") /Creator (Patra PDF Maker) /Producer (Patra) /CreationDate (" +
        pdfDate(new Date()) +
        ") >>"
    );

    var fontReg = addObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>");
    var fontBold = addObj(
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>"
    );

    var pageIds = [];
    var contentIds = [];

    for (var p = 0; p < layout.pages.length; p++) {
      var stream = [];
      var items = layout.pages[p].items;
      for (var i = 0; i < items.length; i++) {
        var it = items[i];
        if (it.type === "rule") {
          stream.push(
            it.color.r.toFixed(3) +
              " " +
              it.color.g.toFixed(3) +
              " " +
              it.color.b.toFixed(3) +
              " RG 1.4 w " +
              it.x1.toFixed(2) +
              " " +
              it.y1.toFixed(2) +
              " m " +
              it.x2.toFixed(2) +
              " " +
              it.y2.toFixed(2) +
              " l S"
          );
        } else if (it.type === "text") {
          var font = it.bold ? "/F2" : "/F1";
          var x = it.x;
          if (it.align === "center") {
            x = it.x - helveticaWidth(it.text, it.size, it.bold) / 2;
          }
          stream.push(
            "BT " +
              it.color.r.toFixed(3) +
              " " +
              it.color.g.toFixed(3) +
              " " +
              it.color.b.toFixed(3) +
              " rg " +
              font +
              " " +
              it.size +
              " Tf 1 0 0 1 " +
              x.toFixed(2) +
              " " +
              it.y.toFixed(2) +
              " Tm (" +
              pdfEscape(it.text) +
              ") Tj ET"
          );
        }
      }
      var content = stream.join("\n");
      var contentBytes = enc.encode(content);
      contentIds.push(
        addObj(
          concatBytes([
            utf8("<< /Length " + contentBytes.length + " >>\nstream\n"),
            contentBytes,
            utf8("\nendstream"),
          ])
        )
      );
      pageIds.push(0);
    }

    var pagesId = addObj("%pages");
    for (var pg = 0; pg < layout.pages.length; pg++) {
      pageIds[pg] = addObj(
        "<< /Type /Page /Parent " +
          pagesId +
          " 0 R /MediaBox [0 0 " +
          layout.pageWidth.toFixed(2) +
          " " +
          layout.pageHeight.toFixed(2) +
          "] /Resources << /Font << /F1 " +
          fontReg +
          " 0 R /F2 " +
          fontBold +
          " 0 R >> >> /Contents " +
          contentIds[pg] +
          " 0 R >>"
      );
    }

    var kids = pageIds
      .map(function (id) {
        return id + " 0 R";
      })
      .join(" ");
    objects[pagesId] = enc.encode(
      "<< /Type /Pages /Kids [" + kids + "] /Count " + pageIds.length + " >>"
    );

    var catalogId = addObj("<< /Type /Catalog /Pages " + pagesId + " 0 R >>");

    var chunks = [enc.encode("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n")];
    var offsets = [0];
    var pos = chunks[0].length;
    for (var o = 1; o < objects.length; o++) {
      offsets[o] = pos;
      var objBytes = concatBytes([utf8(o + " 0 obj\n"), objects[o], utf8("\nendobj\n")]);
      chunks.push(objBytes);
      pos += objBytes.length;
    }
    var xrefPos = pos;
    var xref = "xref\n0 " + objects.length + "\n0000000000 65535 f \n";
    for (var x = 1; x < objects.length; x++) {
      xref += padOffset(offsets[x]) + " 00000 n \n";
    }
    xref +=
      "trailer\n<< /Size " +
      objects.length +
      " /Root " +
      catalogId +
      " 0 R /Info " +
      infoId +
      " 0 R >>\nstartxref\n" +
      xrefPos +
      "\n%%EOF\n";
    chunks.push(enc.encode(xref));
    return concatBytes(chunks);
  }

  function buildRasterPdf(layout, jpegs) {
    var enc = new TextEncoder();
    var objects = [];
    objects.push(null);

    function addObj(body) {
      objects.push(typeof body === "string" ? enc.encode(body) : body);
      return objects.length - 1;
    }

    var infoId = addObj(
      "<< /Title (Patra) /Creator (Patra PDF Maker) /Producer (Patra) /CreationDate (" +
        pdfDate(new Date()) +
        ") >>"
    );

    var imageIds = [];
    var contentIds = [];
    var pageIds = [];

    for (var i = 0; i < jpegs.length; i++) {
      var jpeg = jpegs[i];
      imageIds.push(
        addObj(
          concatBytes([
            utf8(
              "<< /Type /XObject /Subtype /Image /Width " +
                jpeg.widthPx +
                " /Height " +
                jpeg.heightPx +
                " /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length " +
                jpeg.bytes.length +
                " >>\nstream\n"
            ),
            jpeg.bytes,
            utf8("\nendstream"),
          ])
        )
      );
      var draw =
        "q " +
        layout.pageWidth.toFixed(2) +
        " 0 0 " +
        layout.pageHeight.toFixed(2) +
        " 0 0 cm /Im" +
        i +
        " Do Q";
      var drawBytes = enc.encode(draw);
      contentIds.push(
        addObj(
          concatBytes([
            utf8("<< /Length " + drawBytes.length + " >>\nstream\n"),
            drawBytes,
            utf8("\nendstream"),
          ])
        )
      );
      pageIds.push(0);
    }

    var pagesId = addObj("%pages");
    for (var p = 0; p < jpegs.length; p++) {
      pageIds[p] = addObj(
        "<< /Type /Page /Parent " +
          pagesId +
          " 0 R /MediaBox [0 0 " +
          layout.pageWidth.toFixed(2) +
          " " +
          layout.pageHeight.toFixed(2) +
          "] /Resources << /XObject << /Im" +
          p +
          " " +
          imageIds[p] +
          " 0 R >> >> /Contents " +
          contentIds[p] +
          " 0 R >>"
      );
    }

    objects[pagesId] = enc.encode(
      "<< /Type /Pages /Kids [" +
        pageIds
          .map(function (id) {
            return id + " 0 R";
          })
          .join(" ") +
        "] /Count " +
        pageIds.length +
        " >>"
    );

    var catalogId = addObj("<< /Type /Catalog /Pages " + pagesId + " 0 R >>");

    var chunks = [enc.encode("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n")];
    var offsets = [0];
    var pos = chunks[0].length;
    for (var o = 1; o < objects.length; o++) {
      offsets[o] = pos;
      var objBytes = concatBytes([utf8(o + " 0 obj\n"), objects[o], utf8("\nendobj\n")]);
      chunks.push(objBytes);
      pos += objBytes.length;
    }
    var xrefPos = pos;
    var xref = "xref\n0 " + objects.length + "\n0000000000 65535 f \n";
    for (var x = 1; x < objects.length; x++) {
      xref += padOffset(offsets[x]) + " 00000 n \n";
    }
    xref +=
      "trailer\n<< /Size " +
      objects.length +
      " /Root " +
      catalogId +
      " 0 R /Info " +
      infoId +
      " 0 R >>\nstartxref\n" +
      xrefPos +
      "\n%%EOF\n";
    chunks.push(enc.encode(xref));
    return concatBytes(chunks);
  }

  function canvasMeasure(fontSpec) {
    var canvas = document.createElement("canvas");
    var ctx = canvas.getContext("2d");
    ctx.font = fontSpec;
    return function (s) {
      return ctx.measureText(s).width;
    };
  }

  function drawLayoutToCanvas(layout, pageIndex, scale) {
    var canvas = document.createElement("canvas");
    canvas.width = Math.round(layout.pageWidth * scale);
    canvas.height = Math.round(layout.pageHeight * scale);
    var ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.scale(scale, scale);
    ctx.textBaseline = "alphabetic";

    var items = layout.pages[pageIndex].items;
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (it.type === "rule") {
        ctx.strokeStyle = rgbCss(it.color);
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.moveTo(it.x1, layout.pageHeight - it.y1);
        ctx.lineTo(it.x2, layout.pageHeight - it.y2);
        ctx.stroke();
      } else if (it.type === "text") {
        ctx.fillStyle = rgbCss(it.color);
        ctx.font = (it.bold ? "700 " : "400 ") + it.size + "px " + fontStack();
        var x = it.x;
        if (it.align === "center") {
          ctx.textAlign = "center";
        } else {
          ctx.textAlign = "left";
        }
        ctx.fillText(it.text, x, layout.pageHeight - it.y);
      }
    }
    return canvas;
  }

  function fontStack() {
    return '"Helvetica Neue", Helvetica, Arial, "Noto Sans", "Noto Sans Devanagari", "Noto Sans Gurmukhi", sans-serif';
  }

  function rgbCss(c) {
    return (
      "rgb(" +
      Math.round(c.r * 255) +
      "," +
      Math.round(c.g * 255) +
      "," +
      Math.round(c.b * 255) +
      ")"
    );
  }

  function canvasToJpeg(canvas, quality) {
    return new Promise(function (resolve, reject) {
      if (canvas.toBlob) {
        canvas.toBlob(
          function (blob) {
            if (!blob) {
              reject(new Error("Could not create JPEG"));
              return;
            }
            blob.arrayBuffer().then(function (buf) {
              resolve(new Uint8Array(buf));
            }, reject);
          },
          "image/jpeg",
          quality || 0.92
        );
      } else {
        var data = canvas.toDataURL("image/jpeg", quality || 0.92);
        var bin = atob(data.split(",")[1]);
        var out = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
        resolve(out);
      }
    });
  }

  function slugify(title) {
    var s = String(title || "document")
      .trim()
      .replace(/\.pdf$/i, "")
      .toLowerCase()
      .replace(/[^\w\u0900-\u097F\u0A00-\u0A7F]+/g, "-")
      .replace(/^-+|-+$/g, "");
    return (s || "document") + ".pdf";
  }

  function allText(doc) {
    return [doc.title, doc.author, doc.date, doc.body].join("\n");
  }

  function prepareLayout(doc) {
    var useVector = canUseVector(allText(doc));
    var measure = null;
    if (!useVector && typeof document !== "undefined") {
      measure = {
        regular: canvasMeasure("400 " + BODY_SIZE + "px " + fontStack()),
        bold: canvasMeasure("700 " + TITLE_SIZE + "px " + fontStack()),
      };
    }
    return {
      layout: layoutDocument(doc, measure),
      useVector: useVector,
    };
  }

  function buildPdf(doc) {
    var prepared = prepareLayout(doc);
    var layout = prepared.layout;
    var useVector = prepared.useVector;

    if (useVector) {
      return Promise.resolve({
        bytes: buildVectorPdf(doc, layout),
        filename: slugify(doc.filename || doc.title),
        layout: layout,
        mode: "vector",
      });
    }

    var scale = 2;
    var jobs = [];
    for (var i = 0; i < layout.pages.length; i++) {
      jobs.push(
        (function (index) {
          var canvas = drawLayoutToCanvas(layout, index, scale);
          return canvasToJpeg(canvas, 0.92).then(function (bytes) {
            return {
              bytes: bytes,
              widthPx: canvas.width,
              heightPx: canvas.height,
            };
          });
        })(i)
      );
    }
    return Promise.all(jobs).then(function (jpegs) {
      return {
        bytes: buildRasterPdf(layout, jpegs),
        filename: slugify(doc.filename || doc.title),
        layout: layout,
        mode: "image",
      };
    });
  }

  function downloadPdf(bytes, filename) {
    var blob = new Blob([bytes], { type: "application/pdf" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename || "document.pdf";
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () {
      URL.revokeObjectURL(url);
    }, 1500);
  }

  global.PatraPdf = {
    PAGE_SIZES: PAGE_SIZES,
    ACCENTS: ACCENTS,
    MARGIN: MARGIN,
    layoutDocument: layoutDocument,
    prepareLayout: prepareLayout,
    drawLayoutToCanvas: drawLayoutToCanvas,
    buildPdf: buildPdf,
    downloadPdf: downloadPdf,
    slugify: slugify,
    canUseVector: canUseVector,
    helveticaWidth: helveticaWidth,
    wrapText: wrapText,
    contentWidth: contentWidth,
    pageSize: pageSize,
    rgbCss: rgbCss,
    fontStack: fontStack,
  };
})(typeof window !== "undefined" ? window : this);
