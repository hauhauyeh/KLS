using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Common;
using KLS.Models;
using Microsoft.AspNetCore.Http;
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
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ItemHistoryService(IUnitOfWork uow, IPurchaseService purchaseService, ISalesService salesService, IHttpContextAccessor httpContextAccessor) : base(uow)
        {
            _purchaseService = purchaseService;
            _salesService = salesService;
            _httpContextAccessor = httpContextAccessor;
        }

        public IEnumerable<ItemHistorySales> GetSalesHistory(ItemHistoryReq itemHistoryReq)
        {
            itemHistoryReq = WithServerContext(itemHistoryReq);
            var salesItems = Uow.ItemHistories.GetSalesHistory(itemHistoryReq).ToList();

            foreach (var item in salesItems)
            {
                item.IsPdfExist = _salesService.IsInvoicePdfExist(item.SalesNumber);
            }

            return salesItems;
        }

        public IEnumerable<ItemHistoryPurchase> GetPurchaseHistory(ItemHistoryReq itemHistoryReq)
        {
            itemHistoryReq = WithServerContext(itemHistoryReq);
            var billItems = Uow.ItemHistories.GetPurchaseHistory(itemHistoryReq).ToList();

            foreach (var item in billItems)
            {
                item.IsPdfExist = _purchaseService.IsBillPdfExist(item.PurchaseNumber);
            }

            return billItems;
        }

        public IEnumerable<ItemHistoryInventory> GetInventoryHistory(ItemHistoryReq itemHistoryReq)
        {
            itemHistoryReq = WithServerContext(itemHistoryReq);
            return Uow.ItemHistories.GetInventoryHistory(itemHistoryReq);
        }

        private ItemHistoryReq WithServerContext(ItemHistoryReq itemHistoryReq)
        {
            return new ItemHistoryReq
            {
                ItemId = itemHistoryReq.ItemId,
                PayeeId = itemHistoryReq.PayeeId,
                Filterby = itemHistoryReq.Filterby,
                ViewerSalesRepId = UserContext.IsSalesRole ? UserContext.EmpId : null,
                CanSeeCost = HasPurchaseHistoryPermission()
            };
        }

        private bool HasPurchaseHistoryPermission()
        {
            var httpContext = _httpContextAccessor.HttpContext;

            if (httpContext?.Items["IsAdmin"] is bool isAdmin && isAdmin)
                return true;

            if (httpContext?.Items["PermissionKeys"] is HashSet<string> permissionKeys)
                return permissionKeys.Contains("Product.ItemHistory.Purchase");

            return false;
        }
    }
}
