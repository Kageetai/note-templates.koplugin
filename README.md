# Note templates for KOReader

Insert literal text into annotation notes using KOReader's existing note editor. Templates are global and ordered. Each insertion adds the template exactly as written, followed by its configured trailing text:

| Choice | Added text |
| --- | --- |
| Nothing | Nothing |
| Space | One space |
| Newline | `\n` |
| Blank line | `\n\n` |

## Install

Copy this folder to `koreader/plugins/note-templates.koplugin/` so `_meta.lua`, `main.lua`, and `templates.lua` are directly inside that directory. Enable **Note templates** in KOReader's plugin management menu if required, then restart KOReader. No dependencies or core-file changes are needed.

The minimum targeted stable release is **2024.07**. The latest required target is **2026.07.1**, rechecked through GitHub's release API on 2026-11-12. Earlier releases lack the required editor or insertion API. These are source-inspected targets; device support has not yet been verified.

## Use

Open an annotation's **Add note** or **Edit note** dialog, including from the bookmarks list. Place the cursor and tap **Templates**, then choose an entry. Repeat to insert more. Use KOReader's original **Save** or **Cancel** action afterward. Choosing a template never saves the note.

The keyboard is hidden while the picker is open. Selecting a template or dismissing the picker restores it only if it was previously visible. This uses KOReader's native keyboard methods, which [KOboard also hooks](https://github.com/titandrive/koboard/blob/main/koboard.koplugin/main.lua) for Android's system keyboard. KOboard device testing remains pending.

Open **Tools → Note templates**, using KOReader's default menu sorting. Selecting a template opens its editor directly; **Delete** is available beside Cancel and Save and requires confirmation. New templates default to **Space**; tap **Trailing text** in the template editor to change it. Editing keeps the template's position; adding appends. Canceling the text editor discards both text and suffix changes. Dismissing the suffix chooser keeps the previous choice.

The first start seeds `.words`, `.c1`, and `.c2`, each with a trailing space. Their contents have no special meaning. Emptying the list keeps it empty across restarts.

Template text must contain at least one character. Spaces, punctuation, Unicode, and line breaks are accepted without trimming. Multiline entries use a one-line `↵` preview in menus; insertion preserves their original contents. No deduplication or surrounding-whitespace adjustment occurs, including at the end of a note.

## Settings and compatibility

The `note_templates` key in KOReader's global `settings.reader.lua` stores an ordered list:

```lua
["note_templates"] = {
    { text = ".words", suffix = "space" },
    { text = "my text\nnext line", suffix = "none" },
},
```

Suffix values are `none`, `space`, `newline`, and `blank_line`. Settings live in KOReader's user data directory, outside this plugin folder, and follow KOReader's normal settings-save lifecycle. Updating the plugin preserves them. Invalid data is preserved and blocks template management/insertion with an explanatory message. To repair it, close KOReader, back up `settings.reader.lua`, then correct the key. Explicitly removing the key seeds examples on the next start; an empty table does not.

The plugin wraps `setBookmarkNote` once per reader instance. During its synchronous execution, it intercepts only the first `InputDialog` constructor, checks the native note-editor option shape, and appends a separate button row. The constructor is restored **before** delegation, including inherited constructors and existing wrappers, and restored again on success or error. Native Cancel/Paste/Save callbacks remain unchanged; PDF writes and annotation notifications remain KOReader's responsibility.

There is no public note-editor extension hook. An incompatible API or constructor shape leaves native editing available and reports compatibility trouble once per application session. Other note-editor plugins may conflict with this private integration; no combinations have been runtime-tested. Unrelated input dialogs are not decorated. No clipboard, note-format, sync, placeholder, per-book, keyboard-shortcut, or external-service features are included.

## Releases

