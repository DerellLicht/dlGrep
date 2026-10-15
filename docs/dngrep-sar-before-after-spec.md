# dnGrep: Replacement Log in the Results Pane — Design Spec (Draft 6)

Status: draft for Derell's review. Based on dnGrep source at commit `33c514d` (Oct 12, 2026), the HisGrepship screenshots, a HisGrepship saved report (Oct 14), a dnGrep text "Report" sample (Oct 14), and Derell's hands-on testing. Nothing has been built yet.

Claims marked **[verified]** come from reading the source. **[user-observed]** means Derell saw it when testing. **[unverified]** means it needs a build and a runtime check.

Changes from Draft 5: added R7 (saving the log, with a colored HTML option for the log only). The optional first line in R2 is replaced by reusing the existing Report header block. `.md` and SVG output are dropped; HTML for ordinary search results is deferred.

Changes from Draft 4: R2 records the HisGrepship report as the reference for the target output (path line, then old/new line pairs with the matched text highlighted). The header and footer in that sample came from the report save and are not requirements.

Changes from Draft 3: the log is built live, as decisions are made in the Replace window, so all work is visible. OK writes the files and leaves the log in place. Cancel, or any other way of closing the window, clears the log and leaves the pane blank until the next search.

Carried over: the Replace window is left alone (no preview changes, no confirm pane, no Skip button); no diffing against backups; "Replace in all files" is remapped to replace the rest.

## 1. Goal

After a replace, the results pane shows a record of what was done, in the same style as a normal search: a path and filename header for each file, then each affected line as it was and as it became. This is what HisGrepship's results window gave Derell and what dnGrep lacks. Today the pane is blank after pressing OK **[user-observed; matches the code]**. The record can then be saved to a file (R7), as HisGrepship allowed.

## 2. Decisions so far

- The Replace window stays as it is. Its cursor already follows the user from match to match.
- Derell uses two workflows: replace everything at once (usual for plain text), or confirm the first one or two matches and then say "do the rest" (usual for regex).
- Previous, Previous file, and Replace in file stay in the dialog and are simply ignored.
- "Replace in selected files" (Replace menu; works on the files highlighted in the results tree, no dialog) is not redefined. It gets the log through the shared code path (R1).
- No backup diffing. The log comes from the user's decisions, built live.
- Derell wants to see all work as it happens, because the matches in the Replace window's preview scroll off-screen quickly.
- The results pane is cleared when the next normal search starts.
- Highlight colors come from the colors the Replace window's preview already uses, which are theme-settable. The separate ThemeEditor application is not part of this work.
- Saving the log reuses Search → More → Save results. An HTML option is added for the log; `.md`, SVG and RTF are not wanted. HTML for ordinary search results is deferred.
- Undo after saving is not a case worth designing for: Undo clears the log, and nothing is kept for saving afterward.

## 3. Current behavior relevant to this work

**[verified]** unless noted.

- Dialog route: `MainViewModel.Replace()` opens the modal `ReplaceWindow`; on OK it calls `ExecuteReplace(replaceList, true)`.
- Selected-files route: `ReplaceSelectedFiles()` marks all matches in the selected files, then calls `ExecuteReplace(replaceList, false)`. Unselected results stay in the pane today.
- `ExecuteReplace` builds a `ReplaceDef` per file that is not a read-only file type, not already in `undoList`, and has at least one marked match; clears the results (all, or just the replaced files); and starts the background replace.
- Per-match state is one flag, `GrepMatch.ReplaceMatch`. Replace marks and advances; Next advances without marking; Undo clears the mark. "Replace in file" marks all matches in the current file and moves to the next file. "Replace in all files" marks every match in every file, including earlier skips, and closes with OK.
- `GrepCore.Replace` per file: copy to the undo folder, delete the original, write the replacement. On failure it restores that file, stops, and returns -1. Files finished earlier stay replaced. On the failure/cancel path the code does not turn Undo on **[unverified at runtime]**.
- The restore after a failure swallows its own errors (see section 9).
- Regex search type: the replacement text expands capture references (`$1`, `${1}`), tested in `Tests/GrepCoreTest.cs`. Text search type: literal. Also supported in the Replace box: `\\n`, `\\t`, `\\r` for newline, tab, carriage return, and `$(guid)` / `$(guidx)` tokens.
- The results tree has per-file header rows and per-match line rows, with context lines (`IsContext`) as a distinct kind of row. `FormattedGrepResult` and `FormattedGrepLine` do not know the replacement text.
- Search → More → Save results offers "Report", "csv" and "text" **[user-observed]**. The "Report" output is plain text: a header block (search term, search type, case option, folder, file patterns, binary/archive/symlink options, totals line), then for each file its path, a line "has N matches on M lines:", and the match lines with their context lines as `NN: text`, with blank lines between groups **[user-observed, from a saved sample]**. Matches are not marked apart from their context lines in that file. How the menu and the writers are implemented is **[unverified]**.

