using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemImageSortReq
    {
        public int ItemId { get; set; }

        public List<int> OrderedImageIds { get; set; } = new();
    }
}
