namespace KLS.Models
{
    public class TempPurchaseReorderReq
    {
        public int PurchaseId { get; set; }

        public int PayeeId { get; set; }

        public List<TempPurchaseReorderItem> Items { get; set; } = [];
    }
}
