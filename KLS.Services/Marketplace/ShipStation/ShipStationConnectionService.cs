using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.ShipStation;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.ShipStation
{
    public class ShipStationConnectionService : IMarketplaceConnectionService
    {
        private readonly IShipStationApiClient _client;

        public ShipStationConnectionService(IShipStationApiClient client)
        {
            _client = client;
        }

        public Task<bool> TestConnectionAsync(int marketAccountId)
            => _client.TestConnectionAsync(marketAccountId);
    }
}
