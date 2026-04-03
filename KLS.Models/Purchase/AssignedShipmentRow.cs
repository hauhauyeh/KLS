using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AssignedShipmentRow
    {
        [Key]
        public Int64 Id { get; set; }
        public int ShipmentPurchaseId { get; set; }
        public int ShipmentId { get; set; }
        public string? ShipmentType { get; set; }
        public string? ContainerType { get; set; }
        public string? ContainerNo { get; set; }
        public string? Status { get; set; }
        public string? PayeeName { get; set; }

        public int? ChargeId { get; set; }
        public string? ChargeType { get; set; }
        public string? AllocationMethod { get; set; }
        public decimal? ChargeAmount { get; set; }
        public string? Notes { get; set; }
        public string? UsedMethod { get; set; }
    }

    public class AssignedShipment
    {
        [Key]
        public int ShipmentPurchaseId { get; set; }
        public int ShipmentId { get; set; }
        public string? ShipmentType { get; set; }
        public string? ContainerType { get; set; }
        public string? ContainerNo { get; set; }
        public string? PayeeName { get; set; }

        public string? Status { get; set; }

        public decimal TotalCharges => Charges?.Sum(c => c.ChargeAmount ?? 0m) ?? 0m;

        public bool IsClosed => Status == EnumHelper.ShipmentStatus.Closed.ToString();

        public ICollection<ShipmentCharge> Charges { get; set; } = [];
    }
}
