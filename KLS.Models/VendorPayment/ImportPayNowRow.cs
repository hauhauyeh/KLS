using System;
using System.Collections.Generic;

namespace KLS.Models
{
    public class ImportPayNowRow
    {
        public int RowNo { get; set; }

        public string? AccountCode { get; set; }

        /// <summary>Account name as resolved from the database, not as typed in the spreadsheet.</summary>
        public string? AccountName { get; set; }

        public decimal? PmtAmount { get; set; }

        public string? Note { get; set; }

        /// <summary>"Ok" | "Warning" | "Error"</summary>
        public string Status { get; set; } = ImportPayNowStatus.Ok;

        public List<string> Messages { get; set; } = new();
    }
}
