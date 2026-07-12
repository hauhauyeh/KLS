using System.Collections.Generic;

namespace KLS.Models
{
    public class ImportPayNowPreviewRes
    {
        /// <summary>Names the uploaded workbook on disk. Post it back to ImportPayNow to commit.</summary>
        public string UploadToken { get; set; } = string.Empty;

        public string FileName { get; set; } = string.Empty;

        /// <summary>Excel data rows. Not the number of payments -- see BatchCount.</summary>
        public int TotalRows { get; set; }

        /// <summary>Number of vendor payments this file will create. This is what the importer returns as @TxCount.</summary>
        public int BatchCount { get; set; }

        public decimal TotalAmount { get; set; }

        /// <summary>True when any batch is in Error. The import is refused, client-side and server-side.</summary>
        public bool HasErrors { get; set; }

        public List<ImportPayNowBatch> Batches { get; set; } = new();
    }
}
