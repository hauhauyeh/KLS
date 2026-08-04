using KLS.Models;
using System;
using System.Collections.Generic;

namespace KLS.Contract.Interfaces
{
    public interface IOpenBalanceRepository
    {
        /// <summary>Read-only. One row per section: counts, totals, posted state, variance.</summary>
        List<OpenBalanceCardRow> GetStatus();

        /// <summary>
        /// Read-only parse of one section's workbook. Also returns the download
        /// stamp from the Instructions sheet, or null when the file was not
        /// produced by us.
        /// </summary>
        List<OpenBalanceExcelRow> Preview(string filePath, OpenBalanceSection section, out DateTime? downloadedAt);

        /// <summary>
        /// Save and post one section in a single transaction. Returns the rows
        /// written and the rows that were there before.
        /// </summary>
        (int RowCount, int PriorRowCount) Import(string filePath, OpenBalanceSection section);

        /// <summary>Remove one section's journal. The saved rows are left alone.</summary>
        void Unpost(OpenBalanceSection section);

        /// <summary>The saved rows for one section, shaped for the download workbook.</summary>
        List<OpenBalanceExcelRow> GetSectionRows(OpenBalanceSection section);
    }
}
