using Microsoft.AspNetCore.Http;

namespace KLS.Models
{
    public class ImageCropUpdateReq
    {
        public IFormFile? CroppedFile { get; set; }
    }
}
