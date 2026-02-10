using IronPdf;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public sealed class PdfGenerationResult
    {
        public PdfDocument Pdf { get; init; } = default!;

        public string RelativePath { get; init; } = string.Empty;

        public string FullPath { get; set; } = string.Empty;

        public bool IsBOL { get; init; }
    }
}
