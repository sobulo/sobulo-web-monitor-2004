# Running the reconstructed researcher-monitor demonstration

This guide reproduces the controlled local demonstration used to validate the surviving Appendix A backend.

The historical Perl source remains frozen at:

`original/appendix-a/MonitorUtils.thesis.pl`

The caller in `scripts/` and the website in `fixtures/` are 2026 reconstruction/test infrastructure, not recovered 2004 source.

## Prerequisites

You need:

- Perl with the modules required by the Appendix A package
- Python 3, used only to serve the local fixture
- a shell such as zsh or bash

First verify that the historical package loads on your machine:

```bash
perl -c original/appendix-a/MonitorUtils.thesis.pl
```

A working environment should report:

```text
original/appendix-a/MonitorUtils.thesis.pl syntax OK
```

## 1. Start the controlled local website

From the repository root, reset the fixture to its initial state:

```bash
cp fixtures/researcher-site/states/index.initial.html fixtures/researcher-site/index.html
```

In one terminal, start the local HTTP server:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory fixtures/researcher-site
```

Leave that terminal running. The monitored page is now:

```text
http://127.0.0.1:8765/index.html
```

The reconstruction caller intentionally rejects non-loopback URLs.

## 2. Take the first snapshot

In a second terminal, from the repository root:

```bash
perl scripts/researcher-monitor.pl snapshot
```

The command prints the generated snapshot directory under:

```text
runtime/researcher-monitor/
```

Save the printed path; it will be the older snapshot supplied to the diff command.

## 3. Change the controlled page

Replace the served page with the second committed fixture state:

```bash
cp fixtures/researcher-site/states/index.updated.html fixtures/researcher-site/index.html
```

The updated page keeps one publication link, removes one previously visible publication link, and adds a new publication link.

The monitor does not modify any publication files. It observes the links exposed by the page.

## 4. Take the second snapshot

Wait at least one second because the historical code names snapshot directories using epoch seconds:

```bash
sleep 2
perl scripts/researcher-monitor.pl snapshot
```

Save the second printed snapshot path.

## 5. Compare the snapshots

Pass the older directory first and the newer directory second:

```bash
perl scripts/researcher-monitor.pl diff \
  runtime/researcher-monitor/<OLDER_EPOCH> \
  runtime/researcher-monitor/<NEWER_EPOCH>
```

The expected report identifies:

- one publication link that existed in the first snapshot but is missing from the second; and
- one publication link that appears in the second snapshot but not the first.

You may also see two non-fatal `illegal url format` warnings. These come from preserved historical handling of the root page's successful-crawl record and are documented in `docs/restoration-log.md`.

## What this demonstrates

The controlled run exercises the surviving researcher-domain path:

```text
local site configuration
  -> page retrieval
  -> publication-link filtering
  -> timestamped snapshot
  -> changed fixture
  -> second snapshot
  -> snapshot reload
  -> added/removed link comparison
  -> plain-text report
```

The test deliberately uses a local fixture so the result does not depend on modern external websites, redirects, TLS behavior, robots policies, or pages that have changed since 2004.

## Scope

This repository demonstrates and documents the surviving Appendix A researcher-monitoring backend. It does not reconstruct the full historical presentation and orchestration layers described in the thesis, including the GUI/controller, scheduler, notification policy, configuration-file management, or the course-domain implementation.

Generated snapshots live under `runtime/`, which is ignored by Git.
