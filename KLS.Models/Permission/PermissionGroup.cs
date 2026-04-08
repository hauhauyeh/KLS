namespace KLS.Models
{
    public class PermissionGroup
    {
        public string Module { get; set; } = string.Empty;
        public List<PermissionNode> Permissions { get; set; } = new();
    }

    public class PermissionNode
    {
        public int PermissionId { get; set; }
        public string PermissionKey { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string PermissionType { get; set; } = string.Empty;
        public string? ParentKey { get; set; }
        public int SortOrder { get; set; }
        public bool IsGranted { get; set; }
    }
}
