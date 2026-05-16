namespace KLS.Models
{
    public class BankFeedCsvColumnMap
    {
        public bool HasHeaderRow { get; set; } = true;

        public int DateColumnIndex { get; set; }

        public int DescriptionColumnIndex { get; set; }

        public int? ReferenceColumnIndex { get; set; }

        public int? CheckNumberColumnIndex { get; set; }

        public string AmountMode { get; set; } = "SingleAmount";

        public int? AmountColumnIndex { get; set; }

        public int? CreditColumnIndex { get; set; }

        public int? DebitColumnIndex { get; set; }

        public string? DateFormat { get; set; }
    }
}
