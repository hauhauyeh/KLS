using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace.Ebay
{
    public interface IEbayApiClient
    {
        Task<T?> GetAsync<T>(int marketAccountId, string endpoint) where T : class;
        Task<T?> PostAsync<T>(int marketAccountId, string endpoint, object? body) where T : class;
        Task<T?> PutAsync<T>(int marketAccountId, string endpoint, object? body) where T : class;
        Task<string?> PostRawAsync(int marketAccountId, string endpoint, object? body);
        Task<string?> PutRawAsync(int marketAccountId, string endpoint, object? body);
        Task DeleteAsync(int marketAccountId, string endpoint);
    }
}
