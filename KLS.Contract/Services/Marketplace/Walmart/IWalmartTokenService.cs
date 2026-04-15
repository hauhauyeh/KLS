using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace.Walmart
{
    public interface IWalmartTokenService
    {
        Task<string> GetAccessTokenAsync(int marketAccountId);
    }
}
