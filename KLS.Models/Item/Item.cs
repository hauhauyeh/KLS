using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Item
    {
        public Item()
        {
            this.CreatedAt = DateTime.UtcNow;
            this.ItemCode = string.Empty;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int ItemId { get; set; }
        public string? ItemType { get; set; }

        [StringLength(50, MinimumLength = 2, ErrorMessage = "Minimum 2 characters required")]
        [RegularExpression(@"(?!^\d+$)^[a-zA-Z0-9-_]*$", ErrorMessage = "!,$,+,Space,w,r are Not Allowed.")]
        [Required(ErrorMessage = "Enter Code")]
        public string ItemCode { get; set; } = string.Empty;
        public string? ItemName { get; set; }
        public string? ItemName2 { get; set; }
        public string? ItemSearchTag { get; set; }
        public string? ItemLongDesc { get; set; }
        public string? ItemBoxDesc { get; set; }
        public string? ItemBrand { get; set; }
        public string? SetPacking { get; set; }
        public string? PackSize { get; set; }

        public int? CategoryId { get; set; }
        public int? StorageId { get; set; }
        public int? PreferredVendorId { get; set; }

        public decimal? PaletteFactor { get; set; }
        public decimal? SaftyInventory { get; set; }
        public decimal? ActualSaftyInventory { get; set; }
        public decimal? RefillInventory { get; set; }

        public bool IsWeightItem { get; set; }
        public bool IsMetricWeight { get; set; }
        public bool IsMetricDimension { get; set; }

        public decimal? CaseWeight { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? CaseLength { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? CaseWidth { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? CaseHeight { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? CaseVolumeInCubicFeet { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? CaseVolumeInCubicMeter { get; set; }

        public bool IsVolumeManual { get; set; }

        [Column(TypeName = "decimal(18, 6)")]
        public decimal? LCloseQty { get; set; }

        [Column(TypeName = "decimal(18, 6)")]
        public decimal? LAvgCost { get; set; }

        [Column(TypeName = "decimal(18, 6)")]
        public decimal? LInventoryValue { get; set; }

        [Column(TypeName = "decimal(18, 6)")]
        public decimal? FutureQty { get; set; }

        [Column(TypeName = "decimal(18, 6)")]
        public decimal? TodayOpenInventory { get; set; }

        public DateTime? ExpiryDate { get; set; }

        public int? IncomeAccountId { get; set; }
        public int? ExpenseAccountId { get; set; }
        public int? COGSAccountId { get; set; }
        public int? InventoryAccountId { get; set; }

        public bool Inactive { get; set; }
        public bool IsDeleted { get; set; }
        public bool IsTaxable { get; set; }
        public bool IsHRExempt { get; set; }
        public bool IsHighlighted { get; set; }
        public bool IsCostChange { get; set; }
        public bool IsImport { get; set; }

        public decimal? Last3M { get; set; }
        public decimal? M0 { get; set; }
        public decimal? M1 { get; set; }
        public decimal? M2 { get; set; }
        public decimal? M3 { get; set; }
        public decimal? M4 { get; set; }
        public decimal? M5 { get; set; }
        public decimal? M6 { get; set; }

        public decimal? YTD { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? YTDSalesPercent { get; set; }

        public decimal? TCost1 { get; set; }
        public decimal? TCost2 { get; set; }
        public decimal? NCost1 { get; set; }
        public decimal? NCost2 { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<ItemUnit>? ItemUnits { get; set; }

        [NotMapped]
        public decimal? DefaultRetailPercent { get; set; }
    }
}
