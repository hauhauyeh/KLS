using System;

namespace KLS.Common
{
    public enum MarketMappingStatus
    {
        Mapped,
        Unmapped,
        Conflict,
        Inactive
    }

    public enum MarketSyncStatus
    {
        Submitted,
        Success,
        Failed
    }

    public enum MarketInternalOrderStatus
    {
        Pending
    }

    public static class MarketplaceStatusValues
    {
        public static string ToValue(this MarketMappingStatus status)
        {
            return status switch
            {
                MarketMappingStatus.Mapped => "mapped",
                MarketMappingStatus.Unmapped => "unmapped",
                MarketMappingStatus.Conflict => "conflict",
                MarketMappingStatus.Inactive => "inactive",
                _ => throw new ArgumentOutOfRangeException(nameof(status), status, null)
            };
        }

        public static string ToValue(this MarketSyncStatus status)
        {
            return status switch
            {
                MarketSyncStatus.Submitted => "submitted",
                MarketSyncStatus.Success => "success",
                MarketSyncStatus.Failed => "failed",
                _ => throw new ArgumentOutOfRangeException(nameof(status), status, null)
            };
        }

        public static string ToValue(this MarketInternalOrderStatus status)
        {
            return status switch
            {
                MarketInternalOrderStatus.Pending => "pending",
                _ => throw new ArgumentOutOfRangeException(nameof(status), status, null)
            };
        }

        public static bool Is(this string? value, MarketMappingStatus status)
        {
            return string.Equals(value, status.ToValue(), StringComparison.OrdinalIgnoreCase);
        }

        public static bool Is(this string? value, MarketSyncStatus status)
        {
            return string.Equals(value, status.ToValue(), StringComparison.OrdinalIgnoreCase);
        }

        public static bool Is(this string? value, MarketInternalOrderStatus status)
        {
            return string.Equals(value, status.ToValue(), StringComparison.OrdinalIgnoreCase);
        }
    }
}
