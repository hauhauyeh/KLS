namespace KLS.Models
{
    public class MigrationResult
    {
        public bool Success { get; set; } = true;
        public bool DryRun { get; set; }
        public int TotalItemsFound { get; set; }
        public int ItemsProcessed { get; set; }
        public int Imported { get; set; }
        public int Skipped { get; set; }
        public int Failures { get; set; }
        public int AlreadyMigrated { get; set; }
        public List<string> Warnings { get; set; } = new();
        public List<string> Details { get; set; } = new();
    }
}
