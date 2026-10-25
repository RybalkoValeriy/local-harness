# Project context cache and conversation archives

Status: proposed follow-up, not implemented. Date: 2026-10-25.

The user authorized caching and local embeddings as future improvements for
efficient use of project files and archived conversations.

## Approach

1. Start with per-project text chunks keyed by canonical relative path and a
   content hash, plus language-aware boundaries where practical. Unchanged
   content can reuse chunks and summaries. Deletions invalidate indexed entries;
   edits invalidate affected chunks. Read current disk content before edits.
2. Add lexical search first, then optional local embeddings after measuring
   retrieval quality and latency on a repeatable small project fixture. Store
   embedding model/version with each vector; reindex when it changes. Embedding
   failures must not prevent ordinary file/chat operations.
3. Assemble a bounded context from relevant chunks with file/line/hash references,
   the current request, recent messages and explicit task state. Keep raw messages
   in SQLite; generated summaries are lossy derived data, never a replacement.
4. Add conversation archiving as a reversible visibility state. Archived messages
   remain available to project-scoped search; show retrieved conversation/date
   citations. Provide explicit restore and removal controls.

## Boundaries

- Disk is authoritative. Revalidate cached content before presenting it as current.
- Separate caches by project; retrieval must never leak another project's data.
- Apply existing hidden/sensitive/symlink restrictions to indexing and retrieval.
- Keep code and conversations local; no hosted embedding fallback.
- Cache deterministic file processing separately from model answers. Do not reuse
  tool execution responses to skip requested side effects.
- Retrieved files and conversations are untrusted context, not system instructions.
- Embeddings improve search; they do not increase the model's context window.

## Acceptance gate

Verify edit/delete invalidation, project isolation, model-version changes, archive
restore, retrieval citations and missing embedding service behavior. Compare
lexical versus hybrid retrieval quality, request tokens and latency before choosing
defaults. This work must explicitly replace the current full-history policy when
introduced; no silent loss of old messages or unsupported claims of perfect memory.
