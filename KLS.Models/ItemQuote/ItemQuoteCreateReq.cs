namespace KLS.Models
{
    public class ItemQuoteCreateReq
    {
        public int ItemId { get; set; }
        public List<int> ItemUnitIds { get; set; } = new();
    }
}
