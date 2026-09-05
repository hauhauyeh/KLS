using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ImageUploadReq
    {
        public int ItemId { get; set; }

        public List<IFormFile>? files { get; set; }

        public List<IFormFile>? OriginalFiles { get; set; }

        public List<IFormFile>? CroppedFiles { get; set; }

        public List<decimal>? CropXRatios { get; set; }

        public List<decimal>? CropYRatios { get; set; }

        public List<decimal>? CropSizeRatios { get; set; }

        // Mixed order: existing IDs + 0 placeholders for NEW files
        // Example: [12, 0, 15, 0, 9]
        public List<int>? Order { get; set; }

        // Index in Order list that should be primary (0-based)
        // Example: 3 means Order[3] is primary (could be 0 => a NEW file)
        public int? PrimaryOrderIndex { get; set; }
    }
}
