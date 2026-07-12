using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    /// <summary>
    /// Parameter object for [VendorPayment_Import]. No longer bound from a form:
    /// the workbook arrives via ImportPayNowPreviewReq and is referenced afterwards
    /// by the upload token, which resolves to FilePath.
    /// </summary>
    public class ImportPayNow
    {
        public string? PaymentMethod { get; set; }

        public int? FromAccountId { get; set; }

        public string? FilePath { get; set; }
    }
}