## 4. Requirements

### R1. Live log while the Replace window is open

- The log is built as the user works in the Replace window, so every decision is visible in the main results pane.
- The first log entry clears the search results in the pane. If the window is closed before any entry exists, the search results stay as they were.
- One entry per match, created or updated whenever its state is decided:
  - Replace gives a "replaced" entry.
  - Next without marking gives a "replacement skipped" entry.
  - Undo flips the entry to "skipped".
  - The bulk buttons (Replace in file, Replace the rest) add or update entries for every match they mark.
  - File headers appear as the user reaches each file.
- **OK:** the marked matches are written to disk (`ExecuteReplace`) and the log stays in the pane.
- **Cancel, Escape, closing the window, or anything other than OK:** nothing is written, the log is cleared, and the pane stays blank until the next search.
- **Selected-files route (no dialog):** the same entries are built in bulk at the start of `ExecuteReplace`.

### R2. Log content and format

**Reference output (HisGrepship saved report, Oct 14).** The target look, per file:

```
D:\...\gdi_plus.cpp                                   <- path header (orange in HisGrepship)
173<tab>bool gdi_plus::build_pargb(void)              <- original line, matched text blue+bold
173<tab>bool gdi_plus::build_pre_argb(void)           <- new line, replacement text green+bold
175<tab>   if (ppargb != nullptr) {
175<tab>   if (ppre_argb != nullptr) {
```

Points taken from it:
- Every changed line appears as a pair: the line as it was, immediately followed by the line as it became. Both carry the same line number.
- Line number, then a tab, then the line text with its original leading whitespace kept.
- The matched text is highlighted in the original line (blue, bold in HisGrepship) and the replacement text in the new line (green, bold). Surrounding text is plain.
- Matches are shown in file order, grouped under the file's path header; files are listed in search order.
- The header line (search term and options) and footer line (match, file and substitution counts) in that sample were added by the report save and are not required in the results pane.
- Colors come from the Replace window's preview, which are settable through themes **[unverified which brushes; Phase 0]**. The old-versus-new distinction is what matters.

Remaining content rules:

- A header row for each file with matches, in the same format as normal search results, plus the number of replacements.
- Under each header, one entry per line that had a match: line number and original line, then either the replaced line or the text "replacement skipped" (the reference only shows replaced lines, because everything was replaced).
- A line with several matches shows the combined result of its marks (replaced if any match on it is marked); the entry is recomputed whenever a match on that line changes state.
- Files not written for a known reason (read-only file type, already replaced earlier in this search) show a short note under the header instead of lines.
- Only match lines appear; no nearby code and no context lines.
- No extra search-settings line in the pane. The search and replace settings go in the saved report's header block (R7).

**Replaced-line text** must come from the engine's own replace code, so the log cannot disagree with what is written. Two ways to get it, to be settled in Phase 1:

1. Run the engine's replace on the single line with only that line's marked matches. Simplest, but depends on how the engine pairs matches with positions **[unverified]**.
2. Run the engine's replace on the whole file in memory with the real marks (the preview code already does this with all matches marked), then take the lines at the matching positions. Works when replacements do not change the number of lines; multi-line cases fall back to showing the original line with a note.

The highlight of the replacement text in the new line needs the position and length of each replacement in that line, so the builder should return those spans along with the line text **[unverified; depends on the approach chosen]**.

Files from plugin engines that cannot supply text (hex, archive, Word/Excel/PDF) show the header with a count only **[unverified; check each engine]**. Very large files show counts only above a threshold chosen after measuring.

### R3. Replace the rest

Change the "Replace in all files" button to mark the currently selected match and every match after it (file order, then match order), leaving earlier decisions alone, and close with OK. Rename the English label to something like "Replace the rest". Other languages keep their current wording for now (the project uses Weblate for translations).

### R4. Write errors

- Existing handling stays: the failing file is restored from its backup and the run stops.
- The log marks the failing file with its error, and marks files after it as "not applied". Files before it show as normal.
- Undo is enabled for files that did complete.
- If the restore also fails, the error message names the backup location in the undo folder.
- No automatic rollback of completed files.

### R5. Undo interaction

- After a successful Undo, the log is cleared.
- The dialog's Undo / Undo file buttons only clear marks and stay unchanged.
- Showing the log must not go through the normal search-completion path, which flags the undo backups to be discarded at the next replace (`needsClearUndo`).

### R6. Display rules

- In both routes the pane shows only the log after a replace. Unselected results in the selected-files route disappear; re-run the search to get them back.
- While the log is displayed, Replace and "Search in results" must not treat log entries as live matches.
- The log clears when the next normal search starts.

### R7. Saving the log

