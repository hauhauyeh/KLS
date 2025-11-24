using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class RPTPoView
    {
        public Company? Company { get; set; }

        public RPTPo? RPTPo { get; set; }

        public List<RPTPoDetail>? RPTPoDetail { get; set; }

        public int TotalItem
        {
            get
            {
                return RPTPoDetail.Where(c => c.LineType == EnumHelper.LineType.I.ToString()).GroupBy(c => c.ItemId).Count();
            }
        }
    }
}
