using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayrollService
    {
        public PayrollService()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PayrollServiceId { get; set; }

        public int PayrollNumber { get; set; }

        public DateOnly? PayrollDate { get; set; }

        public DateOnly? PayrollStartDate { get; set; }

        public DateOnly? PayrollEndDate { get; set; }

        public string? FromAccount { get; set; }

        public decimal? RegularPay { get; set; }

        public decimal? OverTimePay { get; set; }

        public decimal? HolidayPay { get; set; }

        public decimal? VacationPay { get; set; }

        public decimal? EPSLPay { get; set; }

        public decimal? OtherPay { get; set; }

        public decimal? GrossPay { get; set; }

        public decimal? Commission { get; set; }

        public decimal? C401K { get; set; }

        public decimal? E401K { get; set; }

        public decimal? E401KLoan { get; set; }

        public decimal? CHealthIns { get; set; }

        public decimal? EHealthIns { get; set; }

        public decimal? CVisionIns { get; set; }

        public decimal? EVisionIns { get; set; }

        public decimal? CDentalIns { get; set; }

        public decimal? EDentalIns { get; set; }

        public decimal? ChildSupState { get; set; }

        public decimal? ChildSupOutState { get; set; }

        public decimal? Garnishment { get; set; }

        public decimal? COASDI { get; set; }

        public decimal? EOASDI { get; set; }

        public decimal? CHI { get; set; }

        public decimal? EHI { get; set; }

        public decimal? EFWH { get; set; }

        public decimal? CFUTA { get; set; }

        public decimal? CSUTA { get; set; }

        public decimal? Uniform { get; set; }

        public decimal? AdvancePay { get; set; }

        public decimal? ChildSupAnnualFee { get; set; }

        public decimal? Loan { get; set; }

        public decimal? PayrollCharge { get; set; }

        public decimal? NetPay { get; set; }

        public decimal? DirectDeposit { get; set; }

        public decimal? CheckPay { get; set; }

        public decimal? EPSLCredit { get; set; }

        public bool IsLocked { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
