namespace KLS.Models
{
    public class ItemImageVersionMigrationReq
    {
        public bool DryRun { get; set; } = true;

        public int Limit { get; set; }

        public bool Force { get; set; }
    }
}
