using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempPayrollDetail
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempPayrollId { get; set; }

        public int EmpId { get; set; }

        public int VendorPaymentId { get; set; }

        public int PayeeId { get; set; }

        public bool IsApplied { get; set; }

        public DateOnly? PayPeriodStart { get; set; }

        public DateOnly? PayPeriodEnd { get; set; }

        public string? Notes { get; set; }

        public decimal? TotalHour { get; set; }

        public decimal? RegularHour { get; set; }

        public decimal? OvertimeHour { get; set; }

        public decimal? Rate { get; set; }

        public decimal? RegularWage { get; set; }

        public decimal? AddOvertime { get; set; }

        public decimal? AddSickLeave { get; set; }

        public decimal? AddVacation { get; set; }

        public decimal? AddCommission { get; set; }

        public decimal? AddBonus { get; set; }

        public decimal? GrossPay { get; set; }

        public decimal? PreTax401K { get; set; }

        public decimal? PreTaxIRA { get; set; }

        public decimal? PreTaxRouthIRA { get; set; }

        public decimal? PreTaxHealthIns { get; set; }

        public decimal? PreTaxVisionIns { get; set; }

        public decimal? PreTaxDentalIns { get; set; }

        public decimal? YearToDateFWH { get; set; }

        public decimal? YearToDateOASDI { get; set; }

        public decimal? YearToDateHI { get; set; }

        public decimal? YearToDateFUTA { get; set; }

        public decimal? YearToDateSUTA { get; set; }

        public decimal? YTDGross { get; set; }

        public decimal? YTDOASDI { get; set; }

        public decimal? YTDHI { get; set; }

        public decimal? YTDFWH { get; set; }

        public decimal? YTDNet { get; set; }

        public decimal? EmpOASDI { get; set; }

        public decimal? EmpHI { get; set; }

        public decimal? EmpFWH { get; set; }

        public decimal? CompanyOASDI { get; set; }

        public decimal? CompanyHI { get; set; }

        public decimal? CompanyFUTA { get; set; }

        public decimal? CompanySUTA { get; set; }

        public decimal? ChildSup1 { get; set; }

        public decimal? ChildSup2 { get; set; }

        public decimal? ChildSup3 { get; set; }

        public decimal? ChildSup4 { get; set; }

        public decimal? ChildSup5 { get; set; }

        public decimal? Garnishment { get; set; }

        public decimal? EmpBalance { get; set; }

        public decimal? LoanRepayment { get; set; }

        public decimal? Deduction { get; set; }

        public decimal? Reimbursement { get; set; }

        public decimal? NetPay { get; set; }

        public decimal? CashPay { get; set; }


        [ForeignKey("PayeeId")]
        [JsonIgnore]
        public virtual Payee? Payee { get; set; }

        [NotMapped]
        public string? PayeeName => Payee?.PayeeName;

        [NotMapped]
        public bool IsEmpFWHChange { get; set; }

        [NotMapped]
        public bool IsEmpOASDIChange { get; set; }

        [NotMapped]
        public bool IsEmpHIChange { get; set; }

        [NotMapped]
        public bool IsCOASDIChange { get; set; }

        [NotMapped]
        public bool IsCHIChange { get; set; }

        [NotMapped]
        public bool IsTotalHourChange { get; set; }

        [NotMapped]
        public bool IsRegularHourChange { get; set; }

        [NotMapped]
        public bool IsOTHourChange { get; set; }

        [NotMapped]
        public bool IsCFUTAChange { get; set; }

        [NotMapped]
        public bool IsCSUTAChange { get; set; }

        [NotMapped]
        public int PayOption { get; set; }

        [NotMapped]
        public DateOnly PayDate { get; set; }
    }
}
