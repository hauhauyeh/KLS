namespace KLS.API.Helpers
{
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = false)]
    public class PermissionKeyAttribute : Attribute
    {
        public string Key { get; }
        public PermissionKeyAttribute(string key) => Key = key;
    }
}
