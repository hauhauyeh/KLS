using System;
using System.Collections.Generic;

namespace KLS.Models
{
    /// <summary>
    /// Four levels, not three. An earlier design used OK/Warning/Error and
    /// then needed both "a warning that blocks until acknowledged" and "a
    /// warning that never blocks" -- two behaviours under one word, which is
    /// exactly the kind of thing that gets implemented wrong.
    ///
    ///   Error    import is impossible            button disabled, no override
    ///   Confirm  possible but probably wrong     button disabled until ticked
    ///   Warning  proceeds; user should know      button enabled
    ///   Info     neutral fact about a row        no severity
    /// </summary>
    public static class OpenBalanceSeverity
    {
        public const string OK = "OK";
        public const string Info = "Info";
        public const string Warning = "Warning";
        public const string Confirm = "Confirm";
        public const string Error = "Error";

        private static readonly Dictionary<string, int> Rank = new(StringComparer.OrdinalIgnoreCase)
        {
            [OK] = 0,
            [Info] = 1,
            [Warning] = 2,
            [Confirm] = 3,
            [Error] = 4
        };

        public static string Worst(string a, string b)
        {
            return RankOf(a) >= RankOf(b) ? Normalise(a) : Normalise(b);
        }

        public static bool BlocksImport(string severity)
        {
            var rank = RankOf(severity);

            return rank >= Rank[Confirm];
        }

        private static int RankOf(string? severity)
        {
            if (severity != null && Rank.TryGetValue(severity, out var rank))
                return rank;

            // An unrecognised severity is treated as the worst case rather than
            // ignored: a typo in a proc must not quietly enable the import.
            return Rank[Error];
        }

        private static string Normalise(string? severity)
        {
            if (severity != null && Rank.ContainsKey(severity))
                return severity;

            return Error;
        }
    }
}
