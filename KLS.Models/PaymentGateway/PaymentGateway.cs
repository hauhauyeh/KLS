using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PaymentGateway
    {
        public PaymentGateway()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int GatewayId { get; set; }

        public string? GatewayCode { get; set; }

        public string? GatewayName { get; set; }

        public string Environment { get; set; }

        public bool IsActive { get; set; }

        public string? ClientKey { get; set; }

        public string? AccessToken { get; set; }

        public string? MerchantId { get; set; }

        public string? Version { get; set; }

        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
