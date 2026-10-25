# ADR 002: RubyLLM for local model transport

Date: 2026-10-25. Status: accepted for the project chat adapter.

Use ruby_llm 2.1.1 behind LmStudio#complete. Configure a per-request context with
the explicit LM Studio base URL and selected model. Force Chat Completions and
system-role compatibility; disable retries and do not configure hosted fallbacks.
Pass existing function schemas through provider options and use Chat#generate
for one model step. RubyLLM parses streamed text, thinking and fragmented calls.

Keep AgentRunner as the application-owned loop. It validates tool arguments,
executes project-scoped tools and persists results. The user subsequently requested
unlimited steps/tool calls with context size enforced by LM Studio (spec 003).
Do not use RubyLLM's automatic completion/tool loop, which would bypass these
existing controls. Existing Message and Conversation tables need no migration.
Model discovery remains a small explicit GET /models request.

This decision does not adopt a coding engine, multi-agent scheduler or RubyLLM's
ActiveRecord chat schema. ADR 001's OpenCode experiment remains provisional.
Direct create/edit tools are a small capability described separately in spec 003;
they do not supply command execution, background jobs or worktree isolation.

Validation: real HTTP fixture tests for stream fragments, thinking, tool history,
sampling settings, truncation and provider errors; live Qwen read/tool-result run.
Live create/read/edit also passed with independently verified file contents.

References:
- https://rubyllm.com/custom-endpoints/
- https://rubyllm.com/agentic-workflows/
- https://rubyllm.com/connection/
