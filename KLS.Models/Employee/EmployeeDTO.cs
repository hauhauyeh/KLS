using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmployeeDTO
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? Address { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? PhoneDesc1 { get; set; }

        public string? Phone1 { get; set; }

        public string? PhoneDesc2 { get; set; }

        public string? Phone2 { get; set; }

        public string? PhoneDesc3 { get; set; }

        public string? Phone3 { get; set; }

        public string? PhoneDesc4 { get; set; }

        public string? Phone4 { get; set; }

        public bool IsClosed { get; set; }

        public DateTime? StartDate { get; set; }

        public decimal? Balance { get; set; }

        public string? Notes { get; set; }


        public string? FirstName { get; set; }

        public string? MiddleName { get; set; }

        public string? LastName { get; set; }

        public string? Department { get; set; }

        public string? EmploymentType { get; set; }

        public string? SSN { get; set; }

        public DateTime? DOB { get; set; }

        public string? DLN { get; set; }

        public int? PayFreq { get; set; }

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

        public decimal? HealthIns { get; set; }

        public decimal? VisionIns { get; set; }

        public decimal? DentalIns { get; set; }

        public decimal? ChildSup1 { get; set; }

        public decimal? ChildSup2 { get; set; }

        public decimal? ChildSup3 { get; set; }

        public decimal? ChildSup4 { get; set; }

        public decimal? ChildSup5 { get; set; }

        public bool IsUsePayCheck { get; set; }

        public bool IsRestricted { get; set; }

        public bool IsShowPastDueWarning { get; set; }

        public bool IsTextPriceChange { get; set; }

        public bool IsService { get; set; }


        public string? Username { get; set; }

        public string? Password { get; set; }

        public int RoleId { get; set; }
    }
}
