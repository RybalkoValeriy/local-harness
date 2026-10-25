# ADR 001 — Rails project control plane with a replaceable coding engine

Date: 2026-10-25. Status: proposed; engine adoption depends on a local compatibility trial.

## Decision

Keep Rails, SQLite and strict TypeScript for projects, chats, feature specifications,
run/task state, review and scheduling. Evaluate OpenCode's headless HTTP server as
the coding engine. Keep the current read-only LM Studio loop working while evaluating.
Update: ADR 002 adopts RubyLLM for transport and spec 003 adds direct text-file
creation/editing; the OpenCode execution gate remains separate and provisional.
Do not make browser code responsible for starting processes or enforcing worker limits.

## Alternatives

| Approach | Benefit | Cost / limitation |
| --- | --- | --- |
| Extend our entire agent loop | Complete control, Ruby throughout | Must build shell lifecycle, patching, compaction, cancellation and recovery ourselves |
| Rails + OpenCode | Existing tools, sessions, events, diffs, subagents; HTTP works with Ruby | Versioned API integration and local-model reliability still need verification |
| Adopt OpenHands Canvas | Ready-made visual multi-agent/worktree product | Less control of our Rails workflow; additional application/backend stack |
| Open WebUI Computer | General assistant with parallel delegation | Shared machine access; documentation warns against overlapping file edits |
| AutoGen Studio | Team prototyping UI | AutoGen repository currently marks itself archived; avoid a new dependency |

## Project and execution boundaries

Project -> Conversations and Feature specs -> Runs -> Tasks -> Agent sessions/events/artifacts.
Projects store canonical paths. Each worker gets a separate Git worktree once Git is configured.
A worktree separates edits but is not an OS sandbox. Commands require a separate execution policy.
For folders without Git, chat works; implementation will require an explicit Git initialization flow.
Rails owns the task DAG, maximum active workers, total tasks, time limits and stop state.
The model may propose a plan but cannot bypass scheduler limits.
Start with one active worker; enable two only after measurement on this laptop.

## Adoption gate

Pin a released engine version; use a disposable fixture and local-only provider.
Verify health, exact model selection, file reads, edits, command/test status, event capture,
abort, child-session behavior and diffs. Record failures rather than inferring compatibility
from an HTTP 200 or model self-report. Native WSL engine is preferred for Rails commands.

## Sources reviewed

- https://opencode.ai/docs/server/ — HTTP/OpenAPI, sessions, abort, diffs and events.
- https://opencode.ai/docs/providers/ — LM Studio / OpenAI-compatible configuration.
- https://opencode.ai/docs/agents/ — primary agents and task delegation.
- https://opencode.ai/docs/windows-wsl/ — WSL backend and Windows path access.
- https://www.openhands.dev/product/canvas — visual agents and worktrees.
- https://github.com/OpenHands/docs/blob/main/openhands/usage/llms/local-llms.mdx — local LM Studio setup.
- https://docs.openwebui.com/ecosystem/computer/ai/subagents/ — shared access and restart limits.
- https://github.com/microsoft/autogen — current maintenance status.

Documentation is evidence of advertised capabilities, not verification with our Qwen model.

Local trial evidence is recorded in ../engine-trial-results.md. Basic coding and cancellation
work; empty engine diffs and untested delegation keep engine adoption provisional.
