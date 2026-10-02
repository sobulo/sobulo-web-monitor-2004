# Controlled researcher-site fixture

This directory is 2026 reconstruction/test infrastructure. It is not recovered 2004 source.

`index.html` is served only on loopback during the Stage 3 demonstration. The `states/` directory preserves the initial and updated page states used to take two snapshots:

- `states/index.initial.html` links to `database-monitoring.pdf` and `legacy-system.ps`.
- `states/index.updated.html` retains `database-monitoring.pdf`, removes the link to `legacy-system.ps`, and adds `reconstruction-notes.ppt`.

The files under `publications/` are inert placeholders. The historical researcher crawler records publication links but does not download those target files in this depth-zero fixture.
