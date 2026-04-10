using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace
{
    public interface IMarketplaceInventoryService
    {
        Task<ListingResult> PushInventoryAsync(int marketItemMapId);

        Task<int> PushAllInventoryAsync(int marketAccountId);
    }
}
