using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Ebay;
using System;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Ebay
{
    public class EbayConnectionService : IMarketplaceConnectionService
    {
        private readonly IEbayApiClient _client;

        public EbayConnectionService(IEbayApiClient client)
        {
            _client = client;
        }

        public async Task<bool> TestConnectionAsync(int marketAccountId)
        {
            try
            {
                // Locked probe per plan: /sell/account/v1/privilege
                var raw = await _client.GetAsync<object>(marketAccountId, "/sell/account/v1/privilege");
                return raw != null;
            }
            catch
            {
                return false;
            }
        }
    }
}
