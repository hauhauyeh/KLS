using KLS.Models;
using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace.Amazon
{
    public interface IAmazonCatalogService
    {
        Task<AmazonCatalogSearchResult> SearchAsync(int marketAccountId, string keywords);
        Task<AmazonCatalogItem?> GetByAsinAsync(int marketAccountId, string asin);
    }
}
