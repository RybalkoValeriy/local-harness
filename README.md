# Local Harness

A local agent harness built with Rails 8.1, Hotwire, SQLite, and LM Studio. Default model: `qwen/qwen3.5-9b`.

## Start

Keep LM Studio running, then run in PowerShell from this folder:

```powershell
.\start.ps1
```

Open **http://localhost:3000**. The script uses Ubuntu-26.04 and the existing rbenv Ruby. It prepares SQLite and discovers the Windows host address for LM Studio. Stop with Ctrl+C. This is a local development app with no user accounts; keep it bound to localhost.

From WSL, run `bash bin/start-wsl` in the project folder.

## Zed and Ruby LSP

Ruby is installed in Ubuntu-26.04, so open this project using Zed's WSL backend:

```powershell
.\open-zed-wsl.ps1
```

Use the Zed window labeled **Ubuntu-26.04**. Opening the ordinary `C:\...` folder
as a Windows project makes Zed search for Windows Ruby instead. Ruby LSP and its
Rails add-on are development dependencies; `.zed/settings.json` selects Ruby LSP
without starting unrelated Ruby servers. The initial WSL setup is reproducible with
`bash script/setup-editor-wsl.sh`; it installs the bundle and exposes rbenv shims
to login shells, preserving a backup of the previous login profile.

## Project workspaces

The homepage lists projects. **Open existing folder** registers an absolute Windows
drive path or Linux path without changing its contents. **Create project** creates
one empty directory under an existing parent. Project folders are never overwritten.
Each project has its own conversations and file tools. Existing chats are
preserved under **Legacy workspace**; old conversation links redirect to their project.
The registered path is interpreted by the WSL backend, so Windows paths are converted
to `/mnt/c/...`. A missing project folder produces an error rather than changing the workspace.

Use **Browse folders…** in either form to choose a directory. The dialog includes Windows
drive, Linux home, and project-location shortcuts; use **Parent** to navigate upward,
**Go** to open an entered path, then **Select this folder**. For a new project, select its
existing parent directory and enter the new folder name. You can still paste absolute
paths; quoted Windows paths and `~/` are supported. Failed forms preserve their input.

The **Theme** selector at the top offers **Light**, **Dark**, and **System**. The browser
remembers the choice; System follows OS theme changes automatically.

The project chat shows an expandable **Project files** tree, including empty folders.
It refreshes after create/edit tool results; **Refresh files** picks up changes made
outside the app. The tree also polls disk every three seconds while the page is
visible. Click a file to open a persistent editor tab beside the agent chat, with
line numbers and basic syntax highlighting
for Ruby/ERB, JS/TS, HTML, CSS, JSON, YAML, Markdown, shell and SQL. The open file
refreshes from disk too; switch between tabs or close them with ×. The code viewer
is read-only; ask the agent to make file changes. Deleted/unavailable files show an error instead of stale
contents. Previews are limited to 16,000 bytes with a visible truncation notice.
Open folders remain expanded when refreshed. On smaller screens
the collapsible tree sits above the chat. Hidden, secret, dependency and runtime
paths are omitted; symlinks are not followed. Each folder lists up to 500 entries.

Development follows [spec 001](docs/specs/001-project-workspaces.md), the
[architecture decision](docs/adr/001-agent-engine.md), and the
[implementation plan](docs/implementation-plan.md). The OpenCode trial is experimental;
the app uses RubyLLM with LM Studio for chat and project file changes. Multi-agent execution is upcoming.
See the [engine trial results](docs/engine-trial-results.md) for observed capabilities and limitations.
The next slice is described in [feature-run spec 002](docs/specs/002-feature-runs.md).

## TypeScript frontend

The Hotwire/Stimulus frontend uses strict TypeScript. Rails and the agent backend remain Ruby.
Install frontend dependencies once with `npm.cmd ci` in PowerShell (or `bash bin/build-frontend ci` in WSL).
Startup compiles the frontend automatically. After editing TypeScript, run `npm.cmd run build`,
or keep `npm.cmd run watch` running in another terminal and refresh the page.
Run `npm.cmd run typecheck` for static checks; watch mode only compiles.
Compiled JavaScript is generated in `app/assets/builds/` and served through the existing import map.
Build before Rails asset precompilation for deployment.

## Features

- Streamed answers and collapsible thinking.
- Saved conversations, tool requests, results, and errors in SQLite.
- A real tool loop: the model requests `list_files`, `read_file`, `create_file` or `edit_file`; Rails executes it within the selected project and returns the result.
- No harness step or tool-call limit. Complete successful history and tool results are sent to the model without a cumulative byte budget; LM Studio enforces its configured context window. Failed/incomplete turns are excluded from subsequent history. Context compaction is not implemented, so start a new conversation when context fills.
- Connection status and visible tool activity.
- Coding sampling: temperature 0.6, top-p 0.95, top-k 20, min-p 0, presence penalty 0. Output capped at 4,096 tokens per model step.

## Workspace

Put files you want the model to inspect in `workspace/`. Try: **Read README.md and review example.rb.**

Tools read, create and edit ordinary text files in the selected project folder. Creation never overwrites; editing replaces one exact unique text match after reading the file. New parent folders are created as needed. Hidden paths, common secret filenames, and paths escaping the workspace are rejected. Writes reject symlinks and dependency/runtime folders. Files and writes are capped at 16,000 bytes. Changes are written directly and their results appear in the chat's tool details. There are no delete or shell tools, so the agent cannot run tests or install packages.

Try: **Create hello.rb containing `puts "Hello local"`.** Then: **Read hello.rb and change the greeting to Hello RubyLLM.**

RubyLLM 2.1 handles model HTTP streaming and tool-call parsing. Our `LmStudio` adapter
preserves existing chats and UI events; Rails retains project-scoped tool execution.
The adapter uses the configured local endpoint with no hosted fallback or automatic retries.
See [spec 003](docs/specs/003-local-tools-and-rubyllm.md) for boundaries and acceptance checks.

## Configuration

Set these inside WSL before starting when needed:

```bash
export LM_STUDIO_MODEL=qwen/qwen3.5-9b
export AGENT_WORKSPACE=/path/to/a/project
bash bin/start-wsl
```

The startup script detects the Windows host address from WSL automatically. If you need to set `LM_STUDIO_URL` manually, use the current Windows host address reachable from WSL; do not reuse an address from another network. `LM_STUDIO_API_KEY` is optional for authenticated servers. `PORT` defaults to 3000. Don't commit secrets. No hosted AI service is used.

## Checks

```bash
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
bin/rails test
bin/rails zeitwerk:check
bin/rubocop
# Live model check; discovers the Windows host and creates a saved conversation:
bash script/live-check.sh script/smoke.rb
# Live create/read/edit trial in a temporary project (cleans up afterwards):
bash script/live-check.sh script/live-file-check.rb
```

## Code map

- `app/services/lm_studio.rb`: RubyLLM adapter and local model discovery.
- `app/services/agent_runner.rb`: agent loop and complete successful history.
- `app/services/workspace_tools.rb`: project-scoped read, create and exact-text edit tools.
- `app/controllers/conversations_controller.rb`: pages and streamed runs.
- `app/javascript/controllers/chat_controller.ts`: typed Stimulus chat UI.

Possible next steps: approvals for proposed file edits, cancellation, richer code rendering, and a small coding evaluation suite.
