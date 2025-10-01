using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayrollReq : PagingRequest
    {
        public int? PayeeId { get; set; }
    }
}
