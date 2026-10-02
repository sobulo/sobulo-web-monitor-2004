# Static reconstruction audit

## Scope and evidence

This Stage 2 audit compares Chapter 4 of the thesis, especially sections 4.2 through 4.4.9 (logical thesis pages 23-32), with the frozen Appendix A transcription in `original/appendix-a/MonitorUtils.thesis.pl`. Chapter 4 describes the application architecture; Appendix A preserves a Perl package named `MonitorUtils` containing 42 functions and a final true return value, not an executable application entry point. Appendix A printed line numbers and repository line numbers are identical, so line references below apply to both.

This is a static audit. The Perl was not executed, external dependencies were not installed, no network requests or email were sent, and no historical defect was corrected. A function is treated as implemented only when its behavior is visible in Appendix A. Thesis-described behavior without corresponding Appendix A code is labeled as surrounding code absent, not as a transcription omission.

## A. Historical system requirements from Chapter 4

### System modules and features

| Thesis module or feature | Chapter 4 requirement |
|---|---|
| GUI | Provide the system front end. Administrators can force snapshots and add researcher or course sites. Users can select monitored sites, subscribe to email reports, view cached copies, and compare two snapshots. |
| Configuration | Seed an initial monitored-site set through a batch process, accept later GUI changes, and read/write three XML configurations: researchers, courses, and user subscriptions/preferences. |
| Snapshots | Combine crawling, domain-specific extraction, and caching. Run regularly through the scheduler or manually through the GUI, and allow later viewing and comparison. |
| Crawler | Crawl one or more sites for a researcher or course. Honor per-site `depth` and `allow` controls. Chapter 4 says depth zero means no crawl, positive depth limits traversal, missing depth means unlimited traversal, and `allow` restricts followed links to matching strings/domains. |
| Data extraction | Apply domain-specific extraction. For researchers, retain downloadable publications and textual descriptions for PostScript, PDF, or PowerPoint links, with manual noise filters. For courses, retain page content rather than extracting publications. |
| Caching | Cache extracted researcher data under an archive policy with timestamped history. Cache course pages under an overwrite policy, replacing the one stored copy only when content changes. |
| Finding changes / diff | Compare current and cached data using domain-specific rules. Researcher changes are publication URLs added or removed, with duplicate-link count changes suppressed. Course changes are based on differing characters crossing a threshold described as currently one and glossed by the thesis as any change. |
| Notification | Support on-demand web reports, eager email when a subscribed site changes, and periodic email whether or not a change occurred. |
| Scheduler | Run monitored sites at administrator-selected intervals (daily for both documented domains), sequence crawl, extraction, cache, and diff, then apply each user's notification preferences. |

Figure 4.1 groups crawler, data extraction, and cache within the snapshot subsystem, and diff and email within change detection. It also shows GUI and scheduler as callers/orchestrators and configuration and cache as data stores.

### Researcher domain

Chapter 4 describes this domain as follows:

- Monitor one or more websites for each database researcher.
- Find downloadable publications, specifically PostScript, PDF, and PowerPoint files; Appendix A's fixed result expression also includes compressed PostScript (`.ps.gz`).
- Retain a publication URL plus descriptive text and the page on which it was found.
- Use `depth` and `allow` to control traversal from each configured homepage.
- Extract the publication records before caching them.
- Store complete, timestamped snapshots under an archive policy so any two historical snapshots can be compared.
- Report publication URLs added or removed.
- Suppress duplicate-link changes where applicable and filter likely course/class documents using manual rules.
- Present changes through the web interface and email reports.

Appendix A supports most backend steps in this flow, but duplicate suppression and the course/class noise rule are report options controlled by a caller. `diffSavedSites` itself does not deduplicate its input before comparing it.

### Course domain

Chapter 4 describes a different pipeline:

- Monitor one or more course websites.
- Retain page content rather than extracting publication links.
- Maintain one cached copy under an overwrite policy.
- Compare a newly fetched page with the cached page and overwrite the cache only when a qualifying difference is found.
- Report which page changed.
- Treat a character-difference threshold, described as currently one and as detecting any change, as the domain's change rule.

