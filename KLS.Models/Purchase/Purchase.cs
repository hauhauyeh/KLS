using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Purchase
    {
        public Purchase()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public int? StageId { get; set; }

        public int? PayeeId { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        public DateOnly? EnterDate { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public DateOnly? InvoiceDate { get; set; }

        public string? VendorDocNumber { get; set; }

        public string? ContainerNumber { get; set; }

        public int? TermId { get; set; }

        public decimal? VendorTotal { get; set; }

        public decimal? PurchaseTotal { get; set; }

        public decimal? AmountDue { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? DiscountApplied { get; set; }

        public int? Aging { get; set; }

        public int? InvoiceAging { get; set; }

        public DateOnly? DueDate { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public bool IsStartFromPO { get; set; }

        public bool IsFreightOnly { get; set; }

        public decimal? FreightInside { get; set; }

        public decimal? FreightOutside { get; set; }

        [DatabaseGenerated(DatabaseGeneratedOption.Computed)]
        public decimal? FreightTotal { get; set; }

        public decimal? CustomDutyInside { get; set; }

        public decimal? CustomDutyOutside { get; set; }

        [DatabaseGenerated(DatabaseGeneratedOption.Computed)]
        public decimal? CustomDutyTotal { get; set; }

        public decimal? ImportCommission { get; set; }

        public int? PalletCount { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        [NotMapped]
        public bool IsBillStage => StageId == 6;
    }
}


