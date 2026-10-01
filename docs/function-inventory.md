# Preliminary function inventory

Scope: only logical thesis pages 38-42 (printed lines 1-243). `filterOutLinks` is incomplete at the batch boundary.

## Functions defined in the transcribed range

| Function | Printed lines | Visible purpose |
|---|---:|---|
| `newSave` | 36-65 | Takes website snapshots and writes per-site snapshot files in a time-stamped directory. |
| `getDirList` | 71-79 | Reads and reverse-sorts directory contents. |
| `diffSavedSites` | 85-123 | Computes differences between saved link sets and marks broken links. |
| `readSavedSites` | 129-146 | Reads saved site and URL files into a site hash reference. |
| `getLinks` | 152-191 | Retrieves a page and extracts canonicalized link information. |
| `filterLinks` | 198-215 | Keeps links matching a regular-expression filter. |
| `filterOutLinks` | 223 onward | Begins filtering links against selected fields; the function continues after page 42 and is not complete in this batch. |

## Called project routines visible in the range

`getLinksForAllSites`, `browserPrint`, `writeSiteFile`, `writeUrlFile`, `debugPrint`, `diffLinks`, `readSiteFile`, and `readUrlFile` are called but not defined in the transcribed pages.

## Visible module and runtime dependencies

- `strict`
- `HTTP::Request`
- `HTTP::Response`
- `LWP::UserAgent`
- `HTML::TokeParser`
- `HTTP::Headers`
- `URI` is referenced through `URI->new` on printed lines 183-184, although no corresponding `use URI` statement is visible in this batch.
- `/usr/sbin/sendmail -t` is configured on printed line 18.

This inventory does not infer definitions or dependencies from later appendix pages.
