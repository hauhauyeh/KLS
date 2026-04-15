using System.Net.Http;
using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace.Amazon
{
    public interface IAmazonSpApiClient
    {
        Task<T?> GetAsync<T>(int marketAccountId, string endpoint) where T : class;
        Task<T?> PostAsync<T>(int marketAccountId, string endpoint, object body) where T : class;
        Task<T?> PutAsync<T>(int marketAccountId, string endpoint, object body) where T : class;
        Task<T?> PatchAsync<T>(int marketAccountId, string endpoint, object body) where T : class;
        Task DeleteAsync(int marketAccountId, string endpoint);
    }
}
