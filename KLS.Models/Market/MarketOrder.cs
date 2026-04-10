using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketOrder
    {
        public MarketOrder()
        {
            this.CreatedAt = DateTime.UtcNow;
            this.OrderStatus = "pending";
            this.ImportedToErp = false;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int MarketOrderId { get; set; }

        public int MarketAccountId { get; set; }

        [Required]
        [StringLength(100)]
        public string ExternalOrderId { get; set; } = string.Empty;

        [StringLength(100)]
        public string? ExternalOrderNo { get; set; }

        [StringLength(100)]
        public string? ExternalCustomerId { get; set; }

        public DateTime? OrderDate { get; set; }

        [Required]
        [StringLength(50)]
        public string OrderStatus { get; set; } = "pending";

        [StringLength(200)]
        public string? CustomerName { get; set; }

        [StringLength(200)]
        public string? CustomerEmail { get; set; }

        [StringLength(50)]
        public string? Phone { get; set; }

        [StringLength(200)]
        public string? ShipToName { get; set; }

        [StringLength(200)]
        public string? ShipToCompany { get; set; }

        [StringLength(255)]
        public string? ShipToAddress1 { get; set; }

        [StringLength(255)]
        public string? ShipToAddress2 { get; set; }

        [StringLength(100)]
        public string? ShipToCity { get; set; }

        [StringLength(100)]
        public string? ShipToState { get; set; }

        [StringLength(30)]
        public string? ShipToPostalCode { get; set; }

        [StringLength(100)]
        public string? ShipToCountry { get; set; }

        [StringLength(10)]
        public string? CurrencyCode { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? Subtotal { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? ShippingAmount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? TaxAmount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? DiscountAmount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? OrderTotal { get; set; }

        public int? ErpSalesId { get; set; }
        public bool ImportedToErp { get; set; }
        public DateTime? ImportedToErpAt { get; set; }

        public string? RawJson { get; set; }

        public DateTime? LastSyncAt { get; set; }

        [StringLength(20)]
        public string? LastSyncStatus { get; set; }

        [StringLength(1000)]
        public string? LastError { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<MarketOrderItem>? Items { get; set; }
    }
}
