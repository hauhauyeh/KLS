using KLS.Common;
using KLS.Contract.Services;
using Microsoft.Extensions.Caching.Memory;

namespace KLS.Services
{
    public class PortalModeService : IPortalModeService
    {
        private const string CacheKey = "web-portal-mode";
        private readonly ISystemSettingService _systemSettingService;
        private readonly IMemoryCache _memoryCache;

        public PortalModeService(ISystemSettingService systemSettingService, IMemoryCache memoryCache)
        {
            _systemSettingService = systemSettingService;
            _memoryCache = memoryCache;
        }

        public WebPortalMode GetMode()
        {
            return _memoryCache.GetOrCreate(CacheKey, entry =>
            {
                entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(60);

                try
                {
                    var raw = _systemSettingService.GetByKey<string>(GlobalKey.WEB_PORTAL_MODE);
                    if (Enum.TryParse<WebPortalMode>(raw, true, out var mode))
                        return mode;
                }
                catch
                {
                }

                return WebPortalMode.B2B;
            });
        }

        public bool IsB2B() => GetMode() == WebPortalMode.B2B;

        public bool IsB2C() => GetMode() == WebPortalMode.B2C;

        public void Invalidate()
        {
            _memoryCache.Remove(CacheKey);
        }
    }
}
