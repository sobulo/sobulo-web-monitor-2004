# Function and dependency inventory

Scope: the complete Appendix A transcription, logical thesis pages 38-62 (printed lines 1-1284). This inventory records only definitions, calls, and dependencies visible in the appendix.

## Functions defined in Appendix A

| Function | Printed lines | Visible purpose |
|---|---:|---|
| `newSave` | 36-65 | Takes website snapshots and writes per-site snapshot files in a time-stamped directory. |
| `getDirList` | 71-79 | Reads and reverse-sorts directory contents. |
| `diffSavedSites` | 85-123 | Computes differences between saved link sets and marks broken links. |
| `readSavedSites` | 129-146 | Reads saved site and URL files into a site hash reference. |
| `getLinks` | 152-191 | Retrieves a page and extracts canonicalized link information. |
| `filterLinks` | 198-215 | Keeps links matching a regular-expression filter. |
| `filterOutLinks` | 223-251 | Removes links whose selected fields match a regular-expression filter. |
| `removeDuplicateLinks` | 257-281 | Removes links with duplicate URLs. |
| `filterHash` | 283-296 | Takes a source hash and a list of keys, and returns a new hash containing only keys that exist in the source hash. |
| `getLinksForSite` | 298-345 | Retrieves links for one site, filters results, recursively crawls according to depth and crawl filters, and collects okay and broken URLs. |
| `getLinksForAllSites` | 349-380 | Retrieves links for all configured sites. |
| `getKeysSortedByName` | 382-388 | Sorts hash keys by the nested `name` value. |
| `printSnapshotHtml` | 390-499 | Prints an HTML snapshot/difference report. |
| `getSnapshotEmailHtml` | 501-575 | Builds the HTML form of a snapshot email. |
| `getSnapshotEmailText` | 577-649 | Builds the plain-text form of a snapshot email. |
| `checkUrlFormat` | 651-662 | Validates that a URL matches the expected `http://` or `https://` format, warning and returning false when it does not. |
| `readSiteFile` | 664-704 | Reads site records from a delimited file. |
| `writeSiteFile` | 706-747 | Writes site records to a delimited file. |
| `readUrlFile` | 749-781 | Reads URL records from a delimited file. |
| `writeUrlFile` | 783-822 | Writes URL records to a delimited file. |
| `sortLinks` | 824-829 | Sorts link records by URL. |
| `diffLinks` | 831-878 | Compares two sorted link sets and returns links marked as added or removed. |
| `printLinkInfo` | 880-893 | Prints selected link fields. |
| `translateUrlToFileName` | 895-901 | Converts a URL into a cache filename. |
| `readCachedPage` | 903-909 | Reads a cached page from disk. |
| `writeCachedPage` | 911-924 | Writes a page to the cache. |
| `sendMail` | 926-965 | Sends a multipart plain-text/HTML message through `sendmail`. |
| `parseXml` | 967-976 | Parses XML text into the nested hash and array structure used by the monitoring system. |
| `parseXmlHelper` | 978-1017 | Recursively converts parsed XML nodes into nested data structures. |
| `generateXml` | 1019-1025 | Starts XML generation for a nested hash. |
| `generateXmlHelper` | 1027-1063 | Recursively renders nested hashes and arrays as XML text. |
| `convertXmlHashToUserHash` | 1065-1083 | Converts XML-shaped user data to the monitoring-system user hash. |
| `convertUserHashToXmlHash` | 1085-1106 | Converts the monitoring-system user hash to XML-shaped data. |
| `convertXmlHashToProfessorHash` | 1108-1142 | Converts XML-shaped professor data to the professor hash. |
| `convertProfessorHashToXmlHash` | 1144-1178 | Converts the professor hash to XML-shaped data. |
| `convertProfessorHashToSiteHash` | 1180-1201 | Converts professor/course data to site records. |
| `filterProfessorHash` | 1203-1239 | Filters professor and site data according to the supplied selected-site URLs, removing professors that have no selected sites remaining. |
| `findInArray` | 1243-1253 | Searches an array for an exact value. |
| `setDebug` | 1255-1258 | Sets the package debug flag. |
| `debugPrint` | 1260-1267 | Conditionally prints a debug message. |
| `setBrowser` | 1269-1272 | Sets the package browser-output flag. |
| `browserPrint` | 1274-1281 | Conditionally prints a browser message. |

The package's final true return value is `1;` on printed line 1284.

## Calls to project functions

Calls between the routines above include `browserPrint`, `debugPrint`, `getLinksForAllSites`, `writeSiteFile`, `writeUrlFile`, `diffLinks`, `readSiteFile`, `readUrlFile`, `getLinks`, `filterLinks`, `filterOutLinks`, `removeDuplicateLinks`, `getLinksForSite`, `getKeysSortedByName`, `checkUrlFormat`, `sortLinks`, `parseXmlHelper`, `generateXmlHelper`, and `findInArray`. Every project-function call visible in the completed appendix resolves to a function defined in Appendix A; no additional project function is inferred.

## External Perl modules and packages

- `strict`
- `HTTP::Request`
- `HTTP::Response`
- `LWP::UserAgent`
- `HTML::TokeParser`
- `HTTP::Headers`
- `URI` is referenced through `URI->new`, although no corresponding `use URI` statement is visible in Appendix A.

## External programs and OS facilities

- `/usr/sbin/sendmail -t`, opened as a process pipe by `sendMail`.
- Filesystem and directory facilities: `mkdir`, `chmod`, `opendir`, `readdir`, `closedir`, file `open`, and file `close`.
- The system clock through Perl's `time` function.
- HTTP/network access through `LWP::UserAgent` and HTTP request/response objects.

This inventory does not correct missing imports, obsolete APIs, apparent defects, or questionable behavior.
