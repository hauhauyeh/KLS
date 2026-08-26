namespace KLS.Models
{
    public class CategoryImageFinalizeReq
    {
        public int CategoryId { get; set; }

        /// <summary>
        /// 1 = Original, 2 = Python (rembg), 3 = API (remove.bg)
        /// </summary>
        public int SelectedVersion { get; set; }
    }
}
