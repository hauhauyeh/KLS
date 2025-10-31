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
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int ItemId { get; set; }

        public string? ItemType { get; set; }

        [StringLength(50, MinimumLength = 2, ErrorMessage = "Minimum 2 characters required")]
        [RegularExpression(@"(?!^\d+$)^[a-zA-Z0-9-_]*$", ErrorMessage = "!,$,+,Space,w,r,h,x are Not Allowed.")]
        [Required(ErrorMessage = "Enter Code")]
        public string? ItemCode { get; set; }
        public string? BarcodeW { get; set; }
        public string? BarcodeR { get; set; }

        public int? CategoryId { get; set; }
        public int? StorageId { get; set; }

        public string? ItemName { get; set; }
        public string? ItemSearchTag { get; set; }
        public string? ItemForeignName { get; set; }
        public string? ItemLongDesc { get; set; }
        public string? ItemBoxDesc { get; set; }
        public string? ItemBrand { get; set; }
        public string? Notes { get; set; }

        public string? PackSize { get; set; }
        public string? Pack1 { get; set; }
        public string? Pack2 { get; set; }

        public string? DefaultUnit { get; set; }
        public string? WholeUnit { get; set; }
        public string? DisplayUnit { get; set; }
        public string? RetailUnit { get; set; }

        public decimal? RetailFactor { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? RetailProfitPercent { get; set; }

        public decimal? RetailPrice { get; set; }
        public decimal? DefaultCostB4 { get; set; }
        public decimal? DefaultCost { get; set; }
        public decimal? FreightCost { get; set; }
        public decimal? RecentCostB4 { get; set; }
        public decimal? RecentCost { get; set; }
        public int? CostIntervalDays { get; set; }
        public decimal? P1 { get; set; }
        public decimal? MSRP { get; set; }
        public decimal? LCloseQty { get; set; }
        public decimal? LAvgCost { get; set; }
        public decimal? LInventoryValue { get; set; }

        public DateOnly? ExpiryDate { get; set; }

        public int? PreferredVendorId { get; set; }
        public decimal? PaletteFactor { get; set; }
        public decimal? SaftyInventory { get; set; }
        public decimal? CaseWeight { get; set; }
        public decimal? CaseVolume { get; set; }
        public decimal? CaseLength { get; set; }
        public decimal? CaseWidth { get; set; }
        public decimal? CaseHeight { get; set; }

        public string? AisleNumber { get; set; }
        public string? BayNumber { get; set; }

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
        public bool IsLabelPrint { get; set; }
        public bool IsImport { get; set; }
        public bool IsSameDayReturn { get; set; }

        public decimal? Last3M { get; set; }
        public decimal? M0 { get; set; }
        public decimal? M1 { get; set; }
        public decimal? M2 { get; set; }
        public decimal? M3 { get; set; }
        public decimal? M4 { get; set; }
        public decimal? M5 { get; set; }
        public decimal? M6 { get; set; }

        public decimal? YTD { get; set; }
        public decimal? YTDSalesPercent { get; set; }
        public decimal? FutureQty { get; set; }
        public decimal? TodayOpenInventory { get; set; }
        public decimal? TCost1 { get; set; }
        public decimal? TCost2 { get; set; }
        public decimal? NCost1 { get; set; }
        public decimal? NCost2 { get; set; }

        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
