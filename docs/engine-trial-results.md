# Local coding-engine investigation

Date: 2026-10-25. Engine: OpenCode 1.19.4 native Linux x64, running in Ubuntu-26.04 WSL.
Model: qwen/qwen3.5-9b, served by LM Studio on the Windows host, configured context 16,640.

## Observed results

| Check | Result |
| --- | --- |
| Native Linux CLI starts | Pass, version 1.19.4 |
| Local-only provider | Response metadata confirms provider `local` / model `qwen/qwen3.5-9b` |
| Read files and edit Ruby | Pass, nil-handling bug fixed in disposable fixture |
| Execute Ruby check command | Pass, observed tool result and independent rerun |
| HTTP health | healthy=true, version=1.19.4 |
| HTTP coding run | Completed in 57.37 seconds; five persisted messages |
| Independent checks after API run | Exit 0, `2 checks passed` |
| Cancel active generation | Status busy -> abort=true -> no busy session |
| Event endpoint | SSE `server.connected` event observed; full reconnect/replay not yet tested |
| Session diff endpoint | Returned []; independent `git diff` shows 1 file, 5 additions, 1 deletion |
| Child-agent delegation | Not yet tested |
| One vs two workers | Not yet measured |

## Decision from evidence

OpenCode is a promising engine, but adoption remains provisional. Keep the current app's
read-only agent unchanged for this first milestone. Before enabling implementation runs,
collect Git diffs directly from the task worktree and verify the baseline commit. Do not
interpret an empty engine diff as proof that no files changed. Investigate the endpoint
behavior or retain independent Git artifacts as the source of truth.

Cancellation was verified as an engine busy-state transition; this does not yet establish
that arbitrary child shell processes or every upstream inference request are terminated.
The trial exercised an SSE connection, not complete event persistence/reconnection.
The small fixture establishes basic compatibility, not complex-feature reliability.

## Reproduction and artifacts

`script/engine-probe.sh` extracts the pinned package under ignored `tmp/`.
`script/engine-trial.py` runs a bounded CLI coding trial.
`script/engine-api-trial.py` starts a temporary localhost server, tests the HTTP contract,
and stops the server afterward. Each API trial creates a fresh disposable Git fixture
and records an independent Git patch alongside the API results.
Download the Linux package first with:

```powershell
npm.cmd pack opencode-linux-x64@1.19.4 --pack-destination tmp
```

Raw local evidence: `tmp/engine-trial/events.jsonl`, `api-answer.json`, `api-report.json`,
`api-server.log`, and the two fixture folders. These are ignored rather than shipped.

## Next experiment

Use explicit read-only worker definitions and separate worktrees to test child sessions,
concurrency limits and one/two-worker timings. Only then connect the engine to persisted
feature runs described in spec 002.
