# prototype-qa

QA agent, Marionette-driven.

Order, hard-capped at 8 cases: smoke → **every demo prompt, live, verbatim** (flaky sites: 3 runs, report n/3) → ≤5 more spec criteria by risk. Every failure classified `spec | design | build | infra`. `infra` is self-fixed; `build` may go through the live fix loop (capped per demo prompt); anything else is reported for the coordinator to route.

Reports go to `reports/qa-cycle-N.md` (+ `qa-latest.md`) with a separate demo-prompt table, embedded diagnostics and screenshots. Never sets `completed.*`. Never kills Firefox broadly.

The Firefox DevTools MCP server is not attached to prototype builds; QA relies on Marionette, the console service and screenshots.