Merging PRs into `main` updates an unpublished GitHub release draft through Release Drafter. Use conventional PR titles: `fix: ...` suggests a patch version, `feat: ...` suggests a minor version, and `feat!: ...` or `fix(scope)!: ...` marks a breaking change. The largest bump across merged PRs wins. Other changes default to a patch bump. Use the PR title as the squash commit message to keep Git history consistent.

Before 1.0, breaking changes also suggest a minor bump. When publishing 1.0.0, change the breaking-change category in `.github/release-drafter.yml` to `semver-increment: major` for subsequent releases. Version numbers live in release tags; this workflow does not edit plugin settings or `_meta.lua`.

Review the draft, then publish it manually. The **Releases** workflow checks the published tag, runs the standalone Lua tests and syntax checks, and attaches `note-templates-vX.Y.Z.zip`. The archive contains `_meta.lua`, `main.lua`, `templates.lua`, and this README inside `note-templates.koplugin/`. Tests, plans, and automation files are excluded. Packaging accepts stable tags such as `v0.1.1`; prerelease packaging is not configured. Wait for the workflow to finish before downloading the ZIP. If it fails, fix the cause and rerun the failed job from GitHub Actions.

The workflow's manual **Run workflow** action on `main` refreshes the draft without publishing. GitHub's built-in token handles drafting and uploads; no additional secret is required.

## Verification

Run from this directory using LuaJIT:

```sh
luajit tests/templates_test.lua
luajit tests/integration_test.lua
luajit tests/manager_test.lua
luajit tests/picker_test.lua
for file in _meta.lua main.lua templates.lua tests/*.lua; do
    luajit -b "$file" /dev/null || exit 1
done
git diff --check
```

Automated assertions cover literal suffixes, malformed and empty settings, first-use seeding, staged edits, suffix-button width and labels after dialog reconstruction, confirmed deletion, ordered previews, picker cancellation, repeated insertion, wrapper scope/restoration, original arguments/results/errors, and preservation of existing constructor wrappers and callbacks.

`tests/upstream_test.lua` also executes the actual `setBookmarkNote` function from either tagged `readerbookmark.lua` with stubbed UI widgets. Supply a local source file:

```sh
luajit tests/upstream_test.lua /path/to/readerbookmark.lua
```

This verifies native Save/Cancel delegation, new-note cancellation, bookmark-list handling, and the latest release's PDF callback. It is **not** an emulator or device test. Sources inspected: [2024.07 bookmark module](https://github.com/koreader/koreader/blob/v2024.07/frontend/apps/reader/modules/readerbookmark.lua), [2026.07.1 bookmark module](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/apps/reader/modules/readerbookmark.lua), and the corresponding highlight and InputDialog modules. Both highlight-note and bookmark-detail actions route through `setBookmarkNote`, including page bookmarks.

| Check | 2024.07 | 2026.07.1 |
| --- | --- | --- |
| Source inspection: callers, synchronous construction, insertion API | Passed | Passed |
| Tagged native note method with stub UI | Passed | Passed |
| Emulator/device note workflow | **Untested** | **Untested** |
| Device model | Unavailable | Unavailable |

No KOReader emulator, target device, or container runtime was available in the implementation environment. Before treating the plan's completion boundary as met, run these checks on **both** releases:

- New and existing highlight notes, page-bookmark notes, and notes through the bookmarks list; unrelated inputs have no Templates button.
- Insert at the start, middle, and end beside Unicode text; repeat inserts and exercise all four suffixes. Save, reopen, and confirm trailing newlines survive.
- Cancel existing-note edits and new notes; confirm KOReader's original annotation behavior.
- Add/edit/delete, cancel an edit, restart, and check persistence. Remove all entries and restart. Test invalid settings in a disposable profile without replacing them.
- Reopen editors and books; check one Templates button, focus/keyboard state after selection and dismissal, small screens, rotation, and dialog recreation.
- Test installed note-editor plugins and an unsupported API/release; confirm native editing remains usable and compatibility warnings do not repeat.
