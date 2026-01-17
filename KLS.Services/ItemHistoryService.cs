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
    public class ItemHistoryService : BaseService, IItemHistoryService
    {
        private readonly IPurchaseService _purchaseService;
        private readonly ISalesService _salesService;

        public ItemHistoryService(IUnitOfWork uow, IPurchaseService purchaseService, ISalesService salesService) : base(uow)
        {
            _purchaseService = purchaseService;
            _salesService = salesService;
        }

        public IEnumerable<ItemHistorySales> GetSalesHistory(ItemHistoryReq itemHistoryReq)
        {
            var salesItems = Uow.ItemHistories.GetSalesHistory(itemHistoryReq).ToList();

            foreach (var item in salesItems)
            {
                item.IsPdfExist = _salesService.IsInvoicePdfExist(item.SalesNumber);
            }

            return salesItems;
        }

        public IEnumerable<ItemHistoryPurchase> GetPurchaseHistory(ItemHistoryReq itemHistoryReq)
        {
            var billItems = Uow.ItemHistories.GetPurchaseHistory(itemHistoryReq).ToList();

            foreach (var item in billItems)
            {
                item.IsPdfExist = _purchaseService.IsBillPdfExist(item.PurchaseNumber);
            }

            return billItems;
        }

        public IEnumerable<ItemHistoryInventory> GetInventoryHistory(ItemHistoryReq itemHistoryReq)
        {
            return Uow.ItemHistories.GetInventoryHistory(itemHistoryReq);
        }
    }
}
