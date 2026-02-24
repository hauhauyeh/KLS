using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ShipmentPurchase
    {
        [Key]
        public int ShipmentPurchaseId { get; set; }

        public int ShipmentId { get; set; }

        public int PurchaseId { get; set; }
    }
}
