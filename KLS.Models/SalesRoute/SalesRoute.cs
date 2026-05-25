using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesRoute
    {
        public SalesRoute()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int SalesRouteId { get; set; }

        public DateOnly ShipDate { get; set; }

        public string ShipRoute { get; set; }

        public string? Driver { get; set; }

        public int? DriverId { get; set; }

        public string? Loader { get; set; }

        public int? LoaderId { get; set; }

        public string? Checker { get; set; }

        public int? CheckerId { get; set; }

        public string? Officer { get; set; }

        public int? OfficerId { get; set; }

        public string? TruckNumber { get; set; }

        public int? TruckRouteOrder { get; set; }

        public decimal? BeginMileage { get; set; }

        public decimal? EndMileage { get; set; }

        public bool FuelCard { get; set; }

        public decimal? FuelCash { get; set; }

        public bool IsZeroPricePass { get; set; }

        public bool IsZeroWeightPass { get; set; }

        public bool IsPackingListPass { get; set; }

        public bool IsShippingChargePass { get; set; }

        public bool FullTank { get; set; }

        public bool FuelReceipt { get; set; }

        public int? InvoiceCount { get; set; }

        public int? CheckCount { get; set; }

        public decimal? CashCount { get; set; }

        public int? PrintCount { get; set; }

        public bool HandTruckBack { get; set; }

        public bool SweepTruck { get; set; }

        public bool SweepCab { get; set; }

        public decimal? CashChangeBack { get; set; }

        public bool KeyReturned { get; set; }

        public string? TruckIssue { get; set; }

        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
