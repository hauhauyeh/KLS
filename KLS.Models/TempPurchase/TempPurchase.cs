using KLS.Common;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempPurchase
    {
        public TempPurchase()
        {
            ChangeStatus = EnumHelper.ChangeStatus.I.ToString();
            LineType = EnumHelper.LineType.I.ToString();
            FactorToBase = 1;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempPurchaseId { get; set; }

        public int EmpId { get; set; }
        public int PayeeId { get; set; }
        public int PurchaseId { get; set; }
        public int? LineId { get; set; }
        public string? LineType { get; set; }

        public int? ItemId { get; set; }
        public int? AccountId { get; set; }
        public int? ItemUnitId { get; set; }
        public string? Unit { get; private set; }
        public string? Notes { get; set; }

        public bool IsFree { get; private set; }
        public bool IsOut { get; private set; }
        public bool IsCRCG { get; private set; }

        public decimal? OrdQty0 { get; private set; }
        public decimal? OrdQty1 { get; private set; }

        public decimal? ShipQty { get; private set; }
        public decimal? BillQty { get; private set; }
        public decimal? ReceiveQty { get; private set; }
        public decimal? FinalQty { get; private set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? BillPrice { get; private set; }
        [Column(TypeName = "decimal(18,4)")]
        public decimal? FinalPrice { get; private set; }

        public decimal? ImportCommission { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        public DateOnly? ExpiryDate { get; private set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? DiscountPercent { get; private set; }
        public decimal? Discount { get; private set; }
        [Column(TypeName = "decimal(18,4)")]
        public decimal? OrgPrice { get; private set; }


        [Column(TypeName = "decimal(18,6)")]
        public decimal? CustomDutyRate { get; set; }

        [Column(TypeName = "decimal(9,4)")]
        public decimal? TariffPercent { get; set; }

        //[Column(TypeName = "decimal(18,6)")]
        //public decimal? DutySharePercent { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? ItemVolume { get; set; }

        //[Column(TypeName = "decimal(18,6)")]
        //public decimal? VolumeSharePercent { get; set; }


        public string? ChangeStatus { get; set; }
        public int? PurchaseDetailId { get; set; }

        public decimal? BillExtTotal => Utilities.Rounding((BillQty ?? 0m) * (BillPrice ?? 0m), 2);

        public decimal? FinalExtTotal => Utilities.Rounding((FinalQty ?? 0m) * (FinalPrice ?? 0m), 2);


        public void ApplyCommonEdits(bool isFree, bool isOut, bool isCrcg, decimal? billPrice, decimal? finalPrice, string? notes, DateOnly? expiryDate)
        {
            ApplyFlags(isFree, isOut, isCrcg);
            ApplyPrices(billPrice, finalPrice);
            ApplyMetadata(notes, expiryDate);
        }

        public void ApplyPrices(decimal? billPrice, decimal? finalPrice)
        {
            BillPrice = billPrice;
            FinalPrice = finalPrice;
        }

        public void ApplyFlags(bool isFree, bool isOut, bool isCrcg)
        {
            IsFree = isFree;
            IsOut = isOut;
            IsCRCG = isCrcg;
        }

        public void ApplyMetadata(string? notes, DateOnly? expiryDate)
        {
            Notes = notes;
            ExpiryDate = expiryDate;
        }

        // PO: only ordered qty changes (and flags/notes/expiry/etc)
        public void ApplyPO(decimal? ordQty0, decimal? ordQty1, decimal? shipQty)
        {
            ApplyPOQuantities(ordQty0, ordQty1, shipQty);
        }

        // Bill:
        public void ApplyBill(decimal? ordQty0, decimal? ordQty1)
        {
            ApplyBillQuantities(ordQty0, ordQty1);
        }

        public void ApplyPOQuantities(decimal? ordQty0, decimal? ordQty1, decimal? shipQty)
        {
            OrdQty0 = ordQty0;
            OrdQty1 = ordQty1;

            ShipQty = shipQty;
            BillQty = shipQty;

            ApplyFlagRules(docType: EnumHelper.PurchaseDocType.PO);
        }

        public void ApplyBillQuantities(decimal? ordQty0, decimal? ordQty1)
        {
            OrdQty0 = ordQty0;
            OrdQty1 = ordQty1;

            ApplyFlagRules(docType: EnumHelper.PurchaseDocType.Bill);
        }

        public void ApplyUnit(string unit, int? itemUnitId, decimal? factorToBase)
        {
            Unit = unit;
            ItemUnitId = itemUnitId;
            FactorToBase = factorToBase;
        }

        public void MarkChangeStatus(string changeStatus)
        {
            if (PurchaseDetailId.HasValue)
                ChangeStatus = EnumHelper.ChangeStatus.U.ToString();
            else
                ChangeStatus = changeStatus;
        }

        private void ApplyFlagRules(EnumHelper.PurchaseDocType docType)
        {
            if (docType == EnumHelper.PurchaseDocType.Bill)
            {
                if (IsFree)
                {
                    ShipQty = OrdQty0;
                    BillQty = 0;
                    ReceiveQty = OrdQty1;
                    FinalQty = 0;
                }
                else if (IsOut)
                {
                    ShipQty = 0;
                    BillQty = 0;
                    ReceiveQty = 0;
                    FinalQty = 0;
                }
                else if (IsCRCG)
                {
                    ShipQty = 0;
                    BillQty = OrdQty0;
                    ReceiveQty = 0;
                    FinalQty = OrdQty1;
                }
                else
                {
                    ShipQty = OrdQty0;
                    BillQty = OrdQty0;
                    ReceiveQty = OrdQty1;
                    FinalQty = OrdQty1;
                }
            }
            else
            {

            }
        }

        //private void Validate(PurchaseDocType docType)
        //{
        //    if (docType == PurchaseDocType.PO)
        //    {
        //        // PO should not carry bill/final quantities
        //        if ((ReceiveQty ?? 0) != 0 || (FinalQty ?? 0) != 0)
        //            throw new InvalidOperationException("PO cannot have ReceiveQty/FinalQty.");
        //    }
        //}
    }
}
