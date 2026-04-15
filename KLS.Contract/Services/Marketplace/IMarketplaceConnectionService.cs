using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace
{
    public interface IMarketplaceConnectionService
    {
        Task<bool> TestConnectionAsync(int marketAccountId);
    }
}
