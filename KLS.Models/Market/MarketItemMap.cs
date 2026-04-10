using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketItemMap
    {
        public MarketItemMap()
        {
            this.CreatedAt = DateTime.UtcNow;
            this.IsActive = true;
            this.MappingStatus = "mapped";
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int MarketItemMapId { get; set; }

        public int MarketAccountId { get; set; }
        public int ItemId { get; set; }
        public int? ItemUnitId { get; set; }

        [StringLength(100)]
        public string? ExternalSku { get; set; }

        [StringLength(200)]
        public string? ExternalListingId { get; set; }

        [StringLength(200)]
        public string? ExternalVariantId { get; set; }

        [StringLength(500)]
        public string? ExternalItemName { get; set; }

        [Required]
        [StringLength(20)]
        public string MappingStatus { get; set; } = "mapped";

        public bool IsActive { get; set; }
        public DateTime? LastSyncAt { get; set; }

        [StringLength(20)]
        public string? LastSyncStatus { get; set; }

        [StringLength(1000)]
        public string? LastError { get; set; }

        // Dedicated sync timestamps for price and inventory (Phase 5)
        public DateTime? LastPriceSyncAt { get; set; }
        [StringLength(20)]
        public string? LastPriceSyncStatus { get; set; }
        public DateTime? LastInventorySyncAt { get; set; }
        [StringLength(20)]
        public string? LastInventorySyncStatus { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        [NotMapped] public string? ItemCode { get; set; }
        [NotMapped] public string? ItemName { get; set; }
        [NotMapped] public string? AccountName { get; set; }
    }
}
