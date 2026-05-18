namespace KLS.Models
{
    public class BankFeedUploadPreviewRes
    {
        public string UploadToken { get; set; } = string.Empty;

        public string FileName { get; set; } = string.Empty;

        public int TotalRows { get; set; }

        public List<BankFeedPreviewColumn> Columns { get; set; } = new();

        public List<BankFeedPreviewRow> Rows { get; set; } = new();

        public BankFeedCsvColumnMap SuggestedMap { get; set; } = new();
    }
}
