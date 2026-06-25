using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class MarketSyncLogList
    {
        [Key]
        public int MarketSyncLogId { get; set; }
        public int MarketAccountId { get; set; }
        public string? AccountName { get; set; }
        public string SyncType { get; set; } = string.Empty;
        public DateTime StartedAt { get; set; }
        public DateTime? FinishedAt { get; set; }
        public bool? Success { get; set; }
        public int? RecordsProcessed { get; set; }
        public int? RecordsSucceeded { get; set; }
        public int? RecordsFailed { get; set; }
        public string? ReferenceNo { get; set; }
        public string? ErrorMessage { get; set; }
    }
}
