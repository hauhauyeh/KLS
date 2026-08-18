namespace KLS.Models
{
    public class SalesPdfPageDeleteResult
    {
        public int SalesNumber { get; set; }

        public int OriginalPageCount { get; set; }

        public int DeletedPageCount { get; set; }

        public int FinalPageCount { get; set; }
    }
}
