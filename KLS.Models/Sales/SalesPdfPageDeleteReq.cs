namespace KLS.Models
{
    public class SalesPdfPageDeleteReq
    {
        public int SalesNumber { get; set; }

        public List<int> PageNumbers { get; set; } = [];
    }
}
