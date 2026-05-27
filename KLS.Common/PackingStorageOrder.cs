namespace KLS.Common
{
    public static class PackingStorageOrder
    {
        // Section order on every packing-style report — single-invoice AND
        // route-wide. Both paths route through this one helper so the printed
        // PDF lays sections out in the same order regardless of entry point.
        //
        // Normalize once (Trim + ToUpperInvariant) so callers stay flexible:
        // matches the prior call-site contract (string.Equals + OrdinalIgnoreCase)
        // and tolerates a future SP / source change that stops emitting canonical
        // title-case.
        public static int GetSortOrder(string? storageName) =>
            storageName?.Trim().ToUpperInvariant() switch
            {
                "COOLER"    => 0,
                "PREPACK"   => 1,
                "FREEZER"   => 2,
                "WAREHOUSE" => 3,
                "DRIVER"    => 4,
                "STORE"     => 5,
                "CUSTOMER"  => 6,
                _           => 99
            };
    }
}
