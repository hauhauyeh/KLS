using ClosedXML.Excel;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace KLS.Services
{
    /// <summary>
    /// Reads a vendor price file into plain rows {RowNo, Code, Description, Price}.
    ///
    /// Two shapes:
    ///   .csv  the vendor's own list as received, e.g. Harvill's:
    ///           ,"HARVILL'S PRODUCE CO., INC.",
    ///           ,IN HOUSE,
    ///           ,08/25/26 thru 08/27/26,
    ///           PRODUCT,PRODUCT DESCRIPTION,PRICE
    ///           APPFUJIEA,APPLES FUJI                    EA,.80
    ///           POTDBL,"POTATO,RED DICED FRESH 1/ 20# TUB",MKT
    ///         Preamble is skipped by finding the header row whose first cell is
    ///         PRODUCT; without one, every row with a code is taken. Price is
    ///         the LAST column. Quotes are honoured (RFC 4180). The date range
    ///         in the preamble is captured when present.
    ///   .xlsx the template downloaded from Item_ImportCostTemplate. Columns are
    ///         located by header text, so order does not matter.
    ///
    /// Price is kept as text: "MKT" must reach SQL verbatim.
    /// </summary>
    public static class ItemCostImportFile
    {
        public const string SheetName = "Costs";

        private static readonly Regex DateRange = new(
            @"(\d{1,2}/\d{1,2}/\d{2,4})\s+thru\s+(\d{1,2}/\d{1,2}/\d{2,4})",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        private static readonly string[] CodeHeaders = { "Code", "VendorCode", "PRODUCT", "ItemCode" };
        private static readonly string[] DescriptionHeaders = { "Description", "PRODUCT DESCRIPTION", "ItemName" };
        private static readonly string[] PriceHeaders = { "NewCost", "Price", "PRICE", "Cost" };

        public sealed class Parsed
        {
            public List<ItemCostImportFileRow> Rows { get; } = new();

            /// <summary>yyyy-MM-dd or null.</summary>
            public string? EffectiveFrom { get; set; }

            public string? EffectiveTo { get; set; }
        }

        public static Parsed Parse(string path)
        {
            var extension = Path.GetExtension(path);

            if (string.Equals(extension, ".csv", StringComparison.OrdinalIgnoreCase))
                return ParseCsv(path);

            if (string.Equals(extension, ".xlsx", StringComparison.OrdinalIgnoreCase))
                return ParseXlsx(path);

            throw new ArgumentException("Only .csv and .xlsx files can be imported.");
        }

        #region --- CSV ---

        public static Parsed ParseCsv(string path)
        {
            var parsed = new Parsed();
            var records = ReadCsvRecords(path);

            // Header row: first record whose first cell is PRODUCT (any case).
            var headerIndex = records.FindIndex(r => r.Count > 0 && string.Equals(r[0].Trim(), "PRODUCT", StringComparison.OrdinalIgnoreCase));

            // Preamble: everything before the header (or the first coded row).
            var preambleEnd = headerIndex >= 0 ? headerIndex : records.FindIndex(r => r.Count > 0 && r[0].Trim().Length > 0);
            for (var i = 0; i < Math.Max(preambleEnd, 0); i++)
                CaptureDateRange(string.Join(",", records[i]), parsed);

            var rowNo = 0;
            for (var i = headerIndex + 1; i < records.Count; i++)
            {
                var cells = records[i];
                if (cells.Count == 0)
                    continue;

                var code = cells[0].Trim();
                var price = cells[cells.Count - 1].Trim();

                // Blank code AND blank price = decoration / empty line, not a row.
                if (code.Length == 0 && price.Length == 0)
                    continue;

                // Two cells = code,price with no description.
                var description = cells.Count > 2 ? cells[1].Trim() : "";

                // A quoted description that itself contained commas still parses
                // as one cell; a description with more than one middle cell
                // (rare, unquoted comma) is re-joined.
                if (cells.Count > 3)
                    description = string.Join(",", cells.Skip(1).Take(cells.Count - 2)).Trim();

                rowNo++;
                parsed.Rows.Add(new ItemCostImportFileRow(rowNo, code, CollapseSpaces(description), price));
            }

            return parsed;
        }

        /// <summary>Minimal RFC 4180 reader: quoted fields, doubled quotes, CR/LF/CRLF line ends.</summary>
        private static List<List<string>> ReadCsvRecords(string path)
        {
            var text = File.ReadAllText(path, DetectEncoding(path));
            var records = new List<List<string>>();
            var record = new List<string>();
            var field = new StringBuilder();
            var inQuotes = false;

            for (var i = 0; i < text.Length; i++)
            {
                var c = text[i];

                if (inQuotes)
                {
                    if (c == '"')
                    {
                        if (i + 1 < text.Length && text[i + 1] == '"')
                        {
                            field.Append('"');
                            i++;
                        }
                        else
                        {
                            inQuotes = false;
                        }
                    }
                    else
                    {
                        field.Append(c);
                    }

                    continue;
                }

                switch (c)
                {
                    case '"':
                        inQuotes = true;
                        break;

                    case ',':
                        record.Add(field.ToString());
                        field.Clear();
                        break;

                    case '\r':
                        if (i + 1 < text.Length && text[i + 1] == '\n')
                            i++;
                        goto case '\n';

                    case '\n':
                        record.Add(field.ToString());
                        field.Clear();
                        records.Add(record);
                        record = new List<string>();
                        break;

                    default:
                        field.Append(c);
                        break;
                }
            }

            if (field.Length > 0 || record.Count > 0)
            {
                record.Add(field.ToString());
                records.Add(record);
            }

            return records;
        }

        private static Encoding DetectEncoding(string path)
        {
            // UTF-8 BOM -> UTF-8; otherwise the vendor's Windows-1252-style
            // export. Latin1 never throws on a stray byte, and the fields that
            // matter (codes, prices) are ASCII either way.
            using var stream = File.OpenRead(path);
            var bom = new byte[3];
            var read = stream.Read(bom, 0, 3);

            if (read == 3 && bom[0] == 0xEF && bom[1] == 0xBB && bom[2] == 0xBF)
                return Encoding.UTF8;

            return Encoding.Latin1;
        }

        #endregion

        #region --- XLSX ---

        public static Parsed ParseXlsx(string path)
        {
            var parsed = new Parsed();

            using var workbook = new XLWorkbook(path);

            var ws = workbook.Worksheets.FirstOrDefault(w => w.Name == SheetName) ?? workbook.Worksheets.First();
            var headerRow = ws.Row(1);
            var lastColumn = ws.LastColumnUsed()?.ColumnNumber() ?? 0;

            var codeCol = FindColumn(headerRow, lastColumn, CodeHeaders);
            var descCol = FindColumn(headerRow, lastColumn, DescriptionHeaders);
            var priceCol = FindColumn(headerRow, lastColumn, PriceHeaders);

            if (codeCol == 0 || priceCol == 0)
                throw new ArgumentException($"The sheet needs a Code column and a NewCost column. Download the template and fill in NewCost.");

            var lastRow = ws.LastRowUsed()?.RowNumber() ?? 1;
            var rowNo = 0;

            for (var r = 2; r <= lastRow; r++)
            {
                var code = ws.Cell(r, codeCol).GetString().Trim();
                var price = ws.Cell(r, priceCol).GetString().Trim();

                // Template rows with nothing typed in NewCost are not rows.
                if (price.Length == 0)
                    continue;

                if (code.Length == 0 && price.Length == 0)
                    continue;

                var description = descCol > 0 ? ws.Cell(r, descCol).GetString().Trim() : "";

                rowNo++;
                parsed.Rows.Add(new ItemCostImportFileRow(rowNo, code, CollapseSpaces(description), price));
            }

            return parsed;
        }

        private static int FindColumn(IXLRow headerRow, int lastColumn, string[] names)
        {
            for (var c = 1; c <= lastColumn; c++)
            {
                var header = headerRow.Cell(c).GetString().Trim();

                if (names.Any(n => string.Equals(n, header, StringComparison.OrdinalIgnoreCase)))
                    return c;
            }

            return 0;
        }

        #endregion

        private static void CaptureDateRange(string line, Parsed parsed)
        {
            if (parsed.EffectiveFrom != null)
                return;

            var m = DateRange.Match(line);
            if (!m.Success)
                return;

            var from = ParseUsDate(m.Groups[1].Value);
            var to = ParseUsDate(m.Groups[2].Value);

            if (from == null || to == null)
                return;

            parsed.EffectiveFrom = from.Value.ToString("yyyy-MM-dd");
            parsed.EffectiveTo = to.Value.ToString("yyyy-MM-dd");
        }

        private static DateTime? ParseUsDate(string text)
        {
            string[] formats = { "M/d/yy", "MM/dd/yy", "M/d/yyyy", "MM/dd/yyyy" };

            return DateTime.TryParseExact(text, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
                ? d
                : null;
        }

        private static string CollapseSpaces(string text)
        {
            return Regex.Replace(text ?? "", @"\s{2,}", " ").Trim();
        }
    }
}
