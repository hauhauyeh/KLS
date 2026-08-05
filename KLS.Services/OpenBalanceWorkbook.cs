using ClosedXML.Excel;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

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
        private const int TemplatePrefillLastRow = 5000;

        /// <summary>
        /// The key the upload reads back to detect that the section changed
        /// after this file was downloaded. Must match the WHERE clause in
        /// OpenBalance_ImportPreview.
        /// </summary>
        private const string DownloadedAtField = "DownloadedAt";

        public static byte[] Build(OpenBalanceSectionInfo info, IEnumerable<OpenBalanceExcelRow> rows, DateTime? asOfDate)
        {
            using var workbook = new XLWorkbook();
            var rowList = rows.ToList();
            var lookupTemplate = LookupTemplateFor(info.Section);
            var partyDisplayNames = lookupTemplate != null
                ? BuildPartyDisplayNames(rowList)
                : null;

            WriteInstructions(workbook, info, asOfDate);
            WriteData(workbook, info, rowList, partyDisplayNames);

            if (lookupTemplate != null && partyDisplayNames != null)
            {
                var (sheetName, nameHeader, definedName) = lookupTemplate.Value;
                var lookupSheet = WritePartyLookup(workbook, rowList, partyDisplayNames, sheetName, nameHeader);

                // PayeeId is the last column on the name-first templates by design.
                ApplyLookupTemplate(
                    workbook,
                    workbook.Worksheet(info.SheetName),
                    lookupSheet,
                    partyDisplayNames.Count,
                    definedName,
                    info.Columns.Length);
            }

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

            rows.AddRange(SectionNotes(info, asOfDate));

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

        private static IEnumerable<(string, string)> SectionNotes(OpenBalanceSectionInfo info, DateTime? asOfDate)
        {
            var dateText = asOfDate?.ToString("yyyy-MM-dd") ?? "the as-of date";

            switch (info.Section)
            {
                case OpenBalanceSection.Account:
                    yield return ("Note", "This sheet lists your active balance-sheet accounts. Fill in the balance only for accounts that had an opening balance on " + dateText + ". Leave the rest blank -- blank rows are ignored.");
                    yield return ("Note", "An account that is not listed can be added: type its AccountCode into a new row.");
                    yield return ("Note", "Balance: positive means the account's natural balance.");
                    yield return ("Note", "@AR, @AP, @INV and @ARE are CHECK FIGURES. They are compared against the matching section and are never posted to those accounts.");
                    yield return ("Note", "@OBE is calculated by the system. Do not enter it.");
                    break;

                case OpenBalanceSection.AR:
                    yield return ("Note", "This sheet lists all your active customers. Use one row per open invoice owed to you on " + dateText + ". Leave rows with blank Amount alone -- blank rows are ignored.");
                    yield return ("Note", "CustomerName is the client-facing field. PayeeId is the system match key and stays in the last column for support review.");
                    yield return ("Note", "InvoiceDate is optional and should be typed as yyyy-MM-dd. Existing opening-balance rows download with blank InvoiceDate until invoice dates are stored durably.");
                    yield return ("Note", "Amount: positive means the customer owes you. Negative is a customer credit.");
                    yield return ("Note", "InvoiceNumber is the original invoice number for reference/source-record use. Balances post per customer.");
                    break;

                case OpenBalanceSection.AP:
                    yield return ("Note", "This sheet lists all your active vendors. Use one row per open bill you owed on " + dateText + ". Leave rows with blank Amount alone -- blank rows are ignored.");
                    yield return ("Note", "VendorName is the client-facing field: pick it from the dropdown. PayeeId is the system match key, fills in by itself, and stays in the last column for support review.");
                    yield return ("Note", "If PayeeId stays blank, the VendorName did not match the vendor list.");
                    yield return ("Note", "For more than one bill from the same vendor, copy or insert another row and keep the same VendorName.");
                    yield return ("Note", "BillDate is optional and should be typed as yyyy-MM-dd. Existing opening-balance rows download with blank BillDate until bill dates are stored durably.");
                    yield return ("Note", "Amount: positive means you owe the vendor. Negative is a vendor credit.");
                    yield return ("Note", "BillNumber is the original vendor bill number for reference/source-record use. Balances post per vendor.");
                    yield return ("Note", "The Vendors sheet exists only for the PayeeId lookup. Do not edit, rename or delete it.");
                    yield return ("Note", "If a vendor you owe is not in the list, add the vendor in KLS first, then download this template again.");
                    break;

                case OpenBalanceSection.ARE:
                    yield return ("Note", "This sheet lists all your active employees. Fill in the amount only for employees that owed you money on " + dateText + ". Leave the rest blank -- blank rows are ignored.");
                    yield return ("Note", "An employee that is not listed can be added: type their Payee ID into a new row.");
                    yield return ("Note", "Amount: positive means the employee owes you.");
                    break;

                case OpenBalanceSection.INV:
                    yield return ("Note", "This sheet lists all your active inventory products. Fill in Qty, Price and TotalValue only for products on hand on " + dateText + ". Leave the rest blank -- blank rows are ignored.");
                    yield return ("Note", "A product that is not listed can be added: type its ItemCode into a new row.");
                    yield return ("Note", "Qty and Price are per base unit.");
                    yield return ("Note", "TotalValue must equal Qty x Price, to the cent.");
                    break;
            }
        }

        private static void WriteData(
            XLWorkbook workbook,
            OpenBalanceSectionInfo info,
            IEnumerable<OpenBalanceExcelRow> rows,
            IReadOnlyDictionary<int, string>? partyDisplayNames = null)
        {
            var ws = workbook.Worksheets.Add(info.SheetName);

            for (var c = 0; c < info.Columns.Length; c++)
                ws.Cell(1, c + 1).Value = info.Columns[c];

            ws.Row(1).Style.Font.Bold = true;

            var r = 2;
            foreach (var row in rows)
            {
                WriteRow(ws, info, r, row, partyDisplayNames);
                r++;
            }

            ApplyColumnFormats(ws, info, r - 1);

            ws.Columns().AdjustToContents();
            ws.SheetView.FreezeRows(1);
        }

        private static void WriteRow(
            IXLWorksheet ws,
            OpenBalanceSectionInfo info,
            int r,
            OpenBalanceExcelRow row,
            IReadOnlyDictionary<int, string>? partyDisplayNames)
        {
            switch (info.Section)
            {
                case OpenBalanceSection.Account:
                    ws.Cell(r, 1).SetValue(row.Key1 ?? "");
                    ws.Cell(r, 2).SetValue(row.ResolvedName ?? "");
                    SetNumber(ws.Cell(r, 3), row.Amount);
                    ws.Cell(r, 4).SetValue(row.Notes ?? "");
                    break;

                case OpenBalanceSection.AP:
                    ws.Cell(r, 1).SetValue(PartyDisplayName(row, partyDisplayNames));
                    ws.Cell(r, 2).SetValue(row.Key2 ?? "");

                    // BillDate has no durable source yet: OpenBalanceAP stores only
                    // AsOfDate, which is the opening date, not the bill date.
                    ws.Cell(r, 3).SetValue("");

                    SetNumber(ws.Cell(r, 4), row.Amount);
                    ws.Cell(r, 5).SetValue(row.Notes ?? "");
                    SetNumber(ws.Cell(r, 6), ParseInt(row.Key1));
                    break;

                case OpenBalanceSection.AR:
                    ws.Cell(r, 1).SetValue(PartyDisplayName(row, partyDisplayNames));
                    ws.Cell(r, 2).SetValue(row.Key2 ?? "");
                    ws.Cell(r, 3).SetValue("");
                    SetNumber(ws.Cell(r, 4), row.Amount);
                    ws.Cell(r, 5).SetValue(row.Notes ?? "");
                    SetNumber(ws.Cell(r, 6), ParseInt(row.Key1));
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
        /// The name-first sections, and only those, get a hidden lookup sheet plus a
        /// PayeeId formula. Null means the section is entered by code or id and needs
        /// neither. The lookup sheet name is local to the workbook: unlike
        /// OpenBalanceSectionInfo.SheetName, no stored procedure reads it.
        /// </summary>
        private static (string SheetName, string NameHeader, string DefinedName)? LookupTemplateFor(OpenBalanceSection section)
        {
            switch (section)
            {
                case OpenBalanceSection.AR: return ("Customers", "CustomerName", "ARCustomerNames");
                case OpenBalanceSection.AP: return ("Vendors", "VendorName", "APVendorNames");
                default: return null;
            }
        }

        /// <summary>
        /// The hidden lookup sheet the name-first templates match against.
        /// Always PayeeId in column A and the display name in column B, which is
        /// what ApplyLookupTemplate's INDEX/MATCH assumes.
        /// </summary>
        private static IXLWorksheet WritePartyLookup(
            XLWorkbook workbook,
            IEnumerable<OpenBalanceExcelRow> rows,
            IReadOnlyDictionary<int, string> partyDisplayNames,
            string sheetName,
            string nameHeader)
        {
            var ws = workbook.Worksheets.Add(sheetName);

            ws.Cell(1, 1).Value = "PayeeId";
            ws.Cell(1, 2).Value = nameHeader;
            ws.Row(1).Style.Font.Bold = true;

            var parties = rows
                .Where(r => r.ResolvedId.HasValue && partyDisplayNames.ContainsKey(r.ResolvedId.Value))
                .Select(r => r.ResolvedId!.Value)
                .Distinct()
                .OrderBy(id => partyDisplayNames[id], StringComparer.OrdinalIgnoreCase)
                .ThenBy(id => id)
                .ToList();

            var rowNumber = 2;
            foreach (var payeeId in parties)
            {
                SetNumber(ws.Cell(rowNumber, 1), payeeId);
                ws.Cell(rowNumber, 2).SetValue(partyDisplayNames[payeeId]);
                rowNumber++;
            }

            ws.Columns().AdjustToContents();
            ws.SheetView.FreezeRows(1);
            ws.Protect();
            ws.Visibility = XLWorksheetVisibility.Hidden;

            return ws;
        }

        /// <summary>
        /// Fills the PayeeId column from the name the client picked, and puts the
        /// lookup names behind a dropdown so the name is one they can match.
        /// </summary>
        private static void ApplyLookupTemplate(
            XLWorkbook workbook,
            IXLWorksheet dataSheet,
            IXLWorksheet lookupSheet,
            int partyCount,
            string definedName,
            int idColumn)
        {
            // Read the name off the sheet itself so the formula cannot point at a
            // sheet the workbook does not have.
            var lookupName = lookupSheet.Name;

            for (var row = 2; row <= TemplatePrefillLastRow; row++)
            {
                dataSheet.Cell(row, idColumn).FormulaA1 =
                    $"IF(A{row}=\"\",\"\",IFERROR(INDEX({lookupName}!$A:$A,MATCH(A{row},{lookupName}!$B:$B,0)),\"\"))";
            }

            if (partyCount > 0)
            {
                var partyNames = lookupSheet.Range(2, 2, partyCount + 1, 2);
                workbook.DefinedNames.Add(definedName, partyNames);

                var validation = dataSheet.Range(2, 1, TemplatePrefillLastRow, 1).CreateDataValidation();
                validation.List("=" + definedName, true);
                validation.IgnoreBlanks = true;
                validation.InCellDropdown = true;
            }
        }

        private static IReadOnlyDictionary<int, string> BuildPartyDisplayNames(IEnumerable<OpenBalanceExcelRow> rows)
        {
            var parties = rows
                .Where(r => r.ResolvedId.HasValue)
                .Select(r => new
                {
                    PayeeId = r.ResolvedId!.Value,
                    Name = (r.ResolvedName ?? "").Trim()
                })
                .Where(r => !string.IsNullOrWhiteSpace(r.Name))
                .GroupBy(r => r.PayeeId)
                .Select(g => g.First())
                .ToList();

            var duplicateNames = parties
                .GroupBy(c => c.Name, StringComparer.OrdinalIgnoreCase)
                .Where(g => g.Count() > 1)
                .Select(g => g.Key)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            return parties.ToDictionary(
                c => c.PayeeId,
                c => duplicateNames.Contains(c.Name)
                    ? $"{c.Name} [PayeeId: {c.PayeeId}]"
                    : c.Name);
        }

        private static string PartyDisplayName(
            OpenBalanceExcelRow row,
            IReadOnlyDictionary<int, string>? partyDisplayNames)
        {
            if (row.ResolvedId.HasValue &&
                partyDisplayNames != null &&
                partyDisplayNames.TryGetValue(row.ResolvedId.Value, out var displayName))
            {
                return displayName;
            }

            return row.ResolvedName ?? "";
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

                case OpenBalanceSection.AP:
                    var apRowCount = Math.Max(rowCount, TemplatePrefillLastRow);
                    Text(ws, 1, apRowCount);        // VendorName
                    Text(ws, 2, apRowCount);        // BillNumber
                    Text(ws, 3, apRowCount);        // BillDate
                    Text(ws, 5, apRowCount);        // Notes
                    Money(ws, 4, apRowCount);
                    break;

                case OpenBalanceSection.AR:
                    var arRowCount = Math.Max(rowCount, TemplatePrefillLastRow);
                    Text(ws, 1, arRowCount);        // CustomerName
                    Text(ws, 2, arRowCount);        // InvoiceNumber
                    Text(ws, 3, arRowCount);        // InvoiceDate
                    Text(ws, 5, arRowCount);        // Notes
                    Money(ws, 4, arRowCount);
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
