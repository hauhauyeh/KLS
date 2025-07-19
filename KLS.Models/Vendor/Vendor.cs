using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Vendor
    {
        public int PayeeId { get; set; }

        public string PmtCompany { get; set; }

        public string? PmtAddress { get; set; }

        public string? PmtCity { get; set; }

        public string? PmtState { get; set; }

        public string? PmtZipCode { get; set; }

        public string? AccountNumber { get; set; }

        public string? RoutingNumber { get; set; }

        public decimal? FreightRate { get; set; }

        public decimal? InterestRate { get; set; }

        public string? PmtSchedule1 { get; set; }

        public string? PmtSchedule2 { get; set; }

        public string? AcctCode1 { get; set; }

        public string? AcctCode2 { get; set; }

        public string? AcctCode3 { get; set; }

        public string? AcctCode4 { get; set; }

        public string? AcctCode5 { get; set; }

        public string? AcctCode6 { get; set; }

        public string? DefaultPmtMethod { get; set; }

        public bool IsShippingCarrier { get; set; }

        public bool IsVisibleToAdmin { get; set; }
    }
}
