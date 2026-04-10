using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace
{
    public interface IMarketplaceListingService
    {
        Task<ListingResult> PushListingAsync(int marketItemMapId);

        Task<ListingResult> DeleteListingAsync(int marketItemMapId);

        Task RefreshStatusAsync(int marketItemMapId);

        Task<int> PushAllAsync(int marketAccountId);
    }
}
