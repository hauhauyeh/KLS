using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace.Ebay
{
    public interface IEbayTokenService
    {
        Task<string> GetAccessTokenAsync(int marketAccountId);
    }
}
