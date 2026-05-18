namespace KLS.Models
{
    public class BankFeedImportReq
    {
        public int AccountId { get; set; }

        public string UploadToken { get; set; } = string.Empty;

        public BankFeedCsvColumnMap Map { get; set; } = new();
    }
}
