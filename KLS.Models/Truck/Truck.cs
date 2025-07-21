using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Truck
    {
        public Truck()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TruckId { get; set; }

        public string TruckNumber { get; set; }

        public string? TruckName { get; set; }

        public string? VinNumber { get; set; }

        public string? TruckTag { get; set; }

        public string? TruckYear { get; set; }

        public string? TruckModel { get; set; }

        public DateOnly? RegExpDate { get; set; }

        public string? InsureProvider { get; set; }

        public string? InsureCoverage { get; set; }

        public string? OwnLeaseRental { get; set; }

        public string? GPSNumber { get; set; }

        public string? EPassNumber { get; set; }

        public string? Notes { get; set; }

        public bool IsInactive { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
