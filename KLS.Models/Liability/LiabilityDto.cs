using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class LiabilityDto
    {
        [Key]
        public int PayeeId { get; set; }

        public string PayeeType { get; set; }

        public string PayeeName { get; set; }

        public string? Address { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public DateOnly? StartDate { get; set; }

        public decimal? Balance { get; set; }

        public string? LegalName { get; set; }

        public string? AccountNumber { get; set; }

        public int? AccountId1 { get; set; }

        public int? AccountId2 { get; set; }

        public int? AccountId3 { get; set; }

        public int? AccountId4 { get; set; }
    }
}
