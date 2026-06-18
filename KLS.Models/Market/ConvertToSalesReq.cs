using System;

namespace KLS.Models
{
    public class ConvertToSalesReq
    {
        public int MarketAccountId { get; set; }
        public DateOnly OrderDate { get; set; }
    }
}