Appendix A contains generic raw-cache helpers (`translateUrlToFileName`, `readCachedPage`, and `writeCachedPage`) but no visible course-page fetch/cache orchestration or character-difference algorithm. The completed course-domain behavior therefore cannot be reconstructed from Appendix A alone.

## B. Appendix A implementation map

### System-level map of the 42 functions

| Appendix A functions | Thesis module(s) supported | System-level role and limit |
|---|---|---|
| `newSave`, `getDirList`, `readSavedSites` | Snapshots, archive caching | `newSave` crawls all configured sites and writes a new epoch-named snapshot directory. `readSavedSites` rebuilds a site hash from one snapshot. `getDirList` can enumerate snapshot directories, but selection of snapshots is left to a caller. |
| `readSiteFile`, `writeSiteFile`, `readUrlFile`, `writeUrlFile` | Snapshots, caching | Persist and reload the extracted site/link records and the separate okay/broken URL lists used by the researcher pipeline. |
| `getLinks`, `getLinksForSite`, `getLinksForAllSites` | Crawler, researcher data extraction | Fetch pages, parse anchors, canonicalize links, recurse according to depth/crawl filters, and collect result, okay, and broken records. They do not return raw page content for the course domain. |
| `filterLinks`, `filterOutLinks`, `removeDuplicateLinks`, `checkUrlFormat` | Crawler, data extraction, reporting | Apply regular-expression inclusion/exclusion, optionally suppress duplicate URLs in reports, and validate URL shape. `checkUrlFormat` warns and returns false; it does not modify the URL. |
| `diffSavedSites`, `sortLinks`, `diffLinks` | Finding changes | Compare researcher snapshot records, append `added to` or `removed from`, compare successful-crawl lists, and suppress publication differences attributable to affected page URLs. No course content comparator is present. |
| `translateUrlToFileName`, `readCachedPage`, `writeCachedPage` | Caching | Provide raw-page filename translation and scalar page-content reads/writes. No Appendix A function connects these helpers to a course crawl, overwrite decision, or diff threshold. |
| `getKeysSortedByName`, `printSnapshotHtml` | GUI/reporting | Sort site records and print an HTML snapshot/difference body. This is report rendering, not the GUI/controller shown in Chapter 4. |
| `getSnapshotEmailHtml`, `getSnapshotEmailText`, `sendMail` | Notification | Build HTML/plain-text researcher reports and pass a multipart message to the configured `sendmail` program. Recipient selection, timing, eager/periodic decisions, and subjects are caller responsibilities. |
| `printLinkInfo` | Diagnostics | Emit link fields through `debugPrint`; it is not part of a documented application workflow in Appendix A. |
| `parseXml`, `parseXmlHelper`, `generateXml`, `generateXmlHelper` | Configuration | Convert a limited element-only XML text representation to/from nested Perl hashes and arrays. No configuration-file open/save operation or DTD handling is present. |
| `convertXmlHashToUserHash`, `convertUserHashToXmlHash` | Configuration, notification | Convert between XML-shaped data and a user hash containing name, notification value, and subscribed URLs. Nothing invokes these conversions or enforces notification behavior. |
| `convertXmlHashToProfessorHash`, `convertProfessorHashToXmlHash` | Configuration | Convert between XML-shaped professor/site data and the researcher configuration hash used by the backend. |
| `convertProfessorHashToSiteHash`, `filterProfessorHash`, `filterHash`, `findInArray` | Configuration, site/user selection | Flatten professor sites for crawling and select configured professors/sites or hash keys. They provide selection operations, not the GUI or configuration controller. |
| `setDebug`, `debugPrint`, `setBrowser`, `browserPrint` | Cross-cutting output support | Control diagnostic output and browser-oriented progress output. They do not implement a controller or web application. |

### Researcher monitoring pipeline visible in Appendix A

The backend pieces form the following static path:

```text
XML-shaped researcher data
  -> parseXml / convertXmlHashToProfessorHash
  -> optional filterProfessorHash
  -> convertProfessorHashToSiteHash
  -> newSave
       -> getLinksForAllSites
            -> getLinksForSite (recursive)
                 -> getLinks + filterLinks
       -> writeSiteFile + writeUrlFile
  -> a second newSave at a caller-chosen time
  -> readSavedSites for each chosen snapshot
  -> diffSavedSites -> diffLinks
  -> printSnapshotHtml or getSnapshotEmailText/getSnapshotEmailHtml
  -> optional sendMail
```

