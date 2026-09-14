# MarkdownEngine snapshot provenance

- Source: `Vendor/swift-markdown-engine` from a local snapshot of https://github.com/oil-oil/NotchNotes.
- Imported: 2026-08-24
- Upstream repository named by the source project: `nodes-app/swift-markdown-engine`
- Source snapshot has no Git commit metadata.
- License in the source snapshot: MIT, Copyright (c) 2026 Luca Chen.
- StarMemo packages only the core `MarkdownEngine` target. The optional code-highlighting and LaTeX adapter targets were not imported because they are outside the approved feature scope and require unrelated network dependencies.
- StarMemo modifications: Swift 6 warning cleanup; host notification hooks for strikethrough, inline-code, and link commands; read-only focus presentation support; GitHub-style `~~strikethrough~~` parsing and styling.
- 2026-08-31: configurable unchecked checkbox fill/stroke and stroke width, preserving upstream defaults.
- 2026-09-07: equatable editor themes; refresh coordinator and native view theme together and restyle existing content on theme changes, preserving selection, scroll position and undo history.
- 2026-09-08: preserve selection and viewport on font-only updates; defer host updates during marked-text composition and notify on unmark; synchronize native undo/redo results back to the document Binding, scoped to the text view's own undo manager.
- 2026-09-14: configurable completed checkbox fill and checkmark colors, retaining the historical mint fill and dark checkmark as engine defaults. StarMemo supplies theme-specific pale fills; checkbox geometry and interaction are unchanged.
