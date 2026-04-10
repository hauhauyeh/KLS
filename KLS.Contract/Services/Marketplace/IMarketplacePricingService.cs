using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace
{
    public interface IMarketplacePricingService
    {
        Task<ListingResult> PushPriceAsync(int marketItemMapId);

        Task<int> PushAllPricesAsync(int marketAccountId);
    }
}