This is a map of composable functions, not an executable flow contained in Appendix A. No Appendix A caller loads the XML, chooses snapshot directories, invokes the steps in sequence, selects subscribers, or decides when to send mail.

The fixed extraction expressions are in `newSave` (lines 41-44): publication results match `.ps.gz`, `.pdf`, `.ps`, or `.ppt`, while exploration is limited by a separate expression for web-like links plus the configured `allow` string. The manual course/class noise rule appears in report generation (`printSnapshotHtml`, lines 423-425, or the `rule1` option in the email body builders, lines 533-539 and 609-615), rather than being unconditionally applied during `newSave`.

## C. Internal completeness

### Project-function call resolution

All active, unqualified project-function calls in Appendix A resolve to one of the 42 functions defined in the same package. The following table lists every function that makes an active project call; functions absent from the table make none. The definitions occupy lines 36-1281, followed by the package return on line 1284.

| Caller | Active Appendix A callees |
|---|---|
| `newSave` | `getLinksForAllSites`, `browserPrint`, `writeSiteFile`, `writeUrlFile` |
| `diffSavedSites` | `debugPrint`, `diffLinks` |
| `readSavedSites` | `readSiteFile`, `readUrlFile` |
| `getLinks` | `browserPrint`, `debugPrint` |
| `filterLinks` | `browserPrint` |
| `filterOutLinks` | `browserPrint` |
| `getLinksForSite` | `browserPrint`, `getLinks`, `filterLinks`, `debugPrint`, and recursive `getLinksForSite` |
| `getLinksForAllSites` | `getLinksForSite`, `debugPrint`, `browserPrint` |
| `printSnapshotHtml` | `getKeysSortedByName`, `filterOutLinks`, `removeDuplicateLinks` |
| `getSnapshotEmailHtml` | `getKeysSortedByName`, `filterOutLinks`, `removeDuplicateLinks` |
| `getSnapshotEmailText` | `getKeysSortedByName`, `filterOutLinks`, `removeDuplicateLinks` |
| `readSiteFile` | `checkUrlFormat`, `browserPrint` |
| `writeSiteFile` | `checkUrlFormat`, `browserPrint` |
| `readUrlFile` | `checkUrlFormat`, `browserPrint` |
| `writeUrlFile` | `checkUrlFormat`, `browserPrint` |
| `diffLinks` | `sortLinks` |
| `printLinkInfo` | `debugPrint` |
| `parseXml` | `parseXmlHelper` |
| `parseXmlHelper` | recursive `parseXmlHelper` |
| `generateXml` | `generateXmlHelper` |
| `generateXmlHelper` | recursive `generateXmlHelper` |
| `convertProfessorHashToSiteHash` | `checkUrlFormat` |
| `filterProfessorHash` | `findInArray` |

`quickDebug` appears only in four commented lines (209, 211, 245, and 247) in `filterLinks` and `filterOutLinks`; no `quickDebug` definition appears in Appendix A. Commented references to `debugPrint` do resolve to the Appendix A definition but are not active calls. There is no unresolved active project call.

### Call categories

- **Defined in Appendix A:** the active project calls listed above.
- **Perl builtins:** operations such as `shift`, `defined`, `exists`, `keys`, `values`, `sort`, `grep`, `lc`, `scalar`, `push`, `delete`, `ref`, `open`, `close`, `print`, `warn`, `die`, `mkdir`, `chmod`, `opendir`, `readdir`, `closedir`, and `time`.
- **External package methods:** construction and methods on `LWP::UserAgent`, `HTTP::Request`, HTTP response objects, `HTML::TokeParser`, and `URI` objects.
- **Unresolved/project-defined active calls:** none.
- **Comment-only unresolved symbol:** `quickDebug`.

The file declares `package MonitorUtils` and ends with `1;`. It has no `main` routine, command-line processing, top-level workflow, `Exporter` use, or export list. A surrounding caller must load the package and invoke its functions, normally by fully qualified package name unless it supplies some separate import mechanism.

