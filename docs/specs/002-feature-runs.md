# 002 — Feature specifications and bounded coding runs

Status: draft for the next slice; not implemented.
Depends on: spec 001 and the engine compatibility gate.

## User workflow

Inside a project: describe a feature, enter observable acceptance criteria, request
a plan, inspect task assignments, select a maximum worker count, execute, inspect
test evidence and a combined diff, then apply the result to the chosen target branch.
Project scaffolding uses the same run workflow with a selected template and setup checks.

## Data model

- Feature: project, title, description, acceptance criteria, revision.
- Run: feature revision snapshot, plan snapshot, engine/model, starting Git commit,
  worker ceiling, task ceiling, deadlines, status and failure reason.
- Task: run, description, acceptance checks, dependency IDs, assigned paths, status,
  worktree/branch, engine session ID, attempt count and lease expiry.
- Event: run/task, monotonically ordered ID, type, timestamp, redacted payload.
- Artifact: run/task, diff, test/command exit status, bounded output and timestamps.

## State transitions

Run: queued -> planning -> awaiting_review -> running -> integrating -> awaiting_apply -> completed.
Nonterminal states may become cancelling -> cancelled, or failed.
Tasks: queued -> ready -> running -> succeeded / failed / cancelled.
An interrupted running task becomes interrupted; no automatic replay of commands.
A run cannot become completed solely from a model's completion message.
All transition requests use expected current state to reject duplicate/out-of-order updates.

## Scheduler contract

- Model proposes tasks and dependencies as structured data; application validates it.
- Reject missing dependency IDs, cycles, duplicate tasks and over-budget plans.
- Start with max_active_workers=1; allow 2 after the local benchmark. The UI calls
  this maximum active workers; the orchestrator is accounted for separately in the
  shared inference-request semaphore. Do not imply all named agents run simultaneously.
- max_total_tasks=8 and max_task_attempts=2 initially; no recursive unbounded spawning.
- Parent may propose additional tasks within the run budget. Application owns admission.
- Claim ready tasks atomically with a lease; two job workers cannot claim the same task.
- Only schedule a task after its dependencies succeed. Failure blocks dependants visibly.
- Parallel tasks receive distinct worktrees; integration happens in a separate worktree.
- Track time waiting for inference separately from generation and tool execution.

## Engine adapter contract

Health, start session, prompt asynchronously, events since cursor, current state,
cancel, messages, child sessions and diff. Store the engine version with each run.
Rails calls the engine server; browser never receives process handles or provider secrets.
Persist event IDs and status before broadcasting. Refresh reconnects to persisted state.
Each filesystem/tool execution uses that task's explicit working directory.

## Commands and integration

Use configured project commands for install/build/test; capture real exit codes and bounded
stdout/stderr. Worktrees are edit isolation, not a shell sandbox. Define execution scope
before exposing command tools in the app. Separate model proposals from command policy.
Do not initialize Git, overwrite existing files, install dependencies or apply a diff as a
side effect of merely registering a folder. Setup is an explicit project/run operation.
Before applying a result, verify the target commit and file contents still match the
reviewed base. If they changed, stop for reintegration and fresh checks.

## Acceptance tests

1. Feature revisions do not change the requirements of an already-started run.
2. Invalid/cyclic or oversized plans fail validation before worker execution.
3. Scheduler never exceeds configured active-worker and inference-request ceilings.
4. Two claimers cannot execute the same task; dependent tasks wait for success.
5. Overlapping edits remain separate and integration conflicts are surfaced.
6. Stop prevents new tasks, cancels live sessions and records partial artifacts.
7. Restart marks orphaned tasks interrupted; resume is explicit and preserves evidence.
8. A failing test prevents successful completion, even if an agent claims success.
9. Target branch changes after review prevent stale diff application.
10. End-to-end fixture feature produces a reviewed diff and independently passing tests.

## First implementation increment

Persist Feature/Run records and spec revisions; provide feature creation and plan review.
Implement one isolated coding worker before dynamic delegation. Add two-worker execution
only after the gate demonstrates tool reliability, cancellation and measured performance.
