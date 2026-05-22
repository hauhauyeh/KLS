using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CreateGatewayPaymentReq
    {
        public int PayeeId { get; set; }

        public string PaymentMethod { get; set; } = string.Empty;

        public string? ReferenceId { get; set; }

        public decimal PaymentAmount { get; set; }

        /// <summary>
        /// Comma separated Sales IDs (e.g., "101,102,103")
        /// </summary>
        public string SalesIds { get; set; } = string.Empty;

        public string? Gateway { get; set; }

        public decimal CCFee { get; set; }

        public string? CardType { get; set; }

        public string? Last4 { get; set; }

        /// <summary>
        /// Optional user-entered note, forwarded from PaymentChargeReq.Notes.
        /// Distinct from the auto-generated Gateway label so the SP can
        /// compose the final Notes string deterministically.
        /// </summary>
        public string? UserNotes { get; set; }
    }
}
