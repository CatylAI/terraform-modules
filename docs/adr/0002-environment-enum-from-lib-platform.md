# ADR-0002: The environment enum is lib-platform's: local, test, dev, uat, staging, prod

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17

## Context

Three vocabularies were in use. The old SOP and template used `dev | staging | production`. The
AWS baseline used `mgmt | prod | nonprod | dev | sandbox | local`. lib-platform's telemetry
contract uses `local, test, dev, uat, staging, prod` for `APP_ENV`. The first application consumer already deploys `uat`
and `prod`.

## Decision

- `contracts/environments.v1.json` is a projection of lib-platform's
  `contracts/telemetry-vocabulary.v1.json` `/environments` and `/strict_environments`.
- `_internal/context` validates `context.environment` against it, and the gate holds the literal
  in that module equal to the contract.
- The display name of an existing `production` folder is not renamed; display names are labels
  for humans, not this enum.

## Consequences

- An infrastructure label `environment=uat` and a log record's `env=uat` are the same string,
  so a query can join them.
- Adding an environment is a lib-platform change first.
- Another organisation using these modules passes its own vocabulary through
  `context.allowed_environments` (MS-15.3). CatylAI roots never set it.
- The cross-repo check (contract versus lib-platform) runs only where a lib-platform checkout is
  available. That is local-only until the actions library can fetch it in CI.

## Alternatives

`dev | staging | production` was rejected because it disagrees with both lib-platform and
existing deployments. A minimal `uat | prod` enum was rejected because every new environment would then need a
release of every module.
