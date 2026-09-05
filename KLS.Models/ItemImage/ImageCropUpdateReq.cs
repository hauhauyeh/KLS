using Microsoft.AspNetCore.Http;

namespace KLS.Models
{
    public class ImageCropUpdateReq
    {
        public IFormFile? CroppedFile { get; set; }

        public decimal? CropXRatio { get; set; }

        public decimal? CropYRatio { get; set; }

        public decimal? CropSizeRatio { get; set; }
    }
}
