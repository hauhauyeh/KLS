using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TFReq : PagingRequest
    {
        public int? FromAccountId { get; set; }
        public int? ToAccountId { get; set; }
    }
}
