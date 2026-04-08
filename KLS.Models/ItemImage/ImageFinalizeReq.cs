namespace KLS.Models
{
    public class ImageFinalizeReq
    {
        public int ImageId { get; set; }

        /// <summary>
        /// 1 = Original, 2 = Python (rembg), 3 = API (remove.bg)
        /// </summary>
        public int SelectedVersion { get; set; }
    }
}
