namespace KLS.Models
{
    public class CRMFollowUpListReq : PagingRequest
    {
        public int? AssignedTo { get; set; }

        public string? Status { get; set; }

        public string? Priority { get; set; }
    }
}
