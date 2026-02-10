using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountMoveReq
    {
        public int AccountId { get; set; }

        public int NewCategoryId { get; set; }
    }
}