- While the log is showing, Search → More → Save results saves the log instead of search results. The existing formats stay available; a new **HTML** format is added, and it is offered only while the log is showing.
- **Report / text:** reuse the existing Report header block (search term, search type, options, folder, file patterns, totals) and add a "Replace with:" line. Each file shows its path, a line such as "has N replacements on M lines:", and the original and new line pairs from R2. No context lines. Skipped matches show "replacement skipped". Colors do not apply.
- **csv:** what a SaR log means as csv is not settled; decided in the spike after seeing the csv writer (for example, one row per replaced line: file, line number, old text, new text) **[unverified]**.
- **HTML:** a single standalone `.html` file. A `<style>` block at the top defines classes for the old text and the new text, with colors taken from the same theme brushes as the pane (R2) and a monospace font. Matches are wrapped as `<span class="old">` and `<span class="new">`. Source text is HTML-escaped (`<`, `>`, `&`). The header and per-file lines match the text report. No external files, scripts or fonts.
- If the log has been cleared (new search, Undo), there is nothing to save and the command behaves as it does today.

## 5. Technical notes

- First task: examine how `GrepSearchResultsViewModel` and `FormattedGrepResult` / `FormattedGrepLine` build and display the tree, and decide how to add log rows (a new row kind like the context-line kind is the likely route) without disturbing normal searches **[unverified]**. This is the main risk; it comes before any other code. The old/new pair with highlighted spans in R2 is part of what the row design must support.
- Also in the spike: find how Save results is built (menu, format list, writers) and whether the text writer works from the tree or from the search state; find which theme brushes the Replace preview uses for its highlight.
- Live updates: the Replace window is modal, but it shares the UI thread with the main window, so the results pane should repaint while it is open **[unverified]**. `ReplaceViewModel` already raises a `ReplaceMatch` event whenever a mark changes **[verified]**, which is the likely hook.
- The log builder should be a pure function (inputs: file text, marks, replace settings; output: list of entries) so it can be unit-tested without the UI. The text and HTML writers should also be pure functions over the builder's output.
- Build: .NET SDK 10.0.400 (`global.json`); WPF project targets `net10.0-windows`; solution `dnGREP.WPF.slnx`. Derell builds and runs the UI on Windows; a command-line `dotnet build` should work there **[unverified]**.
- License: GPL 3.0 applies to anything added to the fork.

## 6. Phases

0. **Spike (read-only).** Results tree structure and the log-row approach; Save results structure; theme brushes of the Replace preview. Written up before coding.
1. **Log builder.** Pure function with unit tests; settle the replaced-line approach.
2. **Display and rules.** Hook into the Replace window's mark events (live log), the OK / Cancel handling, and `ExecuteReplace` (selected-files route); R2 display; R4 error entries and Undo enable; R5 and R6.
3. **Replace the rest (R3).** Small change in `ReplaceViewModel` plus the English label.
4. **Save the log (R7).** Text and HTML writers over the builder's output, the HTML menu entry, and the csv decision.

## 7. Testing

- Unit tests (xunit.v3, `Tests/`): log builder (replaced lines, skipped lines, lines with several matches, regex captures, line endings and encodings, empty and large inputs, highlight spans for old and new text); the "from here onward" marking; text and HTML writers (header block, escaping of `<`, `>`, `&` in source lines, class spans around the right text). `GrepCoreTest.cs` already exercises Replace and Undo and is the model.
- Manual checklist (I cannot run the WPF UI): the three-file test folder; confirm some, skip some, then Replace the rest; check the log against the HisGrepship reference layout. Use the selected-files route. Use regex with `$1`. Force a write error (read-only or locked file). Undo and confirm the log clears. Save the log as text and as HTML and open the HTML in a browser to check the colors under a light and a dark theme.

## 8. Non-goals

- No changes to the Replace window other than R3.
- No preview changes, confirm pane, Skip button, or backup diffing.
- No change to search behavior, backup, or Undo mechanics beyond R4 and R5.
- Scripted replaces keep their current behavior.
- No new dependencies.
- HTML (or colored) output for ordinary search results is deferred; it would be a small extension of the R7 writer later. No `.md`, SVG or RTF output.
- No theme work and no changes to the separate ThemeEditor application.
- A "hide extraneous controls" checkbox for the Replace window is wanted later and is not part of this work. The window already hides some controls through a visibility binding (`IsFullDialog`), so it should be straightforward when its turn comes.

## 9. Known existing risks (not fixed here)

- A failed restore after a write error is silently swallowed in `GrepCore.Replace`; the user's file may then exist only in the undo folder. R4 makes the message name that location but does not change the behavior.

## 10. Defaults adopted (Derell can change any)

- The saved report reuses the existing Report header block plus a "Replace with:" line (R7).
- The large-file counts-only threshold is chosen after measuring.
- This is a personal fork, not an upstream offer.

No open questions remain for Derell.
