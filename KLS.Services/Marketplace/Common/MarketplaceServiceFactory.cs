using KLS.Common;
using KLS.Contract.Services.Marketplace;
using KLS.Services.Marketplace.Amazon;
using KLS.Services.Marketplace.Ebay;
using KLS.Services.Marketplace.ShipStation;
using KLS.Services.Marketplace.Walmart;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Common
{
    public interface IMarketplaceServiceFactory
    {
        IMarketplaceConnectionService GetConnectionService(string marketType);
        IMarketplaceListingService GetListingService(string marketType);
        IMarketplacePricingService GetPricingService(string marketType);
        IMarketplaceInventoryService GetInventoryService(string marketType);
        IMarketplaceOrderService GetOrderService(string marketType);
    }

    public class MarketplaceServiceFactory : IMarketplaceServiceFactory
    {
        private readonly IServiceProvider _serviceProvider;

        public MarketplaceServiceFactory(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider;
        }

        public IMarketplaceConnectionService GetConnectionService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonConnectionService>(),
                MarketTypeNames.Walmart => _serviceProvider.GetRequiredService<WalmartConnectionService>(),
                MarketTypeNames.Ebay => _serviceProvider.GetRequiredService<EbayConnectionService>(),
                MarketTypeNames.ShipStation => _serviceProvider.GetRequiredService<ShipStationConnectionService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for connection testing")
            };
        }

        public IMarketplaceListingService GetListingService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonListingService>(),
                MarketTypeNames.Walmart => _serviceProvider.GetRequiredService<WalmartListingService>(),
                MarketTypeNames.Ebay => _serviceProvider.GetRequiredService<EbayListingService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for listings")
            };
        }

        public IMarketplacePricingService GetPricingService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonPricingService>(),
                MarketTypeNames.Walmart => _serviceProvider.GetRequiredService<WalmartPricingService>(),
                MarketTypeNames.Ebay => _serviceProvider.GetRequiredService<EbayPricingService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for pricing")
            };
        }

        public IMarketplaceInventoryService GetInventoryService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonInventoryService>(),
                MarketTypeNames.Walmart => _serviceProvider.GetRequiredService<WalmartInventoryService>(),
                MarketTypeNames.Ebay => _serviceProvider.GetRequiredService<EbayInventoryService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for inventory")
            };
        }

        public IMarketplaceOrderService GetOrderService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonOrderService>(),
                MarketTypeNames.Walmart => _serviceProvider.GetRequiredService<WalmartOrderService>(),
                MarketTypeNames.Ebay => _serviceProvider.GetRequiredService<EbayOrderService>(),
                MarketTypeNames.ShipStation => _serviceProvider.GetRequiredService<ShipStationOrderService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for orders")
            };
        }
    }
}
