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

            RegularPay = 0;
            OverTimePay = 0;
            HolidayPay = 0;
            VacationPay = 0;
            EPSLPay = 0;
            OtherPay = 0;
            GrossPay = 0;
            Commission = 0;
            C401K = 0;
            E401K = 0;
            E401KLoan = 0;
            CHealthIns = 0;
            EHealthIns = 0;
            CVisionIns = 0;
            EVisionIns = 0;
            CDentalIns = 0;
            EDentalIns = 0;
            ChildSupState = 0;
            ChildSupOutState = 0;
            Garnishment = 0;
            COASDI = 0;
            EOASDI = 0;
            CHI = 0;
            EHI = 0;
            EFWH = 0;
            CFUTA = 0;
            CSUTA = 0;
            Uniform = 0;
            ChildSupAnnualFee = 0;
            Loan = 0;
            PayrollCharge = 0;
            NetPay = 0;
            DirectDeposit = 0;
            EPSLCredit = 0;
            CheckPay = 0;
            PayrollDate = DateOnly.FromDateTime(DateTime.UtcNow);
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PayrollServiceId { get; set; }

        public int PayrollNumber { get; set; }

        public DateOnly? PayrollDate { get; set; }

        public DateOnly? PayrollStartDate { get; set; }

        public DateOnly? PayrollEndDate { get; set; }

        public int? FromAccountId { get; set; }

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

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
