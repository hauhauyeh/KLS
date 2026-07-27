using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;

namespace KLS.Services
{
    public class ItemQuoteManagerService : BaseService, IItemQuoteManagerService
    {
        private readonly IItemService _itemService;
        private readonly IItemUnitService _itemUnitService;
        private readonly ISystemSettingService _systemSettingService;

        public ItemQuoteManagerService(
            IUnitOfWork uow,
            IItemService itemService,
            IItemUnitService itemUnitService,
            ISystemSettingService systemSettingService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
            _systemSettingService = systemSettingService;
        }

        public IEnumerable<ItemQuoteManagerRow> GetRows(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);

            var priceDecimals = _systemSettingService.GetPriceDecimals();
            var rows = Uow.ItemQuoteManager.GetRows(payeeId).ToList();
            rows.ForEach(r => r.PriceDecimals = priceDecimals);
            return rows;
        }

        public IEnumerable<ItemQuoteManagerRow> Inject(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);

            Uow.ItemQuotes.Inject(payeeId);
            return GetRows(payeeId);
        }

        public int Save(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);

            Uow.ItemQuotes.Save(payeeId);
            return Uow.ItemQuotes.Find(c => c.PayeeId == payeeId).Count();
        }

        public IEnumerable<ItemQuoteManagerRow> Clear(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);

            Uow.TempItemQuotes
                .Find(c => c.EmpId == UserContext.EmpId && c.PayeeId == payeeId)
                .ExecuteDelete();

            return GetRows(payeeId);
        }

        public IEnumerable<ItemQuoteManagerRow> AddItem(int payeeId, ItemQuoteManagerAddItemReq req)
        {
            EnsureVisibleCustomer(payeeId);

            if (req == null)
                throw new InvalidOperationException("Add item request is required.");

            var item = _itemService.GetBySearch(req.ItemCode ?? string.Empty);

            if (item == null)
                throw new KeyNotFoundException("Product code not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            var units = _itemUnitService.GetByItemId(item.ItemId);
            var customer = Uow.Customers.GetById(payeeId);

            foreach (var unit in units)
            {
                if (DraftExists(payeeId, unit.ItemUnitId))
                    continue;

                var row = new TempItemQuote
                {
                    PayeeId = payeeId,
                    EmpId = UserContext.EmpId,
                    ItemId = item.ItemId,
                    ItemUnitId = unit.ItemUnitId
                };

                if (customer != null && !unit.IsBaseUnit && customer.BaseMarkup != 0)
                    row.MarkupPercent = 0;

                Uow.TempItemQuotes.Add(row);
            }

            Uow.Commit();
            return GetRows(payeeId);
        }

        public IEnumerable<ItemQuoteManagerRow> Override(int payeeId, ItemQuoteManagerOverrideReq req)
        {
            EnsureVisibleCustomer(payeeId);

            if (req == null)
                throw new InvalidOperationException("Override request is required.");

            var customer = Uow.Customers.GetById(payeeId);
            if (customer?.ShareQuoteId == null)
                throw new InvalidOperationException("Customer does not have a shared list.");

            var itemUnit = Uow.ItemUnits.GetById(req.ItemUnitId);
            if (itemUnit == null || itemUnit.ItemId != req.ItemId)
                throw new KeyNotFoundException("Item unit not found.");

            var item = Uow.Items.GetById(req.ItemId);
            if (item == null || item.Inactive)
                throw new KeyNotFoundException("Product code not found");

            if (DraftExists(payeeId, req.ItemUnitId))
                throw new InvalidOperationException("Item is already in the customer's draft list.");

            var shared = Uow.ItemQuotes
                .Find(q => q.PayeeId == customer.ShareQuoteId.Value && q.ItemUnitId == req.ItemUnitId)
                .FirstOrDefault();

            if (shared == null)
                throw new InvalidOperationException("Shared quote row not found.");

            Uow.TempItemQuotes.Add(new TempItemQuote
            {
                EmpId = UserContext.EmpId,
                PayeeId = payeeId,
                ItemId = req.ItemId,
                ItemUnitId = req.ItemUnitId,
                MarkupPercent = shared.MarkupPercent,
                TargetPrice = shared.TargetPrice,
                NewPrice = shared.NewPrice,
                OldPrice = shared.OldPrice,
                IsFixed = shared.IsFixed
            });

            Uow.Commit();
            return GetRows(payeeId);
        }

        public ItemQuoteManagerRow UpdateDraftRow(int payeeId, int tempQuoteId, ItemQuoteManagerUpdateDraftRowReq req)
        {
            EnsureVisibleCustomer(payeeId);

            if (req == null)
                throw new InvalidOperationException("Update draft row request is required.");

            var existing = GetDraft(payeeId, tempQuoteId);

            existing.IsFixed = req.IsFixed;
            existing.MarkupPercent = req.IsFixed ? null : req.MarkupPercent;
            existing.TargetPrice = req.IsFixed ? req.TargetPrice : null;

            Uow.TempItemQuotes.Update(existing);
            Uow.Commit();

            return GetRows(payeeId).First(r => r.TempQuoteId == tempQuoteId);
        }

        public IEnumerable<ItemQuoteManagerRow> DeleteDraftRow(int payeeId, int tempQuoteId)
        {
            EnsureVisibleCustomer(payeeId);
            _ = GetDraft(payeeId, tempQuoteId);

            Uow.TempItemQuotes
                .Find(c => c.TempQuoteId == tempQuoteId && c.EmpId == UserContext.EmpId && c.PayeeId == payeeId)
                .ExecuteDelete();

            return GetRows(payeeId);
        }

        private TempItemQuote GetDraft(int payeeId, int tempQuoteId)
        {
            var row = Uow.TempItemQuotes
                .Find(c => c.TempQuoteId == tempQuoteId && c.EmpId == UserContext.EmpId && c.PayeeId == payeeId)
                .FirstOrDefault();

            if (row == null)
                throw new KeyNotFoundException("Draft quote row not found.");

            return row;
        }

        private bool DraftExists(int payeeId, int itemUnitId)
        {
            return Uow.TempItemQuotes.Exists(c =>
                c.EmpId == UserContext.EmpId
                && c.PayeeId == payeeId
                && c.ItemUnitId == itemUnitId);
        }
    }
}