### Package/global state

| State | Visible users |
|---|---|
| `$ua` | A package-scoped `LWP::UserAgent` constructed at load time, assigned agent string `TestBot/0.1`, and reused by `getLinks`. |
| `$sendmail` | Absolute command string `/usr/sbin/sendmail -t`, used by `sendMail`. |
| `$BROWSER` | Set by `setBrowser`; read by `browserPrint`. |
| `$DEBUG` | Set by `setDebug`; read by `debugPrint`. |
| `%crawledLinks` | Used by the recursive crawler to avoid revisiting URLs and reset around each top-level site crawl. |
| `%SiteTitles` | Seeded by `convertProfessorHashToSiteHash`, filled from HTTP response titles by `getLinks`, and consulted when writing site/URL files. |
| `%changedUrls`, `%changedSites` | Declared but not otherwise referenced in Appendix A. |

## D. External Perl dependencies

### Explicit `use` statements

The six explicit statements are together on Appendix A lines 5-10.

| Statement | Visible Appendix A use |
|---|---|
| `use strict;` | Enables strict checking for the package. |
| `use HTTP::Request;` | Constructs GET requests in `getLinks`. |
| `use HTTP::Response;` | Explicit dependency; response objects are used through values returned by the user agent, although the class name is not otherwise referenced. |
| `use LWP::UserAgent;` | Constructs the shared HTTP client and performs requests. |
| `use HTML::TokeParser;` | Parses fetched HTML and extracts anchor tags/text. |
| `use HTTP::Headers;` | Explicit dependency, with no direct class reference elsewhere in Appendix A. |

### Other package/class references

- `URI->new` constructs page and link URI objects; `abs` and `canonical` resolve and normalize discovered links (lines 183-188).
- No `use URI;` appears in Appendix A. A successful compile on a particular machine does not establish how `URI` was historically loaded or declare it as a reconstructed dependency.
- Response methods used are `is_success`, `title`, and `content_ref`; parser methods are `get_tag` and `get_trimmed_text`; user-agent methods are `new`, `agent`, and `request`.

No dependency versions are specified. This audit does not infer the 2004 installed module set from the current machine's ability to compile the package.

## E. OS and platform dependencies

- The shebang is `/usr/bin/perl`. The separately observed baseline identifies `/usr/bin/perl` as Perl 5.30.3 on the current Mac, but Appendix A itself does not constrain a Perl version.
- `sendMail` opens a process pipe to the absolute command `/usr/sbin/sendmail -t`. That path, program, mail configuration, and permission to invoke it are external to Appendix A.
- Snapshot and cache operations use the host filesystem through bareword filehandles, `open`, `close`, `mkdir`, `opendir`, `readdir`, and `closedir`.
- `newSave` requests mode `0777` when creating and then changing a snapshot directory. Snapshot and raw-cache files are changed to mode `0664`.
- Snapshot directory names use Perl's epoch-valued `time` directly. Appendix A contains no `localtime` call or display-date conversion; the GUI's human-readable dates must come from surrounding code.
- The caller-supplied snapshot root is concatenated directly with the epoch value and `/`, so separator placement and root-directory existence are caller/environment concerns.
- Per-site filenames are derived by replacing `/` characters in URLs with backslashes and prefixing `_`, `okay_`, or `broken_` according to file role. `translateUrlToFileName` performs a related slash-to-backslash conversion for raw cache files. These are visible filename assumptions, not a portable path policy reconstructed here.
- `getLinks` requires live HTTP/network access through `LWP::UserAgent`, makes up to two attempts, and treats a non-success response as a broken URL result.
- Diagnostics and browser/report bodies use standard output; warnings and fatal errors use `warn` and `die`.
- No timer, daemon, cron integration, launch service, or other scheduler facility appears in Appendix A.

## F. Data and file formats

### Researcher configuration

Chapter 4's researcher DTD describes a collection of researchers, each with `Name`, `Email`, and one or more `Site` entries; each site has `URL` plus optional `Depth` and `Allow`. Email uniquely identifies a researcher in the described configuration.

