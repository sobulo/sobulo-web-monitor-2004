# Transcription method

## Boundary and page mapping

1. Inspect the visible appendix heading rather than relying solely on physical page indices.
2. Locate the visible References heading to establish the appendix endpoint.
3. Record both logical thesis pages and physical PDF pages.

## Working evidence

Appendix physical pages 45-69 are rendered at 300 DPI as PNG files under `work/appendix-a/pages/`. Poppler also produces:

- `work/appendix-a/appendix-a.txt`: normal text extraction.
- `work/appendix-a/appendix-a-layout.txt`: layout-preserving text extraction.

These extractions are comparison aids only. They are not described or treated as original source code.

## Transcription rules

- Read each rendered page visually and compare it with both text extractions.
- Remove the printed line-number column.
- Preserve one repository line for each numbered printed line, including numbered blank lines, so the manifest can map ranges directly.
- Join visual wraps that belong to a single numbered printed line.
- Preserve routine names, identifiers, comments, spelling, capitalization, structure, and apparent defects.
- Do not refactor, modernize, compile-fix, or infer content beyond the reviewed pages.
- Record unresolved uncertainty in `original/appendix-a/transcription-notes.md` instead of guessing.

## Permitted normalizations in this batch

- Removed printed line numbers and page headers/footers.
- Removed typesetting spaces inserted inside Perl tokens, including `::`, `->`, `=>`, `<=>`, dereferences, escapes, operators, sigils, punctuation, and regular expressions.
- Rejoined code and comments wrapped by the printed page layout when they shared one printed line number.
- Represented the visibly typographic single quotes around `GET` on printed line 161 as ASCII Perl single quotes.

No semantic correction was made.
