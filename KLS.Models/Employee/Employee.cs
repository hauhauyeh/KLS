using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Employee
    {
        [Key]
        public int PayeeId { get; set; }

        public string? FirstName { get; set; }

        public string? MiddleName { get; set; }

        public string? LastName { get; set; }

        public string? Department { get; set; }

        public string? EmploymentType { get; set; }

        public string? SSN { get; set; }

        public DateTime? DOB { get; set; }

        public string? DLN { get; set; }

        public int? PayFrequency { get; set; }

        public string? HourOrSalary { get; set; }

        public decimal? Rate { get; set; }

        public string? SingleOrMarried { get; set; }

        public int? W4Exempt { get; set; }

        public decimal? K401 { get; set; }

        public decimal? IRA { get; set; }

        public decimal? RothIRA { get; set; }

        public decimal? R1 { get; set; }

        public decimal? R2 { get; set; }

        public decimal? R3 { get; set; }

        public decimal? HealthInsurance { get; set; }

        public decimal? VisionInsurance { get; set; }

        public decimal? DentalInsurance { get; set; }

        public decimal? ChildSupport1 { get; set; }

        public decimal? ChildSupport2 { get; set; }

        public decimal? ChildSupport3 { get; set; }

        public decimal? ChildSupport4 { get; set; }

        public decimal? ChildSupport5 { get; set; }

        public bool IsUsePayCheck { get; set; }

        public bool HasOutsideAccess { get; set; }

        public bool HasPastDueWarning { get; set; }

        public bool IsPriceChangeNotify { get; set; }

        public bool IsService { get; set; }
    }
}
