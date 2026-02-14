using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemUpdateReq
    {
        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        public decimal? BaseP1 { get; set; }
    }
}
