# 001 — Project workspaces and local agents

Status: first vertical slice implemented; automated acceptance checks passed. Owner: Local Harness.

## Outcome

A user creates a project folder or registers an existing folder, opens its own
chat, and asks a local agent about that project's files. Future feature runs plan,
implement, test, and integrate changes with a user-configured worker ceiling.

## Requirements

- P1: Create an empty project under a selected existing parent directory. Never overwrite an existing path.
- P2: Register an existing directory without moving or changing its contents.
- P3: Store canonical WSL paths; accept absolute Linux paths and Windows drive paths converted to /mnt/<drive>/.
- P4: Each conversation belongs to a project. Requests cannot select another project's conversation.
- P5: Tool roots come from the conversation's project, never a per-request global environment change.
- P6: Existing conversations are retained under a Legacy workspace project.
- P7: Show the project name/path, project list, project conversations, and validation errors in the UI.
- P8: Validate directory existence, absolute paths, duplicate canonical paths, and single-segment folder names.
- P9: If a project becomes unavailable, show an actionable error; never silently use another folder.

## Acceptance scenarios

1. Create AAA in a temporary parent: exactly parent/AAA is created and opened.
2. Open an existing repository: no file in it is modified by registration.
3. Register the same canonical directory twice: the second registration is rejected.
4. Create a folder that already exists: reject without modifying it.
5. Chat in AAA with a fake model: read_file returns AAA's file, not BBB's file.
6. Request a BBB conversation through an AAA URL: return 404.
7. Migrate saved conversations: all messages and conversation IDs remain available.
8. Remove/rename a registered folder: page still loads with a clear unavailable-path message.
9. TypeScript build, Rails tests, eager loading, and Ruby formatting pass.

## Deliberate first-slice boundaries

Project creation creates an empty directory; framework scaffolding is a later task.
The original slice shipped read-only chat. Spec 003 now adds direct project-scoped
text creation and editing at the user's request. Shell execution and implementation
runs still depend on the coding-engine compatibility gate and spec 002.
The folder browser navigates directories through the WSL backend, with Windows-drive
and Linux-home shortcuts. It selects an absolute server path; it does not upload files.
Users can also enter a path, including quoted Windows paths or ~/ paths.
No arbitrary shell execution, background team execution, or automatic integration is enabled yet.

## Following slices

- Engine gate: pinned OpenCode, exact Qwen model, file read/edit/test, cancellation,
  child sessions, events, diff, and recorded results. Confirm API shapes from installed version.
- Feature specs: description, acceptance criteria, approved plan and persisted runs/tasks/events.
- Single worker: separate worktree, bounded command execution, test evidence, reviewable diff.
- Parallel workers: persisted dependency graph, application-enforced concurrency and total-task
  limits, file ownership, integration workspace and conflict reporting.
- Recovery/evaluation: restart recovery, reproducible tasks and one-versus-two-worker measurements.

## Definition of done for future agent runs

An agent's prose is not proof. Completion requires saved artifacts, tool exit statuses,
acceptance-check results, and an inspectable diff. Failed or unverified work stays visibly incomplete.

## Verification evidence

2026-10-25: 14 Rails tests, 76 assertions, no failures/errors. Strict TypeScript build,
Rails eager loading, and RuboCop (42 Ruby files) pass. A real Chrome smoke check covered
desktop project listing, an existing chat, mobile navigation, invalid paths, and no
JavaScript errors. Desktop/mobile screenshots are saved under ignored tmp/.

Folder-browser/theme follow-up: 16 Rails tests / 93 assertions pass, TypeScript builds,
Rails eager loading passes, and RuboCop reports no offenses in 46 Ruby files. Chrome
verified folder selection, actual existing-folder registration, child-folder creation,
Light/Dark/System switching, saved theme selection, and mobile layout. Only the
temporary browser-check project records were removed afterward.
