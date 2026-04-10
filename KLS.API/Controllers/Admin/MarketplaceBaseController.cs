using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Marketplace.Common;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Admin
{
    public abstract class MarketplaceBaseController : BaseController
    {
        protected readonly IMarketplaceServiceFactory Factory;
        protected readonly IUnitOfWork Uow;

        protected MarketplaceBaseController(IMarketplaceServiceFactory factory, IUnitOfWork uow)
        {
            Factory = factory;
            Uow = uow;
        }

        protected MarketAccount ResolveAccountFromMap(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new KeyNotFoundException($"MarketItemMap {marketItemMapId} not found");
            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new KeyNotFoundException($"MarketAccount {map.MarketAccountId} not found");
            if (!account.IsActive)
                throw new InvalidOperationException($"MarketAccount '{account.AccountName}' is inactive");
            return account;
        }

        protected MarketAccount ResolveAccount(int marketAccountId)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new KeyNotFoundException($"MarketAccount {marketAccountId} not found");
            if (!account.IsActive)
                throw new InvalidOperationException($"MarketAccount '{account.AccountName}' is inactive");
            return account;
        }
    }
}
