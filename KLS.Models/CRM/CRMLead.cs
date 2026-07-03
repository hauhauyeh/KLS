using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class CRMLead
    {
        [Key]
        public int LeadId { get; set; }

        public string? LeadName { get; set; }

        public string? ContactPerson { get; set; }

        public string? Phone { get; set; }

        public string? Email { get; set; }

        public string? Address { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? Source { get; set; }

        public string? Stage { get; set; }

        public int? SalesRepId { get; set; }

        public string? Notes { get; set; }

        [Column(TypeName = "decimal(18, 2)")]
        public decimal? EstimatedValue { get; set; }

        public string? LostReason { get; set; }

        public int? ConvertedPayeeId { get; set; }

        public DateTime? ConvertedAt { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public int? EnterBy { get; set; }

        public int? UpdateBy { get; set; }
    }
}
