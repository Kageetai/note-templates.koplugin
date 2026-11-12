# Note Templates Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task by task. This document authorizes planning only; wait for an implementation request before writing plugin code.

**Goal:** Quickly insert user-defined literal text templates into KOReader notes, with optional trailing whitespace. Short tags are the primary use case; the plugin assigns no meaning to their contents.

**Architecture:** A small Lua plugin adds a Templates button to KOReader's existing note editor and stores a global ordered tag list in KOReader settings. Reuse KOReader's native menus and dialogs for the template picker and tag management, and `InputDialog:addTextToInput()` for insertion. Keep the original note editor and its save/cancel callbacks.

**Tech stack:** KOReader Lua/LuaJIT, native UI widgets, native settings; no additional dependencies.

**Spec:** The agreed requirements and proposed defaults below form the design for this plan.

## Requirements and proposed defaults

- Support user-defined literal text, including short tags such as `.words`, `.c1`, and `.c2`. These are examples, not special syntax.
- Each tag has a trailing-text setting. Proposed choices: **Nothing**, **Space**, **Newline**, and **Blank line**, represented by `""`, `" "`, `"\n"`, and `"\n\n"`.
- Proposed default: new tags use **Space**. Seed `.words`, `.c1`, and `.c2` on first use only. An intentionally empty list stays empty.
- Insert the tag and its configured suffix at the current cursor position. Preserve existing text and allow repeated insertion.
- Insert literal text without deduplicating tags or adjusting surrounding whitespace. The suffix belongs to each insertion, including at the end of a note.
- Apply to new and existing annotation notes, including notes opened through the bookmarks list. Do not add Templates to unrelated text inputs.
- Manage tags in a **Note templates** main-menu entry: add, edit, delete. Show the literal tag as its picker label; no separate display name.
- Preserve insertion order; editing keeps an entry's position and adding appends. No reorder interface in the first version.
- Template text must be a nonempty string. Allow spaces, punctuation, Unicode, and line breaks; do not enforce tag syntax or require a leading dot. Preserve text exactly without trimming. Use a one-line preview for multiline picker entries, keeping the original insertion text intact.
- Confirm deletion. Canceling an editor or picker changes nothing.

## Selected approach

**Extend the existing note editor:** reuse KOReader's native menus and dialogs for template selection and tag management while preserving its annotation handling. Requires verifying a narrow integration point on the supported release.

## Global constraints

- Minimum supported stable release: **KOReader 2024.07**. Latest stable **2026.07.1** is a required support and runtime-test target, not merely an optional compatibility check.
- No changes to KOReader core files, clipboard contents, or existing note formats.
- Save notes only through KOReader's original Save action. Template insertion changes the unsaved editor contents only.
- Preserve all original note callbacks, annotation notifications, and PDF behavior.
- Persist template data separately from the install directory so plugin updates preserve user settings.
- Validate persisted values before use. Preserve invalid stored data and report the problem; do not silently replace it with defaults.
- Install an integration wrapper at most once; avoid duplicate buttons across books or dialog openings.
- If integration is unsupported, leave normal note editing working and explain the incompatibility without repeatedly interrupting reading.
- No external-service integration or verification. Template contents are opaque literal text; do not interpret or validate them for another application.
- No automatic syncing, placeholders, per-book lists, or keyboard customization.

## Researched integration: KOReader v2026.07.1

The workspace currently contains only IDE metadata: no plugin code, tests, or Git repository.

Research date: 2026-11-12. GitHub's [latest stable release](https://github.com/koreader/koreader/releases/latest) and live GitHub release API both resolve to [v2026.07.1](https://github.com/koreader/koreader/releases/tag/v2026.07.1). Support stable releases from v2024.07 through this latest release. Nightly/OTA builds are separate and are not implied by stable-release support.

