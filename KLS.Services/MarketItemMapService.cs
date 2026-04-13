using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class MarketItemMapService : BaseService, IMarketItemMapService
    {
        public MarketItemMapService(IUnitOfWork uow) : base(uow) { }

        public IEnumerable<MarketItemMap> GetByAccount(int marketAccountId)
        {
            var maps = Uow.MarketItemMaps.Find(m => m.MarketAccountId == marketAccountId).ToList();
            var itemIds = maps.Select(m => m.ItemId).Distinct().ToList();
            var items = Uow.Items.Find(i => itemIds.Contains(i.ItemId))
                .Select(i => new { i.ItemId, i.ItemCode, i.ItemName }).ToList();
            foreach (var map in maps)
            {
                var item = items.FirstOrDefault(i => i.ItemId == map.ItemId);
                if (item != null)
                {
                    map.ItemCode = item.ItemCode;
                    map.ItemName = item.ItemName;
                }
            }
            return maps;
        }

        public IEnumerable<MarketItemMap> GetByItemIds(IEnumerable<int> itemIds)
        {
            var idList = itemIds.ToList();
            var maps = Uow.MarketItemMaps.Find(m => idList.Contains(m.ItemId) && m.IsActive).ToList();

            var distinctItemIds = maps.Select(m => m.ItemId).Distinct().ToList();
            var items = Uow.Items.Find(i => distinctItemIds.Contains(i.ItemId))
                .Select(i => new { i.ItemId, i.ItemCode, i.ItemName }).ToList();

            var accountIds = maps.Select(m => m.MarketAccountId).Distinct().ToList();
            var accounts = Uow.MarketAccounts.Find(a => accountIds.Contains(a.MarketAccountId))
                .Select(a => new { a.MarketAccountId, a.AccountName, a.MarketType }).ToList();

            foreach (var map in maps)
            {
                var item = items.FirstOrDefault(i => i.ItemId == map.ItemId);
                if (item != null) { map.ItemCode = item.ItemCode; map.ItemName = item.ItemName; }
                var account = accounts.FirstOrDefault(a => a.MarketAccountId == map.MarketAccountId);
                if (account != null) { map.AccountName = account.AccountName; map.MarketType = account.MarketType; }
            }
            return maps;
        }

        public MarketItemMap? GetById(int id)
        {
            return Uow.MarketItemMaps.GetById(id);
        }

        public MarketItemMap? GetBySku(int marketAccountId, string externalSku)
        {
            return Uow.MarketItemMaps.Find(m => m.MarketAccountId == marketAccountId && m.ExternalSku == externalSku).FirstOrDefault();
        }

        public bool SkuExists(int marketAccountId, string externalSku, int excludeId = 0)
        {
            return Uow.MarketItemMaps.Exists(m => m.MarketAccountId == marketAccountId && m.ExternalSku == externalSku && m.MarketItemMapId != excludeId);
        }

        public MarketItemMap Save(MarketItemMap map)
        {
            if (map.MarketItemMapId == 0)
            {
                Uow.MarketItemMaps.Add(map);
            }
            else
            {
                var existing = Uow.MarketItemMaps.GetById(map.MarketItemMapId)
                    ?? throw new Exception("Item mapping not found");
                existing.ExternalSku = map.ExternalSku;
                existing.ExternalListingId = map.ExternalListingId;
                existing.ExternalVariantId = map.ExternalVariantId;
                existing.ExternalItemName = map.ExternalItemName;
                existing.MappingStatus = map.MappingStatus;
                existing.IsActive = map.IsActive;
                existing.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(existing);
            }
            Uow.Commit();
            return map;
        }

        public void Delete(int id)
        {
            Uow.MarketItemMaps.RemoveById(id);
            Uow.Commit();
        }

        public void UpdateSyncStatus(int id, string status, string? error = null)
        {
            var map = Uow.MarketItemMaps.GetById(id);
            if (map == null) return;
            map.LastSyncStatus = status;
            map.LastSyncAt = DateTime.UtcNow;
            map.LastError = error;
            map.UpdatedAt = DateTime.UtcNow;
            Uow.MarketItemMaps.Update(map);
            Uow.Commit();
        }
    }
}
