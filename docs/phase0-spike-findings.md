# Phase 0 Spike Findings: Replacement Log in the Results Pane

Status: written for Derell's review, 2026-10-15. Read-only survey; nothing was built, run, or changed in the code.

Basis: source on branch `sar-log` at commit `f65c9d7`, read against the Draft 7 spec. (The copy of the spec in this `docs` folder is still **Draft 6**; Draft 7 is in the Claude project. See section 9.)

Everything below was established by reading source and is **[verified]** unless marked **[unverified]**, which means it needs a build and a runtime check. Line numbers refer to commit `f65c9d7`.

## 1. Decision: GO for the in-pane log

Recommendation: put the log in the Results pane (the spec's main plan). The separate Log window fallback is not needed.

Why:

- **No new tree row type is required.** The Results tree can already display a `GrepSearchResult` whose lines were supplied in advance, without reading the file and without context lines (section 2). A small `LogKind` property on `GrepLine` is enough to colour old and new lines differently.
- **The Save writers work from `GrepSearchResult` lists, not from the tree** (section 3), so the same log objects can feed the text and HTML writers.
- **The engine can produce each replaced line for us,** the same way the Replace window's preview already does (section 6).
- **The risks found are manageable** and are listed in section 7. Two of them are changes to existing code that would otherwise silently wipe the log (the two `ResultsViewModel.Clear()` calls in the replace flow).

What the in-pane approach costs, so the choice is informed: about seven existing places need a small gate or hook (section 8), and the log is only as visible as the Replace window's position allows (section 7, item 9).

## 2. The Results tree

**How it is built** [verified]:

- `ResultsTree.xaml` binds the tree to `GrepSearchResultsViewModel.SearchResults`, an `ObservableCollection<FormattedGrepResult>`. Adding or removing items updates the display.
- There are two templates: a `HierarchicalDataTemplate` for `FormattedGrepResult` (the file header row; its children are `FormattedLines`) and a `DataTemplate` for `FormattedGrepLine` (line-number column plus an `InlineTextBlock` bound to `FormattedText`).
- `FormattedGrepLine.FormatLine` (FormattedGrepLine.cs:202) builds the coloured text from `GrepLine.Matches`, using the theme resource keys `Match.Highlight.Foreground` and `Match.Highlight.Background` for every match.
- Row kinds today are chosen in the `FormattedGrepLine` constructor through `Style`: normal, `"Context"` (grey text; hidden when `ShowLinesInContext` is off, via `GrepLine.IsContext`), and `"Empty"`. File headers use `"ReadOnly"` and `"Error"`. The styling is DataTriggers in the tree's `ItemContainerStyle` (ResultsTree.xaml:381-410).

**The key finding, a way to inject lines without touching disk** [verified]:

- `GrepSearchResult.SearchResults` has a public setter (GrepSearchResult.cs:178-190).
- `GetLinesWithContext` returns that cached list as-is when it is already set (GrepSearchResult.cs:193-226). `LazyResultsList.Load` and `LoadAsync` go through it.
- So a synthetic `GrepSearchResult` with its `SearchResults` pre-set displays exactly those lines, never re-reads the file, and shows no context lines regardless of the context-line settings.

**Section breaks and line-number width** [verified]:

- A separator line is drawn when consecutive rows jump in line number (LazyResultsList.cs:117-121). An old/new pair with the same line number gets no separator between its two rows; non-adjacent pairs do.
- The number column width is computed from the largest line number (LazyResultsList.cs:123-133). In the tree this is automatic.

**What needs adding** (for Phase 2):

1. A `LogKind` property on `GrepLine` (in `dnGREP.Common`): None / Old / New / Skipped / Note. `FormattedGrepLine` reads it to set `Style` and to pick brushes in `FormatLine`.
2. A header label for log results. `FormattedGrepResult.SetLabel` builds "(N matches on M lines)" from `GrepResult.Matches` using fixed resource strings (FormattedGrepResult.cs:212-227). The log header needs its own wording ("N replacements"), which means one new English resource string (other languages come through Weblate, as in R3). `GrepResult.Matches` must be filled in on log results so the counts work.
3. Optional DataTriggers on the new styles for row backgrounds.
4. Multi-line replacement text (R2): extra rows with `LineNumber = -1` and non-empty text show a blank number field and are not styled `"Empty"` (that style needs empty text too, FormattedGrepLine.cs:60). This works with today's code.

**Live updates** [unverified at runtime]: `ReplaceWindow` is shown with `ShowDialog()`. A WPF modal dialog runs a nested dispatcher loop, so the main window should keep repainting while it is open. Adding rows to the observable collections should therefore be visible live. This is the first thing to check once there is a build.

## 3. Save results

**Wiring** [verified]:

- The commands live under the More button's context menu: Save results, then Report / Text / CSV (MainView.xaml:1195-1199).
- Each command calls `MainViewModel.SaveResultsToFile(reportType)` (MainViewModel.cs:3164), which shows a `SaveFileDialog` and then calls `ReportWriter.SaveResultsReport`, `SaveResultsAsText`, or `SaveResultsAsCSV` on `ResultsViewModel.GetList()`.
- `ReportWriter` (dnGREP.Common/ReportWriter.cs) works from a `List<GrepSearchResult>`, reading `result.Matches` and `result.SearchResults`. It does **not** read the tree. So a log made of synthetic `GrepSearchResult` objects can be handed to a writer.
- The Report header block comes from `MainViewModel.GetSearchOptions()` (MainViewModel.cs:3393): search term, type, case and other options, folder, file patterns, exclusions, binary/archive/symlink flags, size and date filters. R7 can reuse it as the spec says, with a "Replace with:" line added.

**Existing report line format** [verified]: `ReportWriter.GetResultLinesWithContext` pads line numbers to a fixed 6 characters (`PadLeft(6)`) followed by `: `. The log writer (R7) pads to the widest number in the file instead, so it is a new pure writer, not a tweak of this one.

**Things that will need a gate** (details in section 8):

- `SaveResultsToFile` only runs `if (FilesFound)` (line 3166). A replace does not reset `FilesFound`, but editing the search box, folder, or file pattern does (BaseMainViewModel.cs:554-558). R7 must therefore test "log is displayed", not `FilesFound`, or Save would silently do nothing after the user touches the search box.
- "Copy results", "Copy file names", and the Report Options dialog also take `GetList()`. With a log showing, "Copy results" would list both the old and new lines (it keeps every non-context line, ReportWriter.cs:241). Harmless, but decide whether to leave it, or gate it.
- Scripts and command-line report options use the same writers (MainViewModelScripts.cs:133-137, MainViewModel.cs:3229-3242) and are unaffected.

## 4. The Replace preview: brushes and offsets

These were the two Phase 0 questions about the Replace window's preview.

**Brushes** [verified]. The preview colours come from `ReplaceViewHighlighter.cs:41-47` and are all theme resources (defined in `Themes/LightBrushes.xaml`, `DarkBrushes.xaml`, and the named themes):

| Key | Light | Dark | Use in the preview |
|---|---|---|---|
| `DiffText.Deleted.Word.Background` | `#FFFFCBC4` (salmon) | `#FF8A0000` (dark red) | removed words |
| `DiffText.Inserted.Word.Background` | `#FFC0FFB0` (light green) | `#FF006BC2` (blue) | added words |
| `DiffText.Deleted.Line.Background` | `#FFF7E5E3` | `#FF420000` | whole removed line |
| `DiffText.Inserted.Line.Background` | `#FFECFFE8` | `#FF003057` | whole added line |
| `Match.Replace.Background` / `.Foreground` | `#FF98FB98` / black | `#FF267800` / white | match marked for replace |
| `Match.Skip.Background` / `.Foreground` | `#FFFFA07A` / black | `#FF8A0000` / white | match skipped |

Recommendation: old text uses `DiffText.Deleted.Word.Background`, new text uses `DiffText.Inserted.Word.Background`, and "replacement skipped" entries use `Match.Skip.*`. All are theme-settable without any ThemeEditor work.

One difference from HisGrepship to decide on: those keys are **backgrounds** only (there is no foreground key for the diff colours), whereas HisGrepship used blue and green **bold text**. Using the existing keys keeps the log consistent with the Replace window's own preview. Bold can be added on top of the background if wanted.

**Replacement offsets**: the spec asked whether the preview already records the position and length of each replacement in a line. It does not [verified]:

- The preview highlights through `DiffPiece.SubPieces` from the NetDiff library (ReplaceViewHighlighter.cs:168-201), which is a character-level diff between the old and new line, not a list of replacement spans.
- The only place that works out replacement lengths is the long-line chopping code (ReplaceViewModel.cs:375-397). It is an approximation: it ignores the search options and re-runs the regex on the match text alone.
- A character diff would highlight only the letters that differ. For example, `pargb` to `pre_argb` would highlight only the inserted characters, not the whole replacement text.

So the log builder has to compute its own spans. Section 6 describes how, using only the engine's own output.

## 5. Gating: Replace button and "Search in results"

**Replace button** [verified]:

- `ReplaceCommand` is enabled by `MainViewModel.CanReplace` (line 3250). That property is a plain computed value, re-evaluated whenever WPF re-queries commands, so adding a condition works with the normal requery. Call `CommandManager.InvalidateRequerySuggested()` when the log appears or clears, to be safe.
- Today, after a replace the Results tree is empty, so `GetWritableFilesWithMatches()` is false and Replace is disabled for free.
- A log made of results with matches would make that check **true** and Replace would be **enabled**. So R6's explicit rule is required: add `!ResultsViewModel.IsLogDisplayed` to `CanReplace`.
- `UpdateReplaceButtonTooltip` (line 3269) would need a new case and a new English string, otherwise the tooltip is blank while the button is disabled.

**"Search in results"** [verified]:

- The checkbox is visible when `CompositeSearchInResultsVisible` is true, which is `SearchInResultsVisible && CanSearchInResults` (MainViewModelProps.cs:168).
- `CanSearchInResults` is computed only when `CurrentGrepOperation` or `IsSaveInProgress` change, from `ResultsViewModel.SearchResults.Count > 0` (BaseMainViewModel.cs:693-703). That explains why the checkbox is hidden when the pane is empty: it is the same property. [This answers the spec's "how it is implemented" item.]
- It is not enough to hide the checkbox. The search start path reads the checkbox's bound value, which can stay `true` from earlier: `if (SearchInResultsContent && CanSearchInResults)` (MainViewModel.cs:1966 and 1983). If that is true while the log shows, a normal search would take its file list from the log. So `CanSearchInResults` itself must be false while the log is displayed, and it must be re-evaluated when the log appears or clears (it currently is not triggered by changes to `SearchResults`).

**Clearing on the next search** [verified]: a normal search calls `ResultsViewModel.Clear()` at the start (MainViewModel.cs:1994). That is the natural place for the log to go away, provided `Clear()` also resets `IsLogDisplayed`.

## 6. The log builder: how to get the replaced text

This settles the Phase 1 question the spec left open ("approach 1 or 2").

**What the engine does** [verified]:

- `GrepEnginePlainText.Replace(Stream, Stream, ...)` (GrepEnginePlainText.cs:62) is public and reads the stream line by line, calling the replace method for each line with that line's number and file position. The Replace window's preview already calls it in memory exactly this way (ReplaceViewModel.cs:953-961): `new GrepEnginePlainText()`, `engine.Initialize(InitParameters, FileFilter.Default, null)`, then `engine.Replace(...)` on `MemoryStream`s.
- Within a line, the regex replace re-runs the search on that line and pairs the results with the marked matches using `GrepMatch.Equals`, which compares line number, start location, and length (GrepEngineBase.cs:231-232). Match start locations are file-absolute character offsets, counting line endings: each match is created as `matchStart + filePosition` (GrepEngineBase.cs:334 and 512), `filePosition` grows by each line's length including its line ending (GrepEnginePlainText.cs:138), and the text replace subtracts `filePosition` again (GrepEngineBase.cs:449). A one-line stream therefore runs with `filePosition = 0`, which is why the remapped copies below use plain in-line offsets.

**Recommended approach: run the engine one line at a time.** This is the spec's approach 1 and it matches how the engine itself works:

1. For each line that has matches, feed the engine a stream holding just that line (with its line ending). Give it copies of that line's matches with line number 1 and the start offset within the line, carrying the decided `ReplaceMatch` flags. (The `GrepMatch` constructor that takes a `FileMatchId` can build the remapped copies.) The output is that line's replaced text, possibly several lines if the replacement contains line breaks.
2. To get each replacement's highlight span, run the engine again with only match *i* marked. Its length is `outputLength - lineLength + matchLength`. A span's start is the in-line start plus the length changes from the earlier marked matches on the same line. This is exact for non-overlapping matches and costs N+1 engine calls for a line with N matches, which is cheap. Overlapping matches are merged by `GrepMatch.Normalize` (GrepMatch.cs:154-196) **[unverified that every search path calls it]**.
3. Approach 2 (replace the whole file in memory, then pick lines by position) is rejected as the main route: it breaks as soon as a replacement adds or removes line breaks, which is the reason the preview needs a diff library.

**Where per-line cannot work** (use the spec's fallback: original line plus a short note) [verified]:

- The **Multiline** search option and **XPath** searches replace the whole file as one block (`ReplaceMultiline`, GrepEnginePlainText.cs:82-83; `DoXPathReplace`, GrepEngineBase.cs:627).
- Hex, archive, and Word/Excel/PDF files never reach the Replace window, as the spec says.

**Differences between the preview's engine call and the real replace** that the builder must copy from the real one so the log cannot disagree with the file:

1. `GrepCore.Replace` calls `Utils.ReplaceSpecialCharacters(replacePattern)` before the engine (GrepCore.cs:654). It converts the double-backslash forms `\\a \\b \\f \\n \\r \\t \\v \\0` (Utils.cs:2671-2685). The preview skips this step. The engine itself still converts `\\t \\r \\n` (GrepEngineBase.cs:98-110), so only `\\a \\b \\f \\v \\0` would differ, but the builder should call it anyway.
2. **`$(guid)`, its upper-case form, and `$(guidx)` cannot be reproduced.** `$(guid)` creates a new GUID for every replaced match (GrepEngineBase.cs:83-96), so a preview call and the real write produce different values. `$(guidx)` is cached per search pattern and reset at the start of each replace run (`ResetGuidxCache`, line 26; GrepCore.cs:652). The log will show a different GUID than the one in the file. Suggested handling: add a one-line note on affected entries. This is rare, so it is not worth more.

## 7. Risks and observations

1. **Two `ResultsViewModel.Clear()` calls in the replace flow would wipe the log.** `ExecuteReplace(..., clearAll: true)` clears at MainViewModel.cs:2228, and the replace-completion handler clears again at line 1790 (`ReplaceType != SelectedFiles`). Both must be skipped when a log is active.
2. **Scripted replaces must keep today's behavior** (spec non-goal). They go through the same `ExecuteReplace` and completion handler (MainViewModel.cs:2144-2154). The log hooks belong in the dialog path of `Replace()` only, and the Clear calls stay for scripts. A `logActive` flag distinguishes the two.
3. **R5 holds by construction.** `needsClearUndo = true` is set only in the search-completion branch (MainViewModel.cs:1726), not in the replace-completion branch. Showing the log from the replace path therefore never schedules the undo backups for discard. Undo itself does not touch the Results pane today, so R5's "clear the log after a successful Undo" is one added line in the success branch of `Undo()` (around line 2345).
4. **R4, write errors: the existing code does what the spec assumed, and the fix is safe.**
   - `ExecuteReplace` adds every file to `undoList` up front, before any are processed (MainViewModel.cs:2205).
   - `CanUndo` is set only on the success branch (line 1781). On failure, and on cancel (which reaches the same branch with `e.Result = null`, line 1429), Undo stays off even if earlier files were replaced. This confirms the previously unverified claim.
   - Enabling Undo on those paths is safe: `GrepCore.Undo` copies a backup back only `if (File.Exists(sourceFile))` (GrepCore.cs:770-772), so files that never got a backup are skipped, and the failing file's backup equals its restored original.
   - `GrepCore.Replace` returns `-1` without saying which file failed (GrepCore.cs:746). The `ProcessedFile` events it raises before and after each file (lines 664 and 701) identify it: the failing file is the last one begun without a matching finish **[inferred from source; unverified at runtime]**.
5. **Skipped entries need a different hook than marks.** The Replace window raises its `ReplaceMatch` event only when a mark changes (Replace, Undo, bulk buttons; ReplaceViewModel.cs:712-766). **Next** does not raise it; it only changes the observable `SelectedGrepMatch` and `SelectedSearchResult`. To get "replacement skipped" entries, the log must also listen to those property changes. A simple model: every match the cursor has reached is logged as replaced if marked and skipped if not, recomputed on both events.
6. **Cancel leaves the Results pane blank, as specified, which loses the user's search results.** The first log entry clears the tree (R1), so closing the Replace window with Cancel leaves nothing to go back to except re-running the search. This is Derell's stated choice. A possible improvement, if wanted later: keep the original `FormattedGrepResult` list aside and restore it on Cancel. It is cheap, since they are just objects in a list.
7. **Marks persist after Cancel today.** The Replace window marks the same `GrepMatch` objects that the Results tree holds, and Cancel does not clear them. Existing behavior, noted because the log makes it more visible.
8. **The "Replace in file" button is not hidden by `IsFullDialog`**, contrary to the spec's guess (ReplaceWindow.xaml:179-184 has no visibility binding; only the match-level buttons do, lines 208-240). So why Derell does not see it is still unexplained. A plausible cause is clipping in the compact 680x340 dialog **[unverified]**. It does not affect this work.
9. **The Replace window can cover the Results pane.** `MainViewModel.Replace()` creates it without an owner (MainViewModel.cs:2158). It is centred on screen at 680x340 in compact mode, or restored to its last saved bounds in full mode, up to 980x800 by default (ReplaceWindow.xaml.cs:36-51). Derell can move and resize it (the bounds are saved), or use a second monitor, but the live log is only as visible as he arranges it.
10. **Long lines.** Result rows truncate at 500 characters unless wrap is on, with the existing "additional characters" message (FormattedGrepLine.cs:207, 317-362). Log rows inherit that behavior.

## 8. Change list by phase

**Phase 1: builder and writers** (new, pure, unit-tested)

- A log builder (inputs: file text, marks, replace settings; output: entries with old and new text and highlight spans), using the per-line engine approach from section 6.
- Text and HTML writers over the builder output (R7).

**Phase 2: display and rules**

- `GrepLine`: add `LogKind`.
- `FormattedGrepLine`: map `LogKind` to `Style` and brushes. `FormattedGrepResult.SetLabel`: the log header wording. `ResultsTree.xaml`: optional row-style triggers.
- `GrepSearchResultsViewModel`: `IsLogDisplayed`; `Clear()` resets it; methods to add and update log files and lines live.
- `MainViewModel.Replace()` (dialog path only): hook `ReplaceMatch` and the selection changes on the Replace window's view model; build the live log; on OK call `ExecuteReplace` without clearing; on anything else clear the log.
- `MainViewModel`: skip the two `Clear()` calls when the log is active (lines 2228 and 1790); `CanReplace` gate plus new tooltip; `CanSearchInResults` gate plus re-evaluation; R4 error entries and `CanUndo` on failure and cancel; clear the log after a successful Undo.

**Phase 3: R3** (small): `ReplaceViewModel.ReplaceAll()` (line 701) marks every match in every file today. Change it to mark the current match and everything after it. The current position is the private `fileIndex` and `matchIndex` fields (or `SelectedSearchResult` and `SelectedGrepMatch`). One English label change in `Resources.resx`.

**Phase 4: R7**: Save-results hooks (gate on `IsLogDisplayed`, not `FilesFound`); an HTML menu entry shown only while the log is displayed; a decision on csv (the existing csv writers take `GrepSearchResult` lists, so a one-row-per-replaced-line writer is straightforward).

## 9. Questions for Derell

1. **Go on the in-pane log?** Recommended (section 1). Nothing more is needed from you to proceed beyond a yes.
2. **Colours:** use the existing theme backgrounds (`DiffText.*.Word.Background`, `Match.Skip.*`) as in section 4, instead of HisGrepship's blue and green bold text?
3. **Cancel loses the search results** (section 7, item 6). Leave it blank as specified, or restore the original results on Cancel?
4. **GUID tokens** in the replace text (section 6): a short note on the log entry is the suggested handling. OK?
5. **The `docs/dngrep-sar-before-after-spec.md` in this repo is Draft 6** (it says so in its first line); the Draft 7 you described is not in the repo yet. I did not overwrite it, in case your copy has not been pushed. Tell me if you want me to commit Draft 7 over it.
6. Where you arrange the Replace window relative to the main window affects how much of the live log you see (section 7, item 9). No action needed now; this is just to keep in mind for the first test build.

## 10. Next step

On a yes to question 1, Phase 1 (builder and writers, with unit tests) can start. It has no UI dependency, so it can begin before any decision on the display details.
