# Patra — Make a PDF

A small local web app: type a **title** and **body**, then download a PDF. Optional author, date, page size, and accent color. Generation runs in the browser — nothing is uploaded.

Hindi / Punjabi (and other non-Latin scripts) are supported.

## Open / run

**Fastest:** open `pdf-maker/index.html` in a desktop browser (Chrome, Edge, Firefox, Safari).

If the browser blocks file downloads from `file://`, serve the folder:

```bash
cd pdf-maker
python3 -m http.server 8080
```

Then visit http://localhost:8080

No install, no build, no account.

## Use

1. Enter a title and the page text
2. Optionally fill author, date, file name
3. Click **Download PDF** (or Ctrl/Cmd+Enter)
4. **Fill sample** loads a demo note you can edit

The right-hand preview updates as you type.
