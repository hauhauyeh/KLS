using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketOrderItem
    {
        public MarketOrderItem()
        {
            this.CreatedAt = DateTime.UtcNow;
            this.MatchStatus = "unmatched";
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int MarketOrderItemId { get; set; }

        public int MarketOrderId { get; set; }

        [StringLength(100)]
        public string? ExternalLineId { get; set; }

        [StringLength(100)]
        public string? ExternalSku { get; set; }

        [StringLength(200)]
        public string? ExternalListingId { get; set; }

        [StringLength(200)]
        public string? ExternalVariantId { get; set; }

        [StringLength(500)]
        public string? ExternalItemName { get; set; }

        public int? ItemId { get; set; }
        public int? ItemUnitId { get; set; }
        public int? MarketItemMapId { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal Qty { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? UnitPrice { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? DiscountAmount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? TaxAmount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? LineTotal { get; set; }

        [Required]
        [StringLength(20)]
        public string MatchStatus { get; set; } = "unmatched";

        [StringLength(500)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
