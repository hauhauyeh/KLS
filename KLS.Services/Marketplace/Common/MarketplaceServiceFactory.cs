using KLS.Common;
using KLS.Contract.Services.Marketplace;
using KLS.Services.Marketplace.Amazon;
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

        public IMarketplaceListingService GetListingService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonListingService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for listings")
            };
        }

        public IMarketplacePricingService GetPricingService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonPricingService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for pricing")
            };
        }

        public IMarketplaceInventoryService GetInventoryService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonInventoryService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for inventory")
            };
        }

        public IMarketplaceOrderService GetOrderService(string marketType)
        {
            return marketType switch
            {
                MarketTypeNames.Amazon => _serviceProvider.GetRequiredService<AmazonOrderService>(),
                _ => throw new NotSupportedException($"Marketplace '{marketType}' is not supported for orders")
            };
        }
    }
}
