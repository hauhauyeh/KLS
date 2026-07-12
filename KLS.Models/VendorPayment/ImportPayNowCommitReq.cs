namespace KLS.Models
{
    public class ImportPayNowCommitReq
    {
        public string? PaymentMethod { get; set; }

        public int FromAccountId { get; set; }

        /// <summary>Token returned by ImportPayNowPreview. Names the uploaded workbook on disk.</summary>
        public string? UploadToken { get; set; }
    }
}
