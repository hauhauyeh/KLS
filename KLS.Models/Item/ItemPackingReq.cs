using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemPackingReq
    {
        public string? SetPacking { get; set; }

        public decimal? P1 { get; set; }
    }
}