Appendix A reconstructs the following in-memory forms:

```text
professor_hash = {
  researcher_email => {
    name  => researcher_name,
    sites => {
      site_url => {
        depth => optional_depth,
        allow => optional_allow
      }
    }
  }
}

site_hash = {
  site_url => {
    name   => researcher_name,
    depth  => optional_depth,
    allow  => optional_allow,
    links  => added_by_crawl_or_snapshot_read,
    okay   => added_by_crawl_or_snapshot_read,
    broken => added_by_crawl_or_snapshot_read,
    title  => added_by_snapshot_read
  }
}
```

`convertXmlHashToProfessorHash` and its reverse use lowercase keys (`professor`, `email`, `name`, `site`, `url`, `depth`, `allow`). `parseXml` additionally expects an outer `xml-document` element. Chapter 4's printed DTD and sample use different capitalization and show a plural collection element; the absent configuration caller's normalization/wrapping behavior cannot be determined from Appendix A.

### User configuration

Appendix A supports this in-memory form:

```text
user_hash = {
  user_email => {
    name   => user_name,
    notify => notification_value,
    url    => array_reference_of_selected_urls
  }
}
```

The XML-shaped form uses repeated lowercase `user` entries with `email`, `name`, `notify`, and `url` children. Chapter 4 states that the user XML stores subscriber emails and selected sites, but does not print the user DTD or enumerate the actual values accepted by `notify`. Appendix A converts the value but does not interpret it.

### Course configuration

Chapter 4 says the course DTD is similar to the researcher DTD, except `description` and `id` replace researcher `name` and `email`; course entries also contain monitored sites with optional depth and allow controls. No course-specific XML/hash conversion function appears in Appendix A. This structure is thesis-described surrounding configuration, not recovered implementation.

### Depth and allow semantics

- Chapter 4 says depth zero means do not crawl, positive values bound traversal, and an omitted depth means unlimited traversal.
- Appendix A first fetches the current URL (line 305) and then stops recursion when depth is zero (line 317). Missing or non-numeric depth becomes `1000` (lines 362-364), described in a source comment as large enough to represent infinite depth.
- `getLinksForAllSites` passes both a fixed exploration expression and the configured `allow` string as sequential crawl filters. A defined nonblank allow value therefore restricts followed links further; blank or undefined allow leaves the prior set unchanged.

The difference between the thesis's depth-zero description and the Appendix A fetch-then-stop behavior is preserved as evidence and not resolved here.

### Snapshot directory and files

`newSave` (lines 36-65) and the snapshot file readers/writers (lines 664-822) establish this layout:

```text
<caller location><epoch time>/
  _<site URL with slash characters replaced by backslashes>
  okay_<site URL with slash characters replaced by backslashes>
  broken_<site URL with slash characters replaced by backslashes>
```

The main per-site file begins with:

```text
site_url|depth|site_title|allow
```

It is followed by zero or more extracted link records:

```text
publication_url|anchor_or_fallback_text|source_page_url|source_page_title
```

The `okay_` and `broken_` files contain only records in the four-field link form. The readers and writers do not implement general escaping for the pipe delimiter. `readSiteFile` deliberately rejoins extra header fields into `allow`, but link records are split into four variables without an escape convention.

In memory, a crawled link is an array reference:

```text
[canonical_target_url, anchor_text, canonical_source_page_url, source_page_title]
```

`diffLinks` copies a record and appends a fifth value, either `added to` or `removed from`.

### Raw page cache

`readCachedPage` and `writeCachedPage` read and write an entire scalar page body. `translateUrlToFileName` replaces slashes with backslashes and prefixes an underscore. Appendix A does not define the raw-cache directory, course record metadata, overwrite workflow, or content-difference representation.

### XML structure reconstructable from Appendix A

The parser/generator (lines 967-1063) represents each element name as a hash key whose value is an array reference, allowing repeated elements. A nested element becomes a hash reference stored in that array; text content is stored as a scalar. `generateXml` wraps output in `<xml-document>`. No attribute model, DTD validation, entity policy, file encoding policy, or configuration-file I/O is visible.

## G. Missing surrounding application components

