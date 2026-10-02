# Restoration log

## Stage 3, chunk 1: controlled researcher pipeline

Date: 2026-10-02

This log records the first runnable reconstruction exercise around the frozen Appendix A package. The fixture under `fixtures/researcher-site/` and the caller at `scripts/researcher-monitor.pl` are 2026 reconstruction/test infrastructure. They are not recovered 2004 source.

The historical file `original/appendix-a/MonitorUtils.thesis.pl` was loaded directly and was not edited. No external website, email transport, scheduler, GUI, course-domain code, or Python implementation was used. Python was used only to serve the static fixture on `127.0.0.1`.

## Sync

Command:

```console
git pull --ff-only origin main
```

Observed result:

```text
From https://github.com/sobulo/sobulo-web-monitor-2004
 * branch            main       -> FETCH_HEAD
   7967cc1..1af2c6a  main       -> origin/main
Updating 7967cc1..1af2c6a
Fast-forward
 README.md                  | 4 +++-
 docs/function-inventory.md | 4 ++--
 2 files changed, 5 insertions(+), 3 deletions(-)
```

## Controlled fixture and local server

The initial `index.html` linked to:

- `publications/database-monitoring.pdf`
- `publications/legacy-system.ps`
- a non-publication `about.html` page

The server was started with:

```console
python3 -m http.server 8765 --bind 127.0.0.1 --directory fixtures/researcher-site
```

Observed startup:

```text
Serving HTTP on 127.0.0.1 port 8765 (http://127.0.0.1:8765/) ...
```

The server's complete access log for the exercise was:

```text
127.0.0.1 - - [02/Oct/2026 10:47:27] "GET /index.html HTTP/1.1" 200 -
127.0.0.1 - - [02/Oct/2026 10:47:33] "GET /index.html HTTP/1.1" 200 -
127.0.0.1 - - [02/Oct/2026 10:47:57] "GET /index.html HTTP/1.1" 200 -
```

Only the loopback fixture index was requested. No external host and no linked publication file was requested.

## 1. Direct `getLinks` proof

This invoked the frozen package directly, before any historical behavior was changed:

```console
/usr/bin/perl -e 'require "./original/appendix-a/MonitorUtils.thesis.pl"; my @links = MonitorUtils::getLinks("http://127.0.0.1:8765/index.html"); for my $link (@links) { print join(" | ", map { "$_" } @{$link}), "\n"; }'
```

Observed result:

```text
http://127.0.0.1:8765/publications/database-monitoring.pdf | Database Monitoring Paper | http://127.0.0.1:8765/index.html | Controlled Researcher Publications
http://127.0.0.1:8765/publications/legacy-system.ps | Legacy Monitoring Paper | http://127.0.0.1:8765/index.html | Controlled Researcher Publications
http://127.0.0.1:8765/about.html | About this fixture | http://127.0.0.1:8765/index.html | Controlled Researcher Publications
```

This proves that the preserved `getLinks` fetched the local page, resolved the relative URLs, retained anchor text, and captured the page title. Returning the HTML link here is expected: `getLinks` extracts anchors, while the publication-extension filter is applied later by `newSave`.

## 2. First historical snapshot

The reconstructed caller creates a minimal professor/site hash, converts it with `MonitorUtils::convertProfessorHashToSiteHash`, and invokes `MonitorUtils::newSave`. Depth is zero so only the controlled index page is fetched.

Command:

```console
/usr/bin/perl scripts/researcher-monitor.pl snapshot
```

Observed result:

```text
Snapshot created: /Users/olusegunsobulo/Documents/Codex/2026-08-05/github-plugin-github-openai-curated-remote/sobulo-web-monitor-2004/scripts/../runtime/researcher-monitor/1790934453/
```

The main snapshot file contained:

```text
http://127.0.0.1:8765/index.html|0|Controlled Researcher Publications|
http://127.0.0.1:8765/publications/database-monitoring.pdf|Database Monitoring Paper|http://127.0.0.1:8765/index.html|Controlled Researcher Publications
http://127.0.0.1:8765/publications/legacy-system.ps|Legacy Monitoring Paper|http://127.0.0.1:8765/index.html|Controlled Researcher Publications
```

The non-publication `about.html` link was not stored in the publication snapshot.

## 3. Controlled fixture change

The served `index.html` was changed to match `states/index.updated.html`:

- the link to `publications/legacy-system.ps` was removed;
- the link to `publications/reconstruction-notes.ppt` was added; and
- the PDF link remained unchanged.

Both page states are committed under `fixtures/researcher-site/states/` so the evidence is reproducible.

## 4. Second historical snapshot

Command:

```console
date +%s && /usr/bin/perl scripts/researcher-monitor.pl snapshot
```

Observed result:

```text
1790934477
Snapshot created: /Users/olusegunsobulo/Documents/Codex/2026-08-05/github-plugin-github-openai-curated-remote/sobulo-web-monitor-2004/scripts/../runtime/researcher-monitor/1790934477/
```

The epoch directory differs from the first snapshot (`1790934453`). The second main snapshot file contained:

