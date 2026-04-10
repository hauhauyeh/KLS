using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Dtos
{
    public class MarketAccountSaveReq
    {
        public int MarketAccountId { get; set; }
        public string MarketType { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        public string? StoreCode { get; set; }
        public string? RegionCode { get; set; }
        public string? ApiBaseUrl { get; set; }
        public string? SettingsJson { get; set; }
        public bool IsActive { get; set; } = true;
        public string? Notes { get; set; }
    }
}