- [`ReaderHighlight:editNote()`](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/apps/reader/modules/readerhighlight.lua) routes highlight notes to the bookmark module.
- [`ReaderBookmark:setBookmarkNote()`](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/apps/reader/modules/readerbookmark.lua#L1322) creates and shows a local InputDialog. No dedicated extension callback is exposed there.
- [`InputDialog`](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/ui/widget/inputdialog.lua#L578) accepts button rows and provides `addTextToInput(text)`. Its `addWidget()` also supports extra controls, but constructor-time button insertion avoids rebuilding the input widget.
- [`Widget:new(o)`](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/ui/widget/widget.lua#L36) initializes from the supplied options table. Modify button options before calling the original constructor.
- The bundled [`hello` plugin](https://github.com/koreader/koreader/blob/v2026.07.1/plugins/hello.koplugin/main.lua#L25) demonstrates `self.ui.menu:registerToMainMenu(self)` and `addToMainMenu(menu_items)`. Reuse this registration and native `Menu`, `InputDialog`, `ButtonDialog`, and `ConfirmBox` widgets.

**Implementation decision:** Wrap `self.ui.bookmark.setBookmarkNote` on the current reader instance once. During its synchronous call, temporarily intercept `InputDialog.new` to append a separate Templates button row to the note constructor's options. Capture the resulting dialog for the picker callback. Restore the previous constructor before forwarding to it, and also restore on every exit/error from the outer call. Delegate to the captured original methods; retain their arguments, return values, and errors. Preserve whether `new` originally came from inheritance when restoring it.

This is a source-supported runtime-wrapper design, not a dedicated public plugin API or a completed runtime test. It must consume only the intended constructor once, never match translated titles, and never remain installed globally. Guard the expected options shape; if it does not match, forward unchanged. Native note callbacks remain untouched. Keep a concise why-comment explaining the temporary interception.

Use a native paginated Menu for selection and management, a native text InputDialog for template contents, and a native ButtonDialog for suffix selection. Keep menu previews separate from insertion contents. Hardware layout and wrapper interaction still require runtime checks; device details are useful for those checks but do not block implementation against this release.

### Compatibility findings

| Release(s) inspected | Finding | Support decision |
| --- | --- | --- |
| 2020.01, 2021.01, 2022.01 | Older bookmark editor path; no `setBookmarkNote()` method | Exclude; the planned wrapper does not attach there |
| 2023.01, 2024.04 | `setBookmarkNote()` exists, but InputDialog lacks `addTextToInput()` | Exclude; the planned insertion call is unavailable |
| 2024.07 | Both methods exist; note editor constructs InputDialog synchronously with native button rows | Minimum supported stable release |
| 2024.11, 2025.04, 2025.08, 2025.10, 2026.03, 2026.07, 2026.07.1 | Both methods and synchronous note-dialog construction remain present | Source-compatible targets; latest release is mandatory |

The insertion method was added in [commit 6b192c3, Annotations: Bookmark list improvement](https://github.com/koreader/koreader/commit/6b192c346aeeba94ffbabc1d7fa19d15a5c435ec) on 2024-05-16. The first stable release containing it is [2024.07](https://github.com/koreader/koreader/releases/tag/v2024.07), published 2024-07-15. The preceding stable release, 2024.04, lacks it. Compare the [2024.04 InputDialog](https://github.com/koreader/koreader/blob/v2024.04/frontend/ui/widget/inputdialog.lua) with [2024.07 InputDialog](https://github.com/koreader/koreader/blob/v2024.07/frontend/ui/widget/inputdialog.lua) and its [note editor](https://github.com/koreader/koreader/blob/v2024.07/frontend/apps/reader/modules/readerbookmark.lua).

This floor follows the selected public insertion method, not an assertion that plugins are impossible on older versions. Older releases would require a different editor hook or insertion through private widget fields. Do not add those compatibility paths.

At plugin initialization, check that the reader instance exposes `setBookmarkNote` and InputDialog exposes `addTextToInput`; do not wrap a missing method. Guard constructor options when decorating. For unsupported API shapes, keep native editing usable and show one actionable compatibility message. Avoid a custom version parser; document the release floor and use API checks for safety.

The live source check covered all eight stable release tags listed above from 2024.07 through 2026.07.1. It checked method availability and synchronous constructor use, not execution. Before claiming tested support, run the note workflow on **both 2024.07 and 2026.07.1**, including cursor insertion, Unicode, all suffixes, Save/Cancel, and repeated editor/book openings. Recheck the latest stable tag at implementation time; if it advances, include the new latest release before shipping.

## Planned files

| File | Responsibility |
| --- | --- |
| `_meta.lua` | Plugin identity and description |
| `main.lua` | Plugin lifecycle, main menu, tag dialogs, picker, and note-editor integration |
| `templates.lua` | Small pure module for validation and suffix expansion |
| `tests/templates_test.lua` | Standalone assertions for stored data and insertion strings |
| `tests/integration_test.lua` | Stub-based assertions for wrapper scope, restoration, and delegation |
| `README.md` | Installation, usage, supported version, limitations, and device checks |

Use a single namespaced setting, `note_templates`, with an ordered list of `{ text = ".words", suffix = "space" }` entries. Allowed suffix values are `none`, `space`, `newline`, and `blank_line`. A missing setting means first use; an empty list means the user removed all entries. Do not add IDs, migrations, or a general template engine.

## Review focus

- Integration affects only annotation note editors, including entry through the bookmarks list.
- Cursor insertion preserves Unicode, existing text, and configured trailing newlines.
- Save and Cancel retain native behavior, including cancellation of a newly created annotation.
- Stored settings survive restart, empty lists, and invalid data without destructive resets.
- Reopening books, resizing dialogs, and other editor plugins do not duplicate controls or break editing.

## Task 1: Verify the note-editor integration

**Files:** Create the integration portion of `main.lua` and `tests/integration_test.lua`; record findings in `README.md`.

- [ ] Use v2024.07 as the minimum and v2026.07.1 as the latest required target; recheck the latest stable release before implementation. Apply the integration decision above. Trace callers on both endpoint releases to confirm page-bookmark and bookmark-list coverage. Record the device model when available for hardware checks.
- [ ] Implement the per-reader `setBookmarkNote` wrapper and one-shot constructor interception described above. Append a separate native button row; preserve the original Cancel/Paste/Save row. Do not replace the editor or permanently intercept InputDialog creation.
- [ ] Before implementing the wrapper, add failing assertions in `tests/integration_test.lua` using stub bookmark/constructor objects: original constructor restored after success and an injected error, inherited `new` restored without leaving an override, existing callbacks unchanged, only one decoration, original arguments/results forwarded, and pre-existing constructor wrappers preserved. Also test missing `setBookmarkNote`, missing `addTextToInput`, and unexpected constructor options: no crash or broken native editor. Run `luajit tests/integration_test.lua` before and after implementation; expect failure before and passing assertions after. Record wrapper lifetime and supported releases in README.
- [ ] Verify the chosen approach in the emulator or target device on both minimum and latest stable releases with a temporary button: new note, existing note, bookmarks-list note, and an unrelated text input. Confirm the button is restricted to notes.
- [ ] Reopen a book and reopen the editor twice. Confirm one button per dialog and working Save/Cancel. If no bounded integration works, stop and revise this plan before building a replacement editor.

**Deliverable:** A verified integration approach and documented supported release. No claim of broad version support.

## Task 2: Persist and manage tags

**Files:** Create `_meta.lua`, `templates.lua`, and `tests/templates_test.lua`; extend `main.lua` from Task 1.

**Interfaces:** `templates.validate(entries)` returns `true` or `nil, error_message`; `templates.insertionText(entry)` returns the literal tag plus its validated suffix. `main.lua` owns settings reads/writes and native dialogs.

- [ ] Write failing assertions for all four suffixes, Unicode text, embedded spaces/newlines, empty text, non-string text, unknown suffixes, malformed entries, and an empty list. Assert `.c1` with `space` produces exactly `.c1 ` and `.words` with `blank_line` produces exactly `.words\n\n`. Assert `my text\nnext line` remains unchanged with suffix `none`.
- [ ] Run `luajit tests/templates_test.lua`; confirm it fails because the module is not implemented. Use the target KOReader development environment's LuaJIT if none is installed locally.
- [ ] Implement structural validation and literal suffix expansion in `templates.lua` without a KOReader dependency. Validate types and supported suffix choices, not template syntax. Do not trim or normalize text.
- [ ] Add plugin metadata and native settings/menu registration. Initialize examples only when the namespaced setting is absent. Validate existing data before editing or insertion; never evaluate tag text as code.
- [ ] Implement add/edit dialogs with a literal text field (`allow_newline = true`) and the four suffix choices. Prevent empty-text saves with a clear message; preserve user text exactly. Implement confirmed deletion.
- [ ] Run `luajit tests/templates_test.lua`; expect all assertions to pass, including whitespace preservation.
- [ ] In KOReader, add/edit/delete a tag, cancel an edit, restart, and verify persistence. Remove all tags and restart; verify examples do not return. Supply malformed settings in a disposable profile and verify preservation plus a useful error.

**Deliverable:** A usable global tag manager with persistent suffix choices.

## Task 3: Insert tags into native notes

**Files:** Update `main.lua` and `README.md`; reuse Task 1's verified integration and Task 2's insertion strings.

- [ ] Add one Templates button using the verified integration. Open a native picker showing entries in stored order; selection inserts `templates.insertionText(entry)` through `input_dialog:addTextToInput()` and closes only the picker.
- [ ] If the list is empty or invalid, keep note editing usable and explain how to configure tags. Canceling the picker must preserve text, cursor, and keyboard state.
- [ ] Verify new notes, existing highlight notes, page-bookmark notes, and notes opened through the bookmarks list. Insert at the start, middle, and end of text, including adjacent to Unicode characters. Insert several tags and exercise all four suffixes.
- [ ] Verify that trailing newlines survive native Save and reopening. Test Cancel separately: existing notes retain saved content, and new-note cancellation retains KOReader's original annotation behavior.
- [ ] Verify keyboard focus after picker dismissal, small-screen layout, rotation/dialog recreation, and no duplicate controls after reopening books. Confirm unrelated input dialogs remain unchanged.
- [ ] Test alongside any installed plugin that modifies note editing; document incompatibilities. On an unsupported release, confirm normal editing still works.
- [ ] Document copying this folder to `koreader/plugins/note-templates.koplugin/`, enabling the plugin if required, and restarting KOReader. Include usage, settings location, tested release/device, and integration limitations.
- [ ] Run the assertion suite and syntax checks with the target LuaJIT environment. Execute the note workflow on both 2024.07 and the latest stable release, currently 2026.07.1. Record each release's emulator/device checks as passed, failed, or untested; do not claim tested support from source inspection.

**Deliverable:** Installable plugin with tag insertion, suffix configuration, and documented verification.

## Completion boundary

The plugin is complete when templates and suffixes persist, literal insertion works in new and existing notes, native Save/Cancel behavior is preserved, and the target release/device checks pass. No downstream application behavior needs consideration or verification.

Git initialization, publishing, releases, and automated updates are separate work. No implementation has been performed by creating this plan.
