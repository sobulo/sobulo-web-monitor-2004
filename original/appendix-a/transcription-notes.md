# Transcription notes

## Batch 1

- **Logical thesis pages:** 38-42
- **Physical PDF pages:** 45-49
- **Printed lines:** 1-243
- **Repository lines:** 1-243
- **Status:** transcribed; awaiting independent human verification

## Documented normalizations

- Printed line numbers, appendix heading, and page numbers were omitted.
- Numbered blank lines were retained so repository and printed line numbers remain aligned in this batch.
- Visual line wraps within a single numbered line were rejoined.
- Typesetting spaces inside Perl tokens were removed, including spaces in `::`, `->`, `=>`, `<=>`, escape sequences, dereferences, operators, punctuation, and regular expressions.
- The typographic quote glyphs around `GET` on printed line 161 were represented as ASCII single quotes.

## Unresolved ambiguities

None recorded for printed lines 1-243 after comparison of the 300 DPI page renders with normal and layout-preserving extractions.

## Visually sensitive tokens checked

The following areas were checked directly against the page renders because extraction fragmented them heavily:

- printed lines 41-42: both regular-expression strings, including backslashes, escaped dollar signs, and `\/??`;
- printed lines 56 and 139: `s#/#\\\\#g`;
- printed line 75: spaces introduced by extraction were removed; the token was resolved visually as `!/^\.\.?$/`;
- printed line 77: the comparison operator is `<=>`;
- printed lines 116-121: backslash references such as `\@links` and `\%sites1`;
- printed line 161: `HTTP::Request->new('GET' => $page_url)`;
- printed lines 181-188: array/hash dereferencing and `->canonical` calls.

Apparent defects and spelling, including `b read` (line 69), `btw` (line 84), `acnchor` and repeated `and` (line 187), and the condition on lines 173-175, were preserved rather than corrected.
