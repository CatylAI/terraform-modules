# ADR-0010: This standard supersedes the four prior Terraform documents

Status: Accepted
Decided by: plan approval, 2026-11-17

## Context

Four internal documents each gave different
answers: an SOP, a module template, and two agent skills. on versions, environments, tags and lock files.

## Decision

`docs/spec/module-standard.md` is binding for modules here and for roots that consume them. The
other four documents are amended in wave 5 to point here, or are archived.

## Consequences

- Until wave 5 lands, a reader can still find the old documents. Each module README links the
  spec.

## Alternatives

Amending the SOP in place was rejected: it lives in a docs repo with no gate, so nothing would
hold code to it.
