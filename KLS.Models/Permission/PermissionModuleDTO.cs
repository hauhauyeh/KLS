namespace KLS.Models
{
    public class PermissionModuleDTO
    {
        public string Module { get; set; } = string.Empty;
        public List<PermissionResourceDTO> Resources { get; set; } = new();
    }

    public class PermissionResourceDTO
    {
        public string Resource { get; set; } = string.Empty;
        public int SortOrder { get; set; }
        public List<PermissionActionDTO> Actions { get; set; } = new();
    }

    public class PermissionActionDTO
    {
        public string Id { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public bool IsGranted { get; set; }
    }
}
