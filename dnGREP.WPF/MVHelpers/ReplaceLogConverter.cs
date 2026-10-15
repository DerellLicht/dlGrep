using System.Collections.Generic;
using System.Linq;
using System.Text;
using dnGREP.Common;
using dnGREP.Localization;
using dnGREP.Localization.Properties;

namespace dnGREP.WPF.MVHelpers
{
    /// <summary>
    /// Turns a replacement log for one file into a GrepSearchResult the Results tree can show.
    /// The result carries its lines (so nothing is read from disk) and a header summary.
    /// </summary>
    internal static class ReplaceLogConverter
    {
        /// <summary>
        /// Converts the log of one file.
        /// For each entry the old line(s) come first, then the new line(s); an entry with no
        /// replacement gets a "replacement skipped" note line instead of new lines.
        /// </summary>
        /// <param name="log">the log for one file</param>
        /// <param name="searchPattern">the search pattern, stored on the synthetic matches</param>
        /// <returns>a result that displays as a file header with the log lines under it</returns>
        public static GrepSearchResult ToSearchResult(ReplaceLogFile log, string searchPattern)
        {
            // one placeholder match per entry: the Results tree only makes a file expandable
            // when it has matches; the real counts are shown through LogSummary
            List<GrepMatch> matches = [.. log.Entries.Select(e => new GrepMatch(searchPattern, e.LineNumber, 0, 0))];
            if (matches.Count == 0 && log.Note != null)
            {
                matches.Add(new GrepMatch(searchPattern, -1, 0, 0));
            }

            GrepSearchResult result = new(log.FileName, searchPattern, matches, Encoding.UTF8)
            {
                LogSummary = log.SkippedCount > 0 ?
                    TranslationSource.Format(Resources.Main_ReplaceLog_CountReplacementsSkipped,
                        log.ReplacementCount, log.ReplacedLineCount, log.SkippedCount) :
                    TranslationSource.Format(Resources.Main_ReplaceLog_CountReplacements,
                        log.ReplacementCount, log.ReplacedLineCount)
            };

            List<GrepLine> lines = [];
            if (log.Note != null)
            {
                lines.Add(NoteLine(log.Note));
            }

            foreach (ReplaceLogEntry entry in log.Entries)
            {
                foreach (ReplaceLogLine old in entry.OldLines)
                {
                    lines.Add(MakeLine(old, ReplaceLogLineKind.Old));
                }

                if (entry.IsReplaced)
                {
                    foreach (ReplaceLogLine added in entry.NewLines)
                    {
                        lines.Add(MakeLine(added, ReplaceLogLineKind.New));
                    }
                }
                else
                {
                    lines.Add(NoteLine(Resources.Main_ReplaceLog_ReplacementSkipped));
                }

                if (entry.Note != null)
                {
                    lines.Add(NoteLine(entry.Note));
                }
            }

            result.SearchResults = lines;
            return result;
        }

        private static GrepLine MakeLine(ReplaceLogLine source, ReplaceLogLineKind kind)
        {
            // continuation lines have number 0: -1 shows a blank number field
            return new GrepLine(source.LineNumber == 0 ? -1 : source.LineNumber, source.Text, false, null)
            {
                LogKind = kind,
                LogSpans = source.Spans
            };
        }

        private static GrepLine NoteLine(string text)
        {
            return new GrepLine(-1, text, false, null) { LogKind = ReplaceLogLineKind.Note };
        }
    }
}
