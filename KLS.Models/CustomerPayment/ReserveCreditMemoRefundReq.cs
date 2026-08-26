using System;
using System.Collections.Generic;

namespace KLS.Models
{
    public class ReserveCreditMemoRefundReq
    {
        public int PayeeId { get; set; }

        public List<int> SalesIds { get; set; } = new();

        public DateOnly? PaymentDate { get; set; }

        public string? Notes { get; set; }
    }
}
