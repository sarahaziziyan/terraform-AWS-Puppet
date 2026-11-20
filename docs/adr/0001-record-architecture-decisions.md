# 0001. Record architecture decisions as ADRs

- **Status:** Accepted
- **Date:** 2026-11-20
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** —

## Context

The reasons for the design were kept in one table in [ARCHITECTURE.md](../ARCHITECTURE.md). The table shows only the current state. Several decisions changed between October and November 2026 (the site moved from user data to Puppet, the autosign secret moved to SSM, the ALB moved behind CloudFront), and the earlier choices and why they were dropped exist only in commit history.

## Decision

We will record each significant architecture decision as an Architecture Decision Record in `docs/adr/`, one Markdown file per decision, numbered `NNNN-title.md`.

- Each record follows Michael Nygard's template (Title, Status, Context, Decision, Consequences) with three additions from MADR: a date, considered options, and consequences split into good and bad.
- Records are not rewritten when a decision changes. A new record is written, the old one's status becomes **Superseded**, and both link to each other (`Supersedes` / `Superseded by`).
- A decision that adds to an earlier one without replacing it says so in its Context and links back.
- [README.md](README.md) in this folder is the decision log: one row per record, with its date, status and what superseded it.

## Considered options

- **ADRs in the repository**: reviewed and versioned with the code they describe.
- **Keep only the table in ARCHITECTURE.md**: short, but it loses history and has no room for alternatives or downsides.

## Consequences

### Good

- The reason for each part of the design, and what it replaced, can be found without reading commit history.
- ARCHITECTURE.md can stay short and link to the records.

### Bad

- One more place to update: a change to a decision needs a new ADR as well as code and doc changes.

## Links

- [template.md](template.md)
- Michael Nygard, "Documenting Architecture Decisions" (2011)
- MADR: <https://adr.github.io/madr/>
