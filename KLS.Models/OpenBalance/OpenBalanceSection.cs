using System;
using System.Collections.Generic;
using System.Linq;

namespace KLS.Models
{
    /// <summary>
    /// The five opening balance sections. Each one owns exactly one workbook,
    /// one staging table and one GeneralJournal number, and nothing in the
    /// system operates on more than one at a time.
    /// </summary>
    public enum OpenBalanceSection
    {
        Account = 1,
        AR = 2,
        AP = 3,
        INV = 4,
        ARE = 5
    }

    /// <summary>
    /// The single place section names, sheet names, staging tables, journal
    /// numbers and control accounts are mapped to each other. Everything else
    /// passes the enum around, so a section cannot be spelled correctly in one
    /// layer and wrongly in another.
    /// </summary>
    public sealed class OpenBalanceSectionInfo
    {
        public OpenBalanceSection Section { get; init; }

        /// <summary>Token passed to the stored procedures.</summary>
        public string Token { get; init; } = "";

        /// <summary>
        /// The worksheet the workbook must contain. Deliberately NOT derived
        /// from Token -- they differ (ACCOUNT/Account, INV/Inventory) and a
        /// clever derivation would silently break the parser. These strings
        /// must match the [Sheet$] literals in OpenBalance_ImportPreview and
        /// OpenBalance_Import exactly.
        /// </summary>
        public string SheetName { get; init; } = "";

        /// <summary>What a user calls it. Used on cards, dialogs and messages.</summary>
        public string DisplayName { get; init; } = "";

        /// <summary>Suggested download file name, without extension.</summary>
        public string FileName { get; init; } = "";

        public int GJNumber { get; init; }

        /// <summary>
        /// The control account this section is checked against, or null for
        /// Account -- that section holds the targets, it is not one of them.
        /// </summary>
        public string? ControlCode { get; init; }

        /// <summary>Column headers, in sheet order. The parser reads by position.</summary>
        public string[] Columns { get; init; } = Array.Empty<string>();

        public static readonly IReadOnlyList<OpenBalanceSectionInfo> All = new[]
        {
            new OpenBalanceSectionInfo
            {
                Section = OpenBalanceSection.Account,
                Token = "ACCOUNT",
                SheetName = "Account",
                DisplayName = "Trial Balance",
                FileName = "OpeningBalance_Account",
                GJNumber = 1,
                ControlCode = null,
                Columns = new[] { "AccountCode", "AccountName", "Balance", "Notes" }
            },
            new OpenBalanceSectionInfo
            {
                Section = OpenBalanceSection.AR,
                Token = "AR",
                SheetName = "AR",
                DisplayName = "Customer AR",
                FileName = "OpeningBalance_AR",
                GJNumber = -1,
                ControlCode = "@AR",
                Columns = new[] { "PayeeId", "CustomerName", "InvoiceNumber", "Amount", "Notes" }
            },
            new OpenBalanceSectionInfo
            {
                Section = OpenBalanceSection.AP,
                Token = "AP",
                SheetName = "AP",
                DisplayName = "Vendor AP",
                FileName = "OpeningBalance_AP",
                GJNumber = -2,
                ControlCode = "@AP",
                Columns = new[] { "PayeeId", "VendorName", "BillNumber", "Amount", "Notes" }
            },
            new OpenBalanceSectionInfo
            {
                Section = OpenBalanceSection.INV,
                Token = "INV",
                SheetName = "Inventory",
                DisplayName = "Inventory",
                FileName = "OpeningBalance_Inventory",
                GJNumber = -3,
                ControlCode = "@INV",
                Columns = new[] { "ItemCode", "ItemName", "Qty", "Price", "TotalValue", "Notes" }
            },
            new OpenBalanceSectionInfo
            {
                Section = OpenBalanceSection.ARE,
                Token = "ARE",
                SheetName = "ARE",
                DisplayName = "Employee AR",
                FileName = "OpeningBalance_ARE",
                GJNumber = -4,
                ControlCode = "@ARE",
                Columns = new[] { "PayeeId", "EmployeeName", "Amount", "Notes" }
            }
        };

        public static OpenBalanceSectionInfo Get(OpenBalanceSection section)
        {
            var info = All.FirstOrDefault(s => s.Section == section);

            if (info == null)
                throw new ArgumentException($"Unknown opening balance section '{section}'.");

            return info;
        }
    }
}