The following Chapter 4 components do not appear as implemented application components in Appendix A:

- **Executable/main entry point:** no script parses arguments, loads configuration, chooses a domain, or invokes `MonitorUtils`.
- **Scheduler:** no timed process sequences crawl, extraction, cache, diff, and notification or implements daily/weekly intervals.
- **GUI/controller:** report HTML and browser progress helpers exist, but the forms, routes/actions, snapshot selection, administrative operations, and user-facing controller do not.
- **Configuration file orchestration:** XML string parsing/generation and hash conversion exist, but no code opens, saves, locks, validates, or locates the researcher, course, or user XML files.
- **Initial batch configuration:** Chapter 4 describes an initial batch process; its source and dataset are absent.
- **User subscription orchestration:** there is no caller that maps users to selected sites, interprets `notify`, filters a diff per user, or chooses recipients/subjects.
- **Course-domain crawl/cache orchestration:** raw-cache helpers exist, but no caller fetches course page bodies, maps pages to files, or applies the overwrite policy.
- **Course-domain difference algorithm:** no character comparison, threshold calculation, HTML normalization, or changed-page result builder is present.
- **Periodic/eager notification decisions:** email body and transport helpers exist, but no policy logic decides whether or when to send.
- **Application-level caller of `MonitorUtils`:** every visible workflow ends at package functions; nothing in Appendix A invokes the package as an application.
- **Snapshot lifecycle management:** listing is supported, but removal, retention, selection of previous/current snapshots, and conversion of epoch directory names to displayed dates are absent.

These are surrounding application components not printed in Appendix A. Their absence does not make the archival transcription incomplete.

## H. Capability matrix

| Chapter 4 feature/module | Described in thesis | Implementation visible in Appendix A | External dependency | Surrounding code absent | Uncertain |
|---|---|---|---|---|---|
| GUI | Full administrator/user web interface | HTML report body and progress-print helpers only | Web server/runtime not identified | Forms, controller, routes, actions, snapshot selection | Historical GUI source/runtime |
| Configuration | Initial batch plus three XML files and GUI updates | XML string parser/generator; user/professor/hash conversions and selection helpers | Filesystem for missing file layer | File loading/saving, DTD handling, batch loader, GUI updates, course conversion | Exact filenames, roots/case normalization, `notify` values |
| Snapshots | Periodic/manual crawl-extract-cache unit | Researcher `newSave`, snapshot read/write, directory listing | Filesystem, clock, network | Caller, lifecycle/selection, manual/scheduled trigger | Historical root paths and retention policy |
| Crawler | Depth/allow-controlled researcher and course crawl | Recursive anchor crawler with result/exploration/allow filters | LWP/HTTP, HTML parser, URI, network | Domain selection and top-level invocation | Intended depth-zero behavior differs from code path |
| Researcher extraction | Downloadable publication links and manual noise rules | Extension filter, anchor metadata, optional report-time noise filters | HTTP/HTML/URI modules | Rule selection/defaults | Whether historical caller always enabled duplicate/noise hiding |
| Course extraction | Monitor complete page content | No extraction pipeline; only generic raw-cache helpers | Filesystem; missing fetch/content layer | Page-body capture and page identity orchestration | Exact representation/normalization of cached pages |
| Archive caching | Timestamped researcher history | Epoch directory and three files per site | Filesystem, permissions, clock | Root selection and retention | Mapping to GUI display dates |
| Overwrite caching | One course copy, replaced on qualifying change | Raw scalar read/write primitives only | Filesystem | Comparison and conditional overwrite workflow | Course cache layout |
| Researcher diff | Added/removed unique publication URLs; duplicate suppression | `diffLinks`, `diffSavedSites`, optional report deduplication, broken-page suppression | None beyond in-memory data | Snapshot selection and report option policy | How caller enforced the thesis's duplicate rule |
| Course diff | Character threshold; report changed page | Not visible | Algorithm/runtime not identified | Entire content comparator and changed-page result | Exact metric and the threshold-one wording |
| Notification | On-demand, eager, periodic | Text/HTML bodies and `sendMail` transport | `/usr/sbin/sendmail -t` | Subscription filtering, timing, policy decisions, subjects/from values | Exact preference vocabulary |
| Scheduler | Administrator interval; daily in both domains | No scheduler implementation | OS scheduler/timer not identified | Entire scheduling/orchestration component | Historical scheduler technology and configuration |

