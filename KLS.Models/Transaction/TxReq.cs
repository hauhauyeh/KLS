using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TxReq : PagingRequest
    {
        public string? DocType { get; set; }
    }
}