```text
http://127.0.0.1:8765/index.html|0|Controlled Researcher Publications|
http://127.0.0.1:8765/publications/database-monitoring.pdf|Database Monitoring Paper|http://127.0.0.1:8765/index.html|Controlled Researcher Publications
http://127.0.0.1:8765/publications/reconstruction-notes.ppt|Reconstruction Notes|http://127.0.0.1:8765/index.html|Controlled Researcher Publications
```

## 5. Load, diff, and plain-text report

The `diff` operation creates the same minimum site hash for each snapshot, calls the preserved `readSavedSites` twice, passes the results to `diffSavedSites`, and renders with `getSnapshotEmailText`.

Command:

```console
/usr/bin/perl scripts/researcher-monitor.pl diff runtime/researcher-monitor/1790934453 runtime/researcher-monitor/1790934477
```

Observed result:

In this block, `␠` denotes one trailing ASCII space present in the captured output.

```text
Warning: illegal url format for ␠
Warning: illegal url format for ␠
Researcher: Controlled Fixture Researcher SiteName: Controlled Researcher Publications SiteUrl: http://127.0.0.1:8765/index.html [Crawl Depth: 0] [Stay Within: ]
     PaperName: Legacy Monitoring Paper PaperUrl: http://127.0.0.1:8765/publications/legacy-system.ps  removed from  PageName: Controlled Researcher Publications PageUrl: http://127.0.0.1:8765/index.html␠
     PaperName: Reconstruction Notes PaperUrl: http://127.0.0.1:8765/publications/reconstruction-notes.ppt  added to  PageName: Controlled Researcher Publications PageUrl: http://127.0.0.1:8765/index.html␠

```

The two warnings are non-fatal historical behavior. `getLinksForSite` seeds the successful-root record as `[$url, "", "", ""]` (Appendix A lines 313 and 368-369). `writeUrlFile` writes that record, and `readUrlFile` later passes its empty source-page URL to `checkUrlFormat` (lines 771-772), producing one warning per snapshot. The complete crawl, snapshot, reload, diff, and report flow still succeeds, so no correction was proposed or applied in this chunk.

## Result

The frozen Appendix A package completed the controlled researcher-domain flow without modification:

```text
local configuration/site hash
  -> local crawl and publication filtering
  -> timestamped snapshot
  -> changed local fixture
  -> second timestamped snapshot
  -> snapshot reload
  -> added/removed publication diff
  -> plain-text report
```

Runtime output was written only under ignored `runtime/` and is not part of the commit. Notification, course monitoring, scheduling, GUI work, and a Python port remain out of scope.

## Final verification

Caller syntax command and result:

```console
/usr/bin/perl -c scripts/researcher-monitor.pl
scripts/researcher-monitor.pl syntax OK
```

Frozen-evidence comparison command:

```console
git diff --exit-code -- original/appendix-a/MonitorUtils.thesis.pl original/appendix-a/transcription-manifest.csv original/appendix-a/transcription-notes.md
```

Observed result: no output and exit status 0. The historical transcription and its audit records remained unchanged.

Ignore verification command and result:

```console
git check-ignore -v runtime runtime/researcher-monitor/1790934453 runtime/researcher-monitor/1790934477
.gitignore:2:/runtime/ runtime
.gitignore:2:/runtime/ runtime/researcher-monitor/1790934453
.gitignore:2:/runtime/ runtime/researcher-monitor/1790934477
```

Loopback guard command:

```console
/usr/bin/perl scripts/researcher-monitor.pl snapshot http://example.com
```

Observed result and exit status:

```text
Only a loopback fixture URL is allowed: http://example.com
exit status 255
```

The reconstructed caller rejected the external URL before invoking the historical crawler.


## Stage 4 closure: behavior reconstruction

The controlled execution above is also the completion evidence for Stage 4, scoped to the surviving Appendix A researcher-monitoring backend.

The run establishes the observed input/output behavior of the preserved path: a researcher-style site configuration identifies the starting page; the historical crawler retrieves that page; publication-style links are filtered into a timestamped snapshot; a later snapshot can be reloaded; the historical diff reports a link that is no longer present and a newly present link; and the preserved reporting routine renders those differences.

The fixture change did not modify or convert publication files. It changed only which publication links were present on the controlled HTML page, allowing the monitor to report one previously observed link as missing and another as newly added.

Together with the static audit, this is sufficient to close the planned behavior-reconstruction stage for the code that actually survives in Appendix A. Recursive crawler behavior, depth/allow semantics, file formats, configuration structures, and the boundaries of missing surrounding application components are documented in `docs/static-audit.md`; the controlled run adds direct execution evidence for the central crawl -> snapshot -> diff -> report path.

### Completion boundary

Stages 3 and 4 are considered complete for the surviving researcher-domain backend.

This repository does not claim that the entire 2004 application has been restored. The GUI/controller, scheduler, notification-policy orchestration, configuration-file orchestration, and thesis-described course-domain implementation were not printed in Appendix A and remain documented historical boundaries rather than implementation tasks for this repository.

The reproducible execution steps are maintained in `RUNNING.md`.
