using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemWebListReq : PagingRequest
    {
        public int PayeeId { get; set; }    //login customer id

        public int? CategoryId { get; set; }

        public bool InStockOnly { get; set; }

        public bool IsWishList { get; set; }
    }
}
