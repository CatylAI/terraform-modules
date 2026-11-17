# contracts/

Language-neutral values this repository shares with the rest of the platform. Read in place,
never copied into a module.

- `environments.v1.json`: the environment enum. It is a projection of `/environments` and
  `/strict_environments` in lib-platform's `contracts/telemetry-vocabulary.v1.json`
  (ADR-0002), so infrastructure labels and runtime `APP_ENV` share one vocabulary.

## Canonical byte form

Same as lib-platform: two-space JSON, keys sorted recursively, non-ASCII unescaped, one
trailing newline. `scripts/check_invariants.py` fails on a non-canonical file.

## How the gate holds it

1. `modules/_internal/context` carries the list as a literal (Terraform cannot read a file
   outside the module package at plan time without coupling to repo layout). The gate fails if
   that literal differs from `environments` here.
2. When `PLATFORM_LIBS_DIR` points at a lib-platform checkout, the gate also fails if this file
   differs from the source pointer. CI sets it once the actions library can fetch lib-platform;
   until then that half is checked locally only. That gap is listed in the README's
   "Not yet verified".

## Changing it

Change lib-platform first (its own contract rule), then this file, the literal in
`_internal/context`, and every module's `.context-digest` in one change.
