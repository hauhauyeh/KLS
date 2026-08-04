using ClosedXML.Excel;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.IO;

namespace KLS.Services
{
    /// <summary>
    /// Builds the downloadable opening balance workbooks.
    ///
    /// Deliberately NOT built on ExportService.ToExcel: that writes the sheet
    /// with ws.Cell(1,1).InsertTable(list), which emits Excel structured-table
    /// markup. HDR=yes parsing against a plain header row plus plain data rows
    /// is the predictable case and is what the import procs rely on.
    /// </summary>
    public static class OpenBalanceWorkbook
    {
        private const string InstructionsSheet = "Instructions";

        /// <summary>
        /// The key the upload reads back to detect that the section changed
        /// after this file was downloaded. Must match the WHERE clause in
        /// OpenBalance_ImportPreview.
        /// </summary>
        private const string DownloadedAtField = "DownloadedAt";

        public static byte[] Build(OpenBalanceSectionInfo info, IEnumerable<OpenBalanceExcelRow> rows, DateTime? asOfDate)
        {
            using var workbook = new XLWorkbook();

            WriteInstructions(workbook, info, asOfDate);
            WriteData(workbook, info, rows);

            using var stream = new MemoryStream();
            workbook.SaveAs(stream);

            return stream.ToArray();
        }

        /// <summary>All five sections in one book. Export only -- never an import.</summary>
        public static byte[] BuildArchive(
            IReadOnlyList<OpenBalanceSectionInfo> sections,
            Func<OpenBalanceSectionInfo, IEnumerable<OpenBalanceExcelRow>> rowsFor,
            DateTime? asOfDate)
        {
            using var workbook = new XLWorkbook();

            var summary = workbook.Worksheets.Add(InstructionsSheet);
            summary.Cell(1, 1).Value = "Field";
            summary.Cell(1, 2).Value = "Value";
            summary.Row(1).Style.Font.Bold = true;
            summary.Cell(2, 1).Value = "Document";
            summary.Cell(2, 2).Value = "Opening Balance archive (export only -- not an import file)";
            summary.Cell(3, 1).Value = "As Of Date";
            summary.Cell(3, 2).Value = asOfDate?.ToString("yyyy-MM-dd") ?? "";
            summary.Cell(4, 1).Value = "Exported At (UTC)";
            summary.Cell(4, 2).Value = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss");
            summary.Columns().AdjustToContents();

            foreach (var info in sections)
                WriteData(workbook, info, rowsFor(info));

            using var stream = new MemoryStream();
            workbook.SaveAs(stream);

            return stream.ToArray();
        }