## I. Minimum Stage 3 restoration path

### Smallest historically defensible backend demonstration

The narrowest end-to-end path supported by surviving code is the researcher archive pipeline:

```text
configuration/site hash
  -> researcher crawl and publication extraction
  -> first timestamped snapshot
  -> second timestamped snapshot
  -> read both snapshots
  -> researcher publication diff
  -> text and/or HTML report
```

The historical Appendix A functions to preserve and invoke are:

1. Construct or load a professor hash, then use `convertProfessorHashToSiteHash`, or provide the equivalent site hash directly.
2. Call `newSave` for the first snapshot.
3. At a separately controlled time, call `newSave` for the second snapshot.
4. Starting from the same configured site keys, call `readSavedSites` for each returned snapshot directory.
5. Call `diffSavedSites` with the earlier snapshot first and later snapshot second so `diffLinks` labels results as removed from or added to the later snapshot.
6. Render with `getSnapshotEmailText`, `getSnapshotEmailHtml`, or `printSnapshotHtml`, explicitly deciding whether to hide duplicate URLs and apply the manual course/class-document rule.

Appendix A supplies those backend operations. Stage 3 must supply a new, clearly labeled reconstruction/caller that loads the frozen package, provides controlled configuration and paths, orders the calls, chooses snapshots, handles failures, and selects report options. That caller will be new reconstruction code because the historical caller is not present; it must not be presented as recovered source.

### Additions beyond the minimum path

- **Notification:** add a reconstructed caller that interprets user preferences, filters sites per subscriber, decides recipient/from/subject values, chooses eager or periodic behavior, and only then invokes the preserved body builders and `sendMail`. Transport should be isolated so restoration work does not accidentally send mail.
- **Course-domain monitoring:** reconstruct raw page fetching, URL-to-cache mapping, content comparison, threshold semantics, changed-page reporting, and conditional overwrite. Appendix A's raw-cache helpers may be reused as historical primitives, but the missing algorithm and orchestration must be labeled new reconstruction.
- **Scheduler:** add a reconstructed scheduling boundary that chooses intervals and sequences snapshots, diffs, and notification. The thesis provides behavior, not the historical scheduling mechanism.
- **GUI:** add a reconstructed controller and views for configuration, snapshot selection, reports, subscriptions, and manual snapshots. `printSnapshotHtml` can inform output compatibility but is not itself the historical GUI.

## J. Open questions

The following cannot be answered from Chapter 4 or Appendix A:

1. What scripts, package-loading conventions, arguments, web routes, and directory layout comprised the original caller/controller?
2. What were the exact researcher, course, and user XML filenames, document roots, capitalization rules, and wrapping steps used to reconcile the Chapter 4 DTD/sample with Appendix A's lowercase keys and required `xml-document` wrapper?
3. What values were valid for the user `notify` field, and how were eager, periodic, and on-demand preferences encoded?
4. What batch input and process created the initial researcher/course configuration?
5. What scheduler technology was used, where was its interval configured, and how were missed or overlapping runs handled?
6. What exact course-page difference algorithm counted characters, what normalization preceded comparison, and how should the thesis's “exceeds” threshold-one wording be reconciled with “any change”?
7. What course cache directory/file layout and metadata connected page URLs to `readCachedPage` and `writeCachedPage`?
8. Did the historical caller compensate for the difference between Chapter 4's depth-zero description and Appendix A's fetch-current-page-then-stop behavior?
9. Which duplicate/noise-filter options did the historical caller enable by default so that reports matched Chapter 4's stated suppression behavior?
10. How were epoch snapshot directories converted to the human-readable dates shown by the GUI, and what timezone was used?
11. Which current or historical module versions supplied `URI`, and was it loaded deliberately by surrounding code or incidentally through another module?

These questions should remain open until additional historical evidence is found. Stage 3 may make explicit reconstruction choices, but those choices must be documented as new behavior rather than attributed to the surviving Appendix A code.
