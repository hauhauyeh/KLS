namespace KLS.Models
{
    public class ItemCategoryReorderReq
    {
        public int Id { get; set; }
        public string Direction { get; set; } = string.Empty; // "Up" or "Down"
    }
}
