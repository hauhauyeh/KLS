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
    public class MarketOrderService : BaseService, IMarketOrderService
    {
        public MarketOrderService(IUnitOfWork uow) : base(uow) { }

        public IEnumerable<MarketOrder> GetByAccount(int marketAccountId)
        {
            return Uow.MarketOrders.Find(o => o.MarketAccountId == marketAccountId)
                .OrderByDescending(o => o.OrderDate).ToList();
        }

        public MarketOrder? GetById(int id)
        {
            return Uow.MarketOrders.GetById(id);
        }

        public MarketOrder? GetByExternalId(int marketAccountId, string externalOrderId)
        {
            return Uow.MarketOrders.Find(o => o.MarketAccountId == marketAccountId && o.ExternalOrderId == externalOrderId).FirstOrDefault();
        }

        public void MatchSkus(int marketOrderId)
        {
            var order = Uow.MarketOrders.GetById(marketOrderId)
                ?? throw new Exception("Market order not found");
            var items = Uow.MarketOrderItems.Find(i => i.MarketOrderId == marketOrderId).ToList();

            foreach (var item in items)
            {
                if (string.IsNullOrEmpty(item.ExternalSku)) continue;
                var map = Uow.MarketItemMaps.Find(m =>
                    m.MarketAccountId == order.MarketAccountId &&
                    m.ExternalSku == item.ExternalSku).FirstOrDefault();

                if (map != null)
                {
                    item.ItemId = map.ItemId;
                    item.ItemUnitId = map.ItemUnitId;
                    item.MarketItemMapId = map.MarketItemMapId;
                    item.MatchStatus = "matched";
                }
                else
                {
                    item.MatchStatus = "unmatched";
                }
                Uow.MarketOrderItems.Update(item);
            }
            Uow.Commit();
        }

        public Task<int> ConvertToSalesAsync(int marketOrderId)
        {
            // TODO: Create TempSales + TempSalesDetail, then inject via Sales_Inject SP
            // Full implementation deferred — requires detailed design pass on existing Sales flow
            throw new NotImplementedException("ConvertToSales not yet implemented");
        }
    }
}
