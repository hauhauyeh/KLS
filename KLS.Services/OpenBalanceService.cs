using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace KLS.Services
{
    public class OpenBalanceService : BaseService, IOpenBalanceService
    {
        /// <summary>
        /// A section whose row count falls by more than this is almost always a
        /// user who filtered their sheet and forgot the import replaces
        /// everything. Below it, deletions are ordinary editing.
        /// </summary>
        private const decimal RowDropConfirmThreshold = 0.10m;

        private readonly ISystemSettingService _systemSettingService;
        private readonly ImportFileStore _files;

        public OpenBalanceService(
            IUnitOfWork uow,
            ISystemSettingService systemSettingService,
            IWebHostEnvironment hostingEnvironment) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _files = new ImportFileStore(hostingEnvironment, "_openbalance");
        }

        #region --- Status ---

        public OpenBalanceStatusRes GetStatus()
        {
            var rows = Uow.OpenBalances.GetStatus();

            var res = new OpenBalanceStatusRes
            {
                AsOfDate = AsOfDate(),
                ObeBalance = rows.FirstOrDefault(r => r.ObeBalance.HasValue)?.ObeBalance
            };

            foreach (var info in OpenBalanceSectionInfo.All)
            {
                var row = rows.FirstOrDefault(r => r.Section == info.Token);

                res.Cards.Add(BuildCard(info, row));
            }

            var offenders = res.Cards
                .Where(c => c.Status == OpenBalanceSeverity.Warning)
                .Select(c => c.SectionName)
                .ToList();

            res.HasVariance = offenders.Count > 0;

            if (res.HasVariance)
            {
                res.VarianceMessage =
                    $"{Join(offenders)} {(offenders.Count == 1 ? "does" : "do")} not match the trial balance. " +
                    "The difference sits in Opening Balance Equity until it is corrected.";
            }

            return res;
        }

        private static OpenBalanceCard BuildCard(OpenBalanceSectionInfo info, OpenBalanceCardRow? row)
        {
            var card = new OpenBalanceCard
            {
                Section = info.Section,
                SectionName = info.DisplayName,
                Unit = UnitFor(info.Section),
                RowCount = row?.RowCount ?? 0,
                SectionTotal = row?.SectionTotal,
                LastImportedAt = row?.LastImportedAt,
                IsPosted = row?.IsPosted ?? false,
                PostedAt = row?.PostedAt,
                TrialBalance = row?.TrialBalance,
                HasTrialBalanceRow = row?.HasTrialBalanceRow ?? false,
                Variance = row?.Variance
            };

            // Nothing here is ever an Error. Reconciliation reports, it does not
            // block: a section imports and posts whether or not it ties (D3).
            if (info.ControlCode == null || card.RowCount == 0)
                return card;

            if (!card.HasTrialBalanceRow)
            {
                // A missing target and a wrong target are different user errors.
                // Reporting a variance here would send someone off to audit rows
                // that are all correct.
                card.Status = OpenBalanceSeverity.Warning;
                card.StatusMessage =
                    $"The trial balance has no {info.ControlCode} row, so there is nothing to check these " +
                    $"{card.RowCount:N0} rows against.";

                return card;
            }

            var variance = card.Variance ?? 0m;

            if (variance == 0m)
                return card;

            card.Status = OpenBalanceSeverity.Warning;
            card.StatusMessage =
                $"{Math.Abs(variance):N2} {(variance > 0 ? "over" : "under")} the trial balance";

            return card;
        }

        private static string UnitFor(OpenBalanceSection section)
        {
            switch (section)
            {
                case OpenBalanceSection.Account: return "accounts";
                case OpenBalanceSection.AR: return "customers";
                case OpenBalanceSection.AP: return "vendors";
                case OpenBalanceSection.ARE: return "employees";
                case OpenBalanceSection.INV: return "products";
                default: return "rows";
            }
        }

        #endregion

        #region --- Download / Export ---

        public (byte[] Content, string FileName) Download(OpenBalanceSection section)
        {
            var info = OpenBalanceSectionInfo.Get(section);

            var rows = Uow.OpenBalances.GetSectionRows(section, includeMasterList: true);

            var content = OpenBalanceWorkbook.Build(info, rows, AsOfDate());

            return (content, $"{info.FileName}.xlsx");
        }

        public (byte[] Content, string FileName) Export()
        {
            var content = OpenBalanceWorkbook.BuildArchive(
                OpenBalanceSectionInfo.All.ToList(),
                info => Uow.OpenBalances.GetSectionRows(info.Section, includeMasterList: false),
                AsOfDate());

            return (content, $"OpeningBalance_All_{DateTime.Now:yyyyMMdd}.xlsx");
        }

        #endregion

        #region --- Preview / Import ---

        public OpenBalancePreviewRes Preview(OpenBalancePreviewReq req)
        {
            var info = OpenBalanceSectionInfo.Get(req.Section);

            var token = _files.Save(req.ExcelFile!);
            var path = _files.PathFor(token);

            OpenBalancePreviewRes preview;

            try
            {
                preview = BuildPreview(path, info);
            }
            catch
            {
                // An unreadable workbook leaves nothing worth keeping.
                _files.TryDelete(path);
                throw;
            }

            preview.UploadToken = token;
            preview.FileName = req.ExcelFile!.FileName;

            return preview;
        }

        public OpenBalanceImportRes Import(OpenBalanceCommitReq req)
        {
            var info = OpenBalanceSectionInfo.Get(req.Section);

            var path = _files.ExistingPathFor(req.UploadToken);

            // The file on disk is the source of truth, not whatever the client
            // last saw. The disabled button is UX; this is the control.
            var preview = BuildPreview(path, info);

            if (preview.HasErrors)
                throw new ArgumentException(
                    $"The {info.DisplayName} file still has {preview.ErrorCount} problem" +
                    $"{(preview.ErrorCount == 1 ? "" : "s")}. Fix the highlighted rows and upload it again.");

            if (preview.NeedsConfirm && !req.Acknowledged)
                throw new ArgumentException(preview.ConfirmMessage ?? "This import needs to be confirmed first.");

            var result = Uow.OpenBalances.Import(path, req.Section);

            // The rows are committed by now. Cleanup failure must never turn
            // that into an error.
            _files.TryDelete(path);

            return new OpenBalanceImportRes
            {
                Section = req.Section,
                RowCount = result.RowCount,
                PriorRowCount = result.PriorRowCount,
                Status = GetStatus()
            };
        }

        public OpenBalanceStatusRes Unpost(OpenBalanceSectionReq req)
        {
            Uow.OpenBalances.Unpost(req.Section);

            return GetStatus();
        }

        /// <summary>
        /// The single source of the import's rules, used by both the preview the
        /// user approves and the gate the import enforces, so the two cannot
        /// drift apart.
        /// </summary>
        private OpenBalancePreviewRes BuildPreview(string path, OpenBalanceSectionInfo info)
        {
            var rows = Uow.OpenBalances.Preview(path, info.Section, out var downloadedAt, out var ignoredRowCount);

            var prior = Uow.OpenBalances.GetStatus()
                .FirstOrDefault(r => r.Section == info.Token);

            var priorRowCount = prior?.RowCount ?? 0;
            var lastImportedAt = prior?.LastImportedAt;

            var res = new OpenBalancePreviewRes
            {
                Section = info.Section,
                SectionName = info.DisplayName,
                RowCount = rows.Count,
                IgnoredRowCount = ignoredRowCount,
                FileRowCount = rows.Count + ignoredRowCount,
                PriorRowCount = priorRowCount,
                Total = rows.Sum(r => r.Amount ?? 0m),
                Rows = rows
            };

            foreach (var row in rows)
                res.Status = OpenBalanceSeverity.Worst(res.Status, row.Severity);

            res.ErrorCount = rows.Count(r => string.Equals(r.Severity, OpenBalanceSeverity.Error, StringComparison.OrdinalIgnoreCase));
            res.HasErrors = res.ErrorCount > 0;

            // File-level checks. Skipped once a row is already fatal: telling
            // someone their row count dropped is noise when the file will not
            // import at all.
            if (!res.HasErrors)
                ApplyConfirmRules(res, info, priorRowCount, lastImportedAt, downloadedAt);

            return res;
        }

        /// <summary>
        /// Confirm means "possible, but probably not what you meant" -- the
        /// import is refused until the user ticks the box, in the dialog and
        /// again on the server. All three cases are legitimate operations that
        /// nobody should perform unaware, and none of them can fire on a first
        /// import, when the section is empty and there is no download stamp.
        /// </summary>
        private static void ApplyConfirmRules(
            OpenBalancePreviewRes res,
            OpenBalanceSectionInfo info,
            int priorRowCount,
            DateTime? lastImportedAt,
            DateTime? downloadedAt)
        {
            if (res.RowCount == 0 && priorRowCount > 0)
            {
                res.NeedsConfirm = true;
                res.ConfirmMessage =
                    $"No row in this file has {ImportNumberPhrase(info.Section)} filled in. " +
                    $"Importing it will delete all {priorRowCount:N0} " +
                    $"{info.DisplayName} rows.";
            }
            else if (priorRowCount > 0 && res.RowCount < priorRowCount)
            {
                var dropped = priorRowCount - res.RowCount;

                if ((decimal)dropped / priorRowCount > RowDropConfirmThreshold)
                {
                    res.NeedsConfirm = true;
                    res.ConfirmMessage =
                        $"This file has {res.RowCount:N0} rows but {info.DisplayName} currently holds " +
                        $"{priorRowCount:N0}. Importing deletes the other {dropped:N0}.";
                }
            }

            // Someone else changed the section after this file was downloaded.
            // A workbook built by hand has no stamp; treat that as unknown and
            // say nothing rather than rejecting a legitimate input.
            if (!res.NeedsConfirm
                && downloadedAt.HasValue
                && lastImportedAt.HasValue
                && lastImportedAt.Value > downloadedAt.Value)
            {
                res.NeedsConfirm = true;
                res.ConfirmMessage =
                    $"{info.DisplayName} was changed on {lastImportedAt.Value:g}, after this file was " +
                    $"downloaded on {downloadedAt.Value:g}. Importing discards that change.";
            }

            if (res.NeedsConfirm)
                res.Status = OpenBalanceSeverity.Worst(res.Status, OpenBalanceSeverity.Confirm);
        }

        #endregion

        #region --- Helpers ---

        private DateTime? AsOfDate()
        {
            var raw = _systemSettingService.GetByKey<string>(GlobalKey.SYSTEM_START_DATE);

            if (string.IsNullOrWhiteSpace(raw))
                return null;

            // Stored as text. Parse it explicitly rather than leaning on the
            // server's locale, which is what the posting procs do implicitly.
            if (DateTime.TryParseExact(raw, new[] { "MM/dd/yyyy", "yyyy-MM-dd", "M/d/yyyy" },
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
                return parsed;

            return DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.None, out var fallback)
                ? fallback
                : null;
        }

        private static string Join(IReadOnlyList<string> names)
        {
            if (names.Count == 1)
                return names[0];

            if (names.Count == 2)
                return $"{names[0]} and {names[1]}";

            return string.Join(", ", names.Take(names.Count - 1)) + " and " + names[names.Count - 1];
        }

        private static string ImportNumberPhrase(OpenBalanceSection section)
        {
            switch (section)
            {
                case OpenBalanceSection.Account: return "a balance";
                case OpenBalanceSection.INV: return "quantity, price or total value";
                default: return "an amount";
            }
        }

        #endregion
    }
}
