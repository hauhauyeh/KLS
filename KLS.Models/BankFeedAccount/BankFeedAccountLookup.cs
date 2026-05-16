namespace KLS.Models
{
    public class BankFeedAccountLookup
    {
        public long? BankFeedAccountId { get; set; }

        public int AccountId { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public string? TypeName { get; set; }

        public string? AccountNickname { get; set; }

        public string ImportFormat { get; set; } = "CSV";

        public bool IsActive { get; set; }
    }
}
