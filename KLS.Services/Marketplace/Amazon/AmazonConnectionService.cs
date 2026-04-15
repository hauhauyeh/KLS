using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Amazon;
using System;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Amazon
{
    public class AmazonConnectionService : IMarketplaceConnectionService
    {
        private readonly IAmazonTokenService _tokenService;

        public AmazonConnectionService(IAmazonTokenService tokenService)
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
