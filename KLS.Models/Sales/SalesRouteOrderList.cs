using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesRouteOrderList
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

        public int? RouteOrder { get; set; }

        public int PayeeId { get; set; }

        public string PayeeName { get; set; }
    }
}
