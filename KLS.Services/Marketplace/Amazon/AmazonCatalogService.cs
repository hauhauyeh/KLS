using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Amazon
{
    public interface IAmazonCatalogService
    {
        Task<AmazonCatalogSearchResult> SearchAsync(int marketAccountId, string keywords);
        Task<AmazonCatalogItem?> GetByAsinAsync(int marketAccountId, string asin);
    }

    public class AmazonCatalogService : IAmazonCatalogService
    {
        private readonly IAmazonSpApiClient _client;
        private readonly IUnitOfWork _uow;

        public AmazonCatalogService(IAmazonSpApiClient client, IUnitOfWork uow)
        {
            _client = client;
            _uow = uow;
        }

        public async Task<AmazonCatalogSearchResult> SearchAsync(int marketAccountId, string keywords)
        {
            var account = _uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);
            var mpId = settings.MarketplaceId ?? "ATVPDKIKX0DER";

            var endpoint = $"/catalog/2022-04-01/items?keywords={Uri.EscapeDataString(keywords)}&marketplaceIds={mpId}&includedData=identifiers,images,productTypes,summaries&pageSize=20";
            return await _client.GetAsync<AmazonCatalogSearchResult>(marketAccountId, endpoint) ?? new AmazonCatalogSearchResult();
        }

        public async Task<AmazonCatalogItem?> GetByAsinAsync(int marketAccountId, string asin)
        {
            var account = _uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);
            var mpId = settings.MarketplaceId ?? "ATVPDKIKX0DER";

            var endpoint = $"/catalog/2022-04-01/items/{asin}?marketplaceIds={mpId}&includedData=identifiers,images,productTypes,summaries,dimensions";
            return await _client.GetAsync<AmazonCatalogItem>(marketAccountId, endpoint);
        }
    }
}
