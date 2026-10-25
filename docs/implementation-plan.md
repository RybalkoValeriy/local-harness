# Implementation plan

Work proceeds spec -> acceptance scenarios -> implementation -> checks -> evidence.
Update the spec when requirements change; do not silently redefine success in code.

## 1. Project workspaces (spec 001)

- [x] Architecture investigation and decision record.
- [x] Create an empty project / register an existing directory.
- [x] Windows-to-WSL path normalization and canonical duplicate checks.
- [x] Per-project conversations and tool instances; legacy chat migration.
- [x] Project list/switcher, path display, missing-path errors.
- [x] Automated acceptance checks: strict TypeScript build, Rails tests/eager loading, RuboCop.
- [x] Real Chrome smoke check: project list, existing chat, mobile navigation, invalid-path error, no JavaScript errors.

## 2. Coding engine compatibility gate

- [x] Pin OpenCode 1.19.4 and execute its native Linux binary in WSL.
- [x] Qwen3.5-9B reads/edits a disposable Ruby fixture and executes its checks.
- [x] Independently verify the resulting Ruby file passes both checks.
- [x] Verify server health, persisted sessions, SSE connection and cancellation of a busy request.
- [x] Verify actual file changes and independent Ruby checks through the HTTP API (57.37 seconds).
- [ ] Engine diff endpoint returned an empty list despite a real Git diff; use independently collected Git artifacts and investigate before adoption.
- [ ] Verify child sessions and measure one versus two concurrent workers.
- [ ] Decide adoption from results; no production engine switch until this gate passes.

## 3. Feature specifications and one coding worker

- [x] Draft Feature/Run/Task/Event state machines and acceptance checks (spec 002).
- [ ] Add feature description and acceptance-criteria UI per project.
- [ ] Add plan generation with task dependencies and explicit execution limits.
- [ ] Git readiness check and isolated worktree per worker.
- [ ] Background execution, stop, captured exit status and final diff review.

## 4. Bounded multi-agent orchestration

- [ ] Enforce maximum workers and total tasks in application code.
- [ ] Schedule independent tasks; persist dependencies, artifacts and failures.
- [ ] Integrate branches in a separate worktree; surface conflicts and rerun checks.
- [ ] Recover interrupted runs after restart; add repeatable model evaluations.

Future work is tracked here, not represented as implemented functionality.

## 5. RubyLLM and direct project file tools (spec 003)

- [x] Install RubyLLM 2.1.1 and adapt the existing model boundary without replacing conversation storage.
- [x] Preserve local endpoint, sampling, streaming, history and application-owned tool limits.
- [x] Create new text files and perform exact unique replacements within the selected project.
- [x] Reject overwrite, traversal, symlink/hardlink writes, secret paths and invalid content.
- [x] Actual RubyLLM HTTP/SSE tests and local Qwen read/tool-response trial.
- [x] Complete live create/read/edit trial; independently verify disk changes and tool results.

## 6. Project files and IDE viewer

- [x] Project-scoped lazy file tree with manual and automatic disk synchronization.
- [x] Persistent highlighted file tabs, line numbers and chat visible together.
- [x] Preview errors/truncation and directory/file boundary checks.
- [x] Browser verification of switching/closing tabs, live updates and mobile layout.

## 7. Efficient context and archives (spec 004, proposed)

- [ ] Content-hash cache with edit/delete invalidation and lexical retrieval.
- [ ] Evaluate optional local embeddings and project-scoped hybrid retrieval.
- [ ] Bounded context assembly with citations and preserved original messages.
- [ ] Reversible conversation archives and searchable summaries.
