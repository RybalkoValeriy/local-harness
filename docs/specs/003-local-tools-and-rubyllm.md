# RubyLLM and project file changes

Status: implemented. Date: 2026-10-25.

Use RubyLLM 2.1 for inference transport behind LmStudio's existing interface.
Keep Rails messages and events. At the user's request, model steps and tool calls
are unlimited; pass complete successful history and tool results without cumulative
byte budgets, relying on LM Studio's configured context window. No automatic
compaction is implemented. Per-file, prompt, output and transport limits remain. Use the
configured LM Studio endpoint exclusively, with no fallback or automatic retries.
Preserve local sampling settings, streamed thinking, text and tool-call history.

Project conversations may create ordinary UTF-8 text files and edit existing
files using one exact, unique text replacement. Creation refuses existing files;
editing refuses absent/ambiguous matches and files larger than 16,000 bytes.
Results describe actual writes and remain visible in persisted tool messages.
New nested directories are allowed. No delete, shell or package installation tool.

Accept only relative slash-separated paths inside the canonical project root.
Reject traversal, hidden paths, symlinks, sensitive names, dependency/runtime
directories and unsupported file types. Reject binary/invalid UTF-8/oversize
content. Preserve existing permissions and replace edited files atomically.
These checks are application boundaries, not an OS sandbox against another
process maliciously changing parent directories concurrently.

Acceptance: real RubyLLM HTTP streaming tests; persisted tool history replay;
truncation/error handling; create+edit verification on disk; refusal of overwrite,
ambiguous edits, traversal, symlink/hardlink escapes and unsupported content;
cross-project write isolation; live local-model read/write/edit trial when available.

Validation: 23 Rails tests / 143 assertions passed; strict TypeScript build,
Zeitwerk loading and RuboCop passed. Live Qwen via RubyLLM created hello.rb,
read it, and changed the greeting through edit_file; independently checked
disk contents, Ruby syntax using Ripper, and persisted tool names/results.
The repeated live trial passed too. The temporary project and
conversation were rolled back and its temporary folder removed afterwards.
Restarted the running app; project page exposes file tools and /connection
reports the selected Qwen model connected.

Follow-up requirements: unlimited model steps/tool calls with full successful
history (no harness byte budget), and a per-project expandable file tree with
automatic refresh on file-tool results and manual refresh for external changes.
The tree includes empty folders, omits hidden/sensitive/dependency/runtime paths,
rejects symlink/traversal escapes and caps each directory listing at 500 entries.
Existing per-file/prompt/output sizes and request timeouts still apply. Context
overflow is handled by LM Studio; the harness does not compact automatically.

Follow-up validation: 26 tests / 161 assertions passed, including 15 model steps,
14 tool calls, complete history above the former byte budgets and directory escape
checks. Browser checks passed for nested/empty folders, automatic event refresh,
manual refresh, preserved expanded folders, mobile collapse and no JavaScript errors.

File viewer follow-up: selecting a file opens a persistent read-only editor tab showing current
disk contents with highlight.js syntax highlighting and an explicit truncation
notice above 16,000 bytes. Unsupported/binary/hidden/sensitive/symlink paths are
rejected using the project's existing file boundaries. Both directory listings
and an open preview poll every three seconds while the page is visible, in
addition to immediate refresh after agent file events. Unchanged listings are
kept in place to preserve focus/expansion. Deleted files clear stale preview text
and display an error. File contents are inserted as text before highlighting.

The popup was replaced at the user's request by an IDE workspace: file explorer,
central editor with switchable/closable tabs and line numbers, and agent chat.
Opening an existing tab selects it without duplication. Closing the active tab
selects an adjacent tab; closing the last tab restores an empty editor. Tab buttons
support arrow/Home/End keyboard navigation. The code view and chat remain usable
together. Narrow screens stack these areas.

Final viewer validation: 27 Rails tests / 184 assertions passed. The browser trial
verified tab switching/closing/deduplication, keyboard navigation, syntax spans,
live file/tree polling, deleted-file errors, escaped script-like content, usable
chat alongside the editor, dark mode and desktop/tablet/mobile widths. Fixture
files were removed after the checks. Strict TypeScript compilation passed.
