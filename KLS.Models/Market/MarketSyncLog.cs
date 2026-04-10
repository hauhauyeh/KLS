using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketSyncLog
    {
        public MarketSyncLog()
        {
            this.CreatedAt = DateTime.UtcNow;
            this.StartedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int MarketSyncLogId { get; set; }

        public int MarketAccountId { get; set; }

        [Required]
        [StringLength(50)]
        public string SyncType { get; set; } = string.Empty;

        public DateTime StartedAt { get; set; }
        public DateTime? FinishedAt { get; set; }

        public bool? Success { get; set; }
        public int? RecordsProcessed { get; set; }
        public int? RecordsSucceeded { get; set; }
        public int? RecordsFailed { get; set; }

        [StringLength(100)]
        public string? ReferenceNo { get; set; }

        public string? ErrorMessage { get; set; }
        public string? PayloadSummary { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
