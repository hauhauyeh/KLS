using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Dtos
{
    public class MarketAccountDto
    {
        public int MarketAccountId { get; set; }
        public string MarketType { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        public string? StoreCode { get; set; }
        public string? RegionCode { get; set; }
        public string? ApiBaseUrl { get; set; }
        public bool HasCredentials { get; set; }
        public bool IsActive { get; set; }
        public DateTime? LastSyncAt { get; set; }
        public string? LastSyncStatus { get; set; }
        public string? LastError { get; set; }
        public string? Notes { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
