using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Walmart;
using System;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Walmart
{
    public class WalmartConnectionService : IMarketplaceConnectionService
    {
        private readonly IWalmartTokenService _tokenService;

        public WalmartConnectionService(IWalmartTokenService tokenService)
        {
            _tokenService = tokenService;
        }

        public async Task<bool> TestConnectionAsync(int marketAccountId)
        {
            try
            {
                var token = await _tokenService.GetAccessTokenAsync(marketAccountId);
                return !string.IsNullOrWhiteSpace(token);
            }
            catch
            {
                return false;
            }
        }
    }
}
