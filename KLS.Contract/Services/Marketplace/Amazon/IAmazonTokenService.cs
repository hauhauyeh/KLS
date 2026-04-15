using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace.Amazon
{
    public interface IAmazonTokenService
    {
        Task<string> GetAccessTokenAsync(int marketAccountId);
        Task<bool> TestConnectionAsync(int marketAccountId);
    }
}
