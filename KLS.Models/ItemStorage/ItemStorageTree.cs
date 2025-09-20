using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemStorageTree
    {
        [Key]
        public int StorageId { get; set; }

        public string? StorageName { get; set; }

        public int? ParentId { get; set; }

        public string? DisplayName { get; set; }

        public IEnumerable<ItemStorageTree>? ChildItemStorage { get; set; }

        public bool IsCollapsed { get; set; }

        public bool HasChild { get { return ChildItemStorage != null && ChildItemStorage.Any(); } }

        public int ItemCount { get; set; }
    }
}
