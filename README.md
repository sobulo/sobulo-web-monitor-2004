# sobulo-web-monitor-2004

Historical preservation and reconstruction of the Perl monitoring-system backend documented in my 2004 University of Illinois at Urbana-Champaign master's thesis, *Query Translation for an Information Integration System and Building a Monitoring System*.

The thesis has two related but distinct parts. Chapters 1–3 document a MOBS-based bookstore information-integration system, with particular focus on query translation. The broader MOBS research predates the thesis and should be attributed to AnHai Doan and collaborators. Chapter 4 and Appendix A present the separate monitoring-system work; Appendix A contains the Perl backend preserved in this repository.

This repository uses the thesis as a historical and technical source, not as a claim that the MOBS ideas originated with me. Where MOBS material is discussed or later re-created, it should be understood as implementation or educational reconstruction of research from AnHai Doan's group. The monitoring-system implementation is the main historical code being preserved here.

## Chronology and attribution

- **2003:** Early MOBS work includes [*Building Data Integration Systems: A Mass Collaboration Approach*](https://pages.cs.wisc.edu/~anhai/projects/papers/mobs-ijcai03-workshop.pdf) by AnHai Doan and Robert McCann, and [*Building Data Integration Systems via Mass Collaboration*](https://pages.cs.wisc.edu/~anhai/projects/papers/mobs-webdb03.pdf) by Robert McCann, AnHai Doan, Alexander Kramnik, and Vanitha Varadarajan. These papers describe the mass-collaboration approach and bookstore information-integration examples.
- **[2004](https://github.com/sobulo/sobulo-web-monitor-2004/tree/main/source):** My master's thesis documents and analyzes the MOBS-based query-translation application and separately presents the monitoring system that I implemented. The repository's `source/` directory contains the thesis and source-artifact documentation.
- **2005:** The research group published [*Integrating Data from Disparate Sources: A Mass Collaboration Approach*](https://pages.cs.wisc.edu/~anhai/papers/mobs-icde05.pdf), continuing the MOBS line of work; I am a coauthor on that paper.
- **[2026](https://github.com/sobulo/sobulo-web-monitor-2004/commits/main/):** This repository preserves the historical monitoring implementation and prepares it for careful reconstruction, execution, and later modernization while keeping historical attribution explicit. The linked commit history records that reconstruction process.

## Current status

The complete Perl backend printed in Appendix A has been transcribed and checked against the thesis. The archival transcription covers logical thesis pages 38–62 (physical PDF pages 45–69), printed lines 1–1284.

The next phase is a static audit of external modules, operating-system dependencies, configuration/data expectations, and surrounding application components before any attempt is made to execute or repair the historical code.

## Repository areas

- `source/` contains the published thesis PDF and source-artifact documentation.
- `original/appendix-a/` contains the faithful Appendix A transcription and its audit records.
- `docs/` records provenance, transcription method, function/dependency inventory, and AI assistance.
- `work/` contains derived page renders and machine-extracted working text used for verification.

Machine-extracted text is verification evidence only and is not represented as original source code. The committed thesis PDF remains the primary published reference.

The archival transcription in `original/` is intentionally preserved separately from any corrected or runnable version that may be created later, so historical evidence and later engineering work remain distinguishable.