        private static void WriteInstructions(XLWorkbook workbook, OpenBalanceSectionInfo info, DateTime? asOfDate)
        {
            var ws = workbook.Worksheets.Add(InstructionsSheet);

            ws.Cell(1, 1).Value = "Field";
            ws.Cell(1, 2).Value = "Value";
            ws.Row(1).Style.Font.Bold = true;

            var rows = new List<(string Field, string Value)>
            {
                ("Section", info.DisplayName),
                ("Sheet", info.SheetName),
                ("As Of Date", asOfDate?.ToString("yyyy-MM-dd") ?? ""),

                // Read back on upload to detect that someone else changed this
                // section in the meantime. A hand-built file has no stamp, which
                // is fine -- the upload treats a missing stamp as "unknown" and
                // says nothing.
                //
                // MUST be UTC: the upload compares it against MAX(CreatedAt) on
                // the staging table, and every CreatedAt in this schema defaults
                // to getutcdate(). A local timestamp here would make the check
                // wrong by the timezone offset in whichever direction hides the
                // problem.
                (DownloadedAtField, DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")),
                ("Note", "DownloadedAt is UTC. It is used to warn you if someone else changed this section after you downloaded the file."),

                ("Note", "Uploading this file REPLACES the whole " + info.DisplayName + " section."),
                ("Note", "Edit the rows on the " + info.SheetName + " sheet. Do not rename or delete that sheet."),
                ("Note", "Do not add or reorder columns. The importer reads them by position.")
            };

            rows.AddRange(SectionNotes(info));

            var r = 2;
            foreach (var (field, value) in rows)
            {
                ws.Cell(r, 1).Value = field;
                ws.Cell(r, 2).Value = value;
                r++;
            }

            // The stamp is a date the importer parses; keep it text so Excel
            // cannot reformat it into something TRY_CONVERT will not read.
            ws.Column(2).Style.NumberFormat.Format = "@";
            ws.Column(1).Width = 16;
            ws.Column(2).Width = 90;
        }

        private static IEnumerable<(string, string)> SectionNotes(OpenBalanceSectionInfo info)
        {
            switch (info.Section)
            {
                case OpenBalanceSection.Account:
                    yield return ("Note", "Balance: positive means the account's natural balance.");
                    yield return ("Note", "@AR, @AP, @INV and @ARE are CHECK FIGURES. They are compared against the matching section and are never posted to those accounts.");
                    yield return ("Note", "@OBE is calculated by the system. Do not enter it.");
                    break;

                case OpenBalanceSection.AR:
                    yield return ("Note", "Amount: positive means the customer owes you. Negative is a customer credit.");
                    yield return ("Note", "InvoiceNumber is for reference only. Balances post per customer.");
                    break;

                case OpenBalanceSection.AP:
                    yield return ("Note", "Amount: positive means you owe the vendor.");
                    yield return ("Note", "BillNumber is for reference only. Balances post per vendor.");
                    break;

                case OpenBalanceSection.ARE:
                    yield return ("Note", "Amount: positive means the employee owes you.");
                    break;

                case OpenBalanceSection.INV:
                    yield return ("Note", "Qty and Price are per base unit.");
                    yield return ("Note", "TotalValue must equal Qty x Price, to the cent.");
                    break;
            }
        }

        private static void WriteData(XLWorkbook workbook, OpenBalanceSectionInfo info, IEnumerable<OpenBalanceExcelRow> rows)
        {
            var ws = workbook.Worksheets.Add(info.SheetName);

            for (var c = 0; c < info.Columns.Length; c++)
                ws.Cell(1, c + 1).Value = info.Columns[c];

            ws.Row(1).Style.Font.Bold = true;

            var r = 2;
            foreach (var row in rows)
            {
                WriteRow(ws, info, r, row);
                r++;
            }

            ApplyColumnFormats(ws, info, r - 1);

            ws.Columns().AdjustToContents();
            ws.SheetView.FreezeRows(1);
        }

        private static void WriteRow(IXLWorksheet ws, OpenBalanceSectionInfo info, int r, OpenBalanceExcelRow row)
        {
            switch (info.Section)
            {
                case OpenBalanceSection.Account:
                    ws.Cell(r, 1).SetValue(row.Key1 ?? "");
                    ws.Cell(r, 2).SetValue(row.ResolvedName ?? "");
                    SetNumber(ws.Cell(r, 3), row.Amount);
                    ws.Cell(r, 4).SetValue(row.Notes ?? "");
                    break;

                case OpenBalanceSection.AR:
                case OpenBalanceSection.AP:
                    SetNumber(ws.Cell(r, 1), ParseInt(row.Key1));
                    ws.Cell(r, 2).SetValue(row.ResolvedName ?? "");
                    ws.Cell(r, 3).SetValue(row.Key2 ?? "");
                    SetNumber(ws.Cell(r, 4), row.Amount);
                    ws.Cell(r, 5).SetValue(row.Notes ?? "");
                    break;

                case OpenBalanceSection.ARE:
                    SetNumber(ws.Cell(r, 1), ParseInt(row.Key1));
                    ws.Cell(r, 2).SetValue(row.ResolvedName ?? "");
                    SetNumber(ws.Cell(r, 3), row.Amount);
                    ws.Cell(r, 4).SetValue(row.Notes ?? "");
                    break;

                case OpenBalanceSection.INV:
                    ws.Cell(r, 1).SetValue(row.Key1 ?? "");
                    ws.Cell(r, 2).SetValue(row.ResolvedName ?? "");
                    SetNumber(ws.Cell(r, 3), row.Qty);
                    SetNumber(ws.Cell(r, 4), row.Price);
                    SetNumber(ws.Cell(r, 5), row.Amount);
                    ws.Cell(r, 6).SetValue(row.Notes ?? "");
                    break;
            }
        }

        /// <summary>
        /// ACE infers each column's type from the first eight rows, so columns
        /// that are usually blank must be forced to text or a value typed
        /// further down comes back NULL with no error. Every one of the 1,858
        /// current OpenBalanceInv.Notes values is blank, which makes this a
        /// live path rather than a theoretical one.
        ///
        /// Code columns are text for the same reason in reverse: today no item
        /// or account code is all-numeric, but one added later would otherwise
        /// round-trip as a number and stop matching.
        /// </summary>
        private static void ApplyColumnFormats(IXLWorksheet ws, OpenBalanceSectionInfo info, int lastRow)
        {
            var rowCount = Math.Max(lastRow, 1);

            switch (info.Section)
            {
                case OpenBalanceSection.Account:
                    Text(ws, 1, rowCount);          // AccountCode
                    Text(ws, 4, rowCount);          // Notes
                    Money(ws, 3, rowCount);
                    break;

                case OpenBalanceSection.AR:
                case OpenBalanceSection.AP:
                    Text(ws, 3, rowCount);          // Invoice / Bill number
                    Text(ws, 5, rowCount);          // Notes
                    Money(ws, 4, rowCount);
                    break;

                case OpenBalanceSection.ARE:
                    Text(ws, 4, rowCount);          // Notes
                    Money(ws, 3, rowCount);
                    break;

                case OpenBalanceSection.INV:
                    Text(ws, 1, rowCount);          // ItemCode
                    Text(ws, 6, rowCount);          // Notes
                    ws.Range(2, 3, rowCount, 3).Style.NumberFormat.Format = "0.0000";
                    ws.Range(2, 4, rowCount, 4).Style.NumberFormat.Format = "0.0000";
                    Money(ws, 5, rowCount);
                    break;
            }
        }

        private static void Text(IXLWorksheet ws, int column, int lastRow)
        {
            ws.Column(column).Style.NumberFormat.Format = "@";
            ws.Range(2, column, lastRow, column).Style.NumberFormat.Format = "@";
        }

        private static void Money(IXLWorksheet ws, int column, int lastRow)
        {
            ws.Range(2, column, lastRow, column).Style.NumberFormat.Format = "0.00";
        }

        private static void SetNumber(IXLCell cell, decimal? value)
        {
            if (value.HasValue)
                cell.SetValue(value.Value);
            else
                cell.Clear(XLClearOptions.Contents);
        }

        private static void SetNumber(IXLCell cell, int? value)
        {
            if (value.HasValue)
                cell.SetValue(value.Value);
            else
                cell.Clear(XLClearOptions.Contents);
        }

        private static int? ParseInt(string? value)
        {
            return int.TryParse(value, out var parsed) ? parsed : null;
        }
    }
}
