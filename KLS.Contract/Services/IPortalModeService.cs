using KLS.Common;

namespace KLS.Contract.Services
{
    public interface IPortalModeService
    {
        WebPortalMode GetMode();

        bool IsB2B();

        bool IsB2C();

        void Invalidate();
    }
}
