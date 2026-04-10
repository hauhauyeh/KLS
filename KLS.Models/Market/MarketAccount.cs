using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketAccount
    {
        public MarketAccount()
        {
            this.CreatedAt = DateTime.UtcNow;
            this.IsActive = true;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int MarketAccountId { get; set; }

        [Required]
        [StringLength(50)]
        public string MarketType { get; set; } = string.Empty;

        [Required]
        [StringLength(200)]
        public string AccountName { get; set; } = string.Empty;

        [StringLength(100)]
        public string? StoreCode { get; set; }

        [StringLength(50)]
        public string? RegionCode { get; set; }

        [StringLength(500)]
        public string? ApiBaseUrl { get; set; }

        public string? SettingsJson { get; set; }

        public bool IsActive { get; set; }
        public DateTime? LastSyncAt { get; set; }

        [StringLength(20)]
        public string? LastSyncStatus { get; set; }

        [StringLength(1000)]
        public string? LastError { get; set; }

        [StringLength(500)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
