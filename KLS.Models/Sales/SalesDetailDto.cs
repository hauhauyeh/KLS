using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesDetailDto
    {
        public string? PayeeName { get; set; }

        public SalesList? Sales { get; set; }

        public string? SalesDisplayNumber { get; set; }

        public ICollection<SalesDetailList>? SalesDetails { get; set; }

        /// <summary>2026-08-29: was IsPriceZero (MGP zero-price flag, never set). Order waits for the scheduled price update.</summary>
        public bool IsPricePending { get; set; }

        /// <summary>Day name of the scheduled price update (SchedulerConfig), for the confirmation banner.</summary>
        public string? PriceUpdateDayName { get; set; }
    }
}
