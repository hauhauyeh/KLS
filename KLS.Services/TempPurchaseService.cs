using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempPurchaseService : BaseService, ITempPurchaseService
    {
        private readonly IItemService _itemService;
        private readonly IItemUnitService _itemUnitService;
        private readonly IAccountService _accountService;

        public TempPurchaseService(IUnitOfWork uow, IItemService itemService, IItemUnitService itemUnitService, IAccountService accountService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
            _accountService = accountService;
        }

        public IEnumerable<TempPurchaseItem>? GetList(TempPurchaseReq tempReq)
        {
            return Uow.TempPurchases.GetList(tempReq);
        }

        public TempPurchase? GetById(int tempId)
        {
            return Uow.TempPurchases.GetById(tempId);
        }

        public TempPurchaseItem GetListById(int payeeId, int purchaseId, int tempId)
        {
            var tempReq = new TempPurchaseReq
            {
                PayeeId = payeeId,
                PurchaseId = purchaseId,
                TempId = tempId
            };

            return Uow.TempPurchases.GetList(tempReq).AsEnumerable().FirstOrDefault();
        }

        public TempPurchaseItem Create(TempPurchaseItem tempItem, EnumHelper.PurchaseDocType docType)
        {
            if (tempItem.LineType == EnumHelper.LineType.A.ToString() || tempItem.ItemCode.StartsWith('@'))
                return AddAccount(tempItem, docType);
            else
                return AddItem(tempItem, docType);
        }

        public TempPurchaseItem Update(TempPurchaseItem dto, EnumHelper.PurchaseDocType docType)
        {
            var existing = GetById(dto.TempPurchaseId);

            if (existing != null)
            {
                switch (dto.UpdateKind)
                {
                    case EnumHelper.TempPurchaseUpdateKind.Price:
                        existing.ApplyPrices(dto.BillPrice, dto.FinalPrice);
                        break;

                    case EnumHelper.TempPurchaseUpdateKind.Metadata:
                        existing.ApplyMetadata(dto.Notes, dto.ExpiryDate);
                        existing.CustomDutyRate = dto.CustomDutyRate;
                        existing.TariffPercent = dto.TariffPercent;
                        existing.ImportCommission = dto.ImportCommission;
                        // 2026-06-29 (Plan 2a): persist ItemVolume so the cart can resync the volume snapshot
                        // from the item after an item-master edit (keeps the readiness chip honest).
                        existing.ItemVolume = dto.ItemVolume;
                        break;

                    case EnumHelper.TempPurchaseUpdateKind.Unit:
                        ApplyKeyboxUnit(existing, dto);
                        break;

                    case EnumHelper.TempPurchaseUpdateKind.QuantityUnit:
                        ApplyKeyboxUnit(existing, dto);
                        if (docType == EnumHelper.PurchaseDocType.Bill)
                            existing.ApplyBillQuantities(dto.OrdQty0, dto.OrdQty1);
                        else
                            existing.ApplyPOQuantities(dto.OrdQty0, dto.OrdQty1, dto.ShipQty);
                        break;

                    case EnumHelper.TempPurchaseUpdateKind.Quantity:
                        if (docType == EnumHelper.PurchaseDocType.Bill)
                            existing.ApplyBillQuantities(dto.OrdQty0, dto.OrdQty1);
                        else
                            existing.ApplyPOQuantities(dto.OrdQty0, dto.OrdQty1, dto.ShipQty);
                        break;

                    case EnumHelper.TempPurchaseUpdateKind.Flag:
                        existing.ApplyFlags(dto.IsFree, dto.IsOut, dto.IsCRCG);
                        existing.ApplyMetadata(dto.Notes, dto.ExpiryDate);
                        if (docType == EnumHelper.PurchaseDocType.Bill)
                            existing.ApplyBillQuantities(dto.OrdQty0, dto.OrdQty1);
                        else
                            existing.ApplyPOQuantities(dto.OrdQty0, dto.OrdQty1, dto.ShipQty);
                        break;

                    case EnumHelper.TempPurchaseUpdateKind.General:
                    default:
                        ApplyLegacyUpdate(existing, dto, docType);
                        break;
                }

                if (existing.PurchaseDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                Uow.TempPurchases.Update(existing);
                Uow.Commit();

                dto.InjectFrom(existing);
            }

            return dto;
        }

        private void ApplyLegacyUpdate(TempPurchase existing, TempPurchaseItem dto, EnumHelper.PurchaseDocType docType)
        {
            // --- NEW: change unit logic (only when keyboxUnit has value) ---
            if (dto.IsUnitChange && dto.LineType == EnumHelper.LineType.I.ToString())
            {
                ApplyKeyboxUnit(existing, dto);
            }

            existing.ApplyCommonEdits(dto.IsFree, dto.IsOut, dto.IsCRCG, dto.BillPrice, dto.FinalPrice, dto.Notes, dto.ExpiryDate);

            if (docType == EnumHelper.PurchaseDocType.Bill)
                existing.ApplyBill(dto.OrdQty0, dto.OrdQty1);
            else
                existing.ApplyPO(dto.OrdQty0, dto.OrdQty1, dto.ShipQty);

            existing.CustomDutyRate = dto.CustomDutyRate;
            existing.TariffPercent = dto.TariffPercent;
            existing.ImportCommission = dto.ImportCommission;
            // 2026-06-29 (Plan 2a): persist ItemVolume so the cart can resync the volume snapshot
            // from the item after an item-master edit (keeps the readiness chip honest).
            existing.ItemVolume = dto.ItemVolume;
        }

        private void ApplyKeyboxUnit(TempPurchase existing, TempPurchaseItem dto)
        {
            if (dto.LineType != EnumHelper.LineType.I.ToString())
                return;

            var resolvedUnit = _itemUnitService.ResolveKeyboxUnit(existing.ItemId ?? 0, dto.Unit);

            if (resolvedUnit != null)
            {
                // update unit on existing
                existing.ApplyUnit(resolvedUnit.Unit, resolvedUnit.ItemUnitId, resolvedUnit.FactorToBase);
            }
        }

        public TempPurchaseItem UpdateUnit(TempPurchaseItem dto)
        {
            var existing = GetById(dto.TempPurchaseId);

            if (existing != null)
            {
                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId ?? 0, existing.Unit);

                existing.ApplyUnit(itemUnit.Unit, itemUnit.ItemUnitId, itemUnit.FactorToBase);

                if (existing.PurchaseDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                Uow.TempPurchases.Update(existing);
                Uow.Commit();

                dto.InjectFrom(existing);
            }

            return dto;
        }

        public void Reorder(TempPurchaseReorderReq reorderReq)
        {
            if (reorderReq.Items.Count == 0)
                throw new ArgumentException("No temp purchase rows provided for reorder.");

            var tempRows = Uow.TempPurchases
                .Find(c => c.EmpId == UserContext.EmpId
                    && c.PayeeId == reorderReq.PayeeId
                    && c.PurchaseId == reorderReq.PurchaseId)
                .ToList();

            if (tempRows.Count == 0)
                throw new KeyNotFoundException("Temp purchase rows not found for reorder.");

            var requestedIds = reorderReq.Items
                .Select(c => c.TempPurchaseId)
                .Distinct()
                .ToList();

            if (requestedIds.Count != reorderReq.Items.Count)
                throw new ArgumentException("Duplicate temp purchase rows found in reorder request.");

            if (requestedIds.Count != tempRows.Count)
                throw new ArgumentException("Reorder request must include every temp purchase row.");

            var existingIds = tempRows.Select(c => c.TempPurchaseId).ToHashSet();

            if (requestedIds.Any(id => !existingIds.Contains(id)))
                throw new ArgumentException("Reorder request contains invalid temp purchase rows.");

            Uow.TempPurchases.Reorder(reorderReq);
        }

        public void Delete(int tempId)
        {
            var temp = Uow.TempPurchases.GetById(tempId);

            if (temp != null)
            {
                if (temp.PurchaseDetailId.HasValue)
                {
                    Uow.TempPurchases.Find(c => c.TempPurchaseId == tempId).ExecuteUpdate(setters => setters.SetProperty(x => x.ChangeStatus, x => EnumHelper.ChangeStatus.D.ToString()));
                }
                else
                {
                    Uow.TempPurchases.Find(c => c.TempPurchaseId == tempId).ExecuteDelete();
                }
            }
        }

        public void Clear(TempPurchaseReq tempReq)
        {
            Uow.TempPurchases.Find(c => c.EmpId == UserContext.EmpId && c.PayeeId == tempReq.PayeeId && c.PurchaseId == tempReq.PurchaseId).ExecuteDelete();
        }

        private TempPurchaseItem AddItem(TempPurchaseItem dto, EnumHelper.PurchaseDocType docType)
        {
            var item = _itemService.GetBySearch(dto.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Product code not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            var tempPurchase = new TempPurchase
            {
                PayeeId = dto.PayeeId,
                PurchaseId = dto.PurchaseId,
                EmpId = UserContext.EmpId,
                ItemId = item.ItemId,
                ItemVolume = item.CaseVolumeInCubicMeter,
                LineType = EnumHelper.LineType.I.ToString(),
                LineId = dto.LineId
            };

            var unit = _itemUnitService.GetBaseUnit(item.ItemId);

            if (!string.IsNullOrEmpty(dto.Unit))
                unit = _itemUnitService.ResolveKeyboxUnit(item.ItemId, dto.Unit);

            // Phase 3: default duty/tariff from the current ItemTariff setup. Preserve NULL rather
            // than coercing to 0 - a NULL line rate means "no rate set" (same signal as no ItemTariff
            // row), which a later allocation precheck can distinguish from a genuine 0% rate. The cart
            // readiness coach and shipment allocation already treat NULL as 0 for their math.
            var itemTariff = GetVendorCountryTariff(item.ItemId, dto.PayeeId);

            if (itemTariff != null)
            {
                tempPurchase.CustomDutyRate = itemTariff.DutyRate;
                tempPurchase.TariffPercent = itemTariff.TariffRate;
            }

            // Default = pure vendor cost (RecentBaseCost); landed RecentCost only as fallback for units not yet backfilled.
            var defaultCost = unit.RecentBaseCost ?? unit.RecentCost ?? 0m;

            var billPrice = (dto.BillPrice.HasValue && dto.BillPrice.Value != 0) ? dto.BillPrice : defaultCost;

            tempPurchase.ApplyCommonEdits(dto.IsFree, dto.IsOut, dto.IsCRCG, billPrice, billPrice, dto.Notes, null);

            tempPurchase.ApplyUnit(unit.Unit, unit.ItemUnitId, unit.FactorToBase);

            if (docType == EnumHelper.PurchaseDocType.Bill)
                tempPurchase.ApplyBill(dto.OrdQty0, dto.OrdQty1);
            else
                tempPurchase.ApplyPO(dto.OrdQty0, dto.OrdQty1, dto.ShipQty);

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            return GetListById(dto.PayeeId, dto.PurchaseId, tempPurchase.TempPurchaseId);
        }

        private TempPurchaseItem AddAccount(TempPurchaseItem tempItem, EnumHelper.PurchaseDocType docType)
        {
            var account = _accountService.CheckAccount(tempItem.ItemCode);

            if (account == null)
                throw new KeyNotFoundException("Account not found");

            if (account.AccountCategory.ClassCode == EnumHelper.AccountClass.I.ToString() || account.AccountCategory.ClassCode == EnumHelper.AccountClass.L.ToString())
                throw new KeyNotFoundException("You can't add Income/Liability account");

            var tempPurchase = new TempPurchase
            {
                PayeeId = tempItem.PayeeId,
                PurchaseId = tempItem.PurchaseId,
                EmpId = UserContext.EmpId,
                AccountId = account.AccountId,
                LineType = EnumHelper.LineType.A.ToString(),
                LineId = tempItem.LineId
            };

            var billPrice = (tempItem.BillPrice.HasValue && tempItem.BillPrice.Value != 0) ? tempItem.BillPrice : 0;

            tempPurchase.ApplyCommonEdits(tempItem.IsFree, tempItem.IsOut, tempItem.IsCRCG, billPrice, billPrice, null, null);

            tempPurchase.ApplyBill(tempItem.OrdQty0, tempItem.OrdQty1);

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            return GetListById(tempItem.PayeeId, tempItem.PurchaseId, tempPurchase.TempPurchaseId);
        }

        // Canonical tariff resolver for PO/Bill line defaulting (Phase 3): the current ItemTariff
        // row for this item + the vendor/payee country resolved to ISO alpha-2. Vendor country is
        // the agreed rule for now (country-of-origin is a later enhancement). A future allocation
        // precheck MUST mirror this exact match (ItemId + alpha-2 CountryCode) to avoid drift.
        private ItemTariff? GetVendorCountryTariff(int itemId, int payeeId)
        {
            var countryCode = GetPayeeAlpha2CountryCode(payeeId);

            if (string.IsNullOrEmpty(countryCode))
                return null;

            return Uow.ItemTariffs
                .Find(c => c.ItemId == itemId && c.CountryCode == countryCode)
                .FirstOrDefault();
        }

        private string? GetPayeeAlpha2CountryCode(int payeeId)
        {
            if (payeeId <= 0)
                return null;

            var payee = Uow.Payees
                .Find(c => c.PayeeId == payeeId)
                .Select(c => new { c.CountryCode, c.Country })
                .FirstOrDefault();

            return ResolveAlpha2CountryCode(payee?.CountryCode)
                ?? ResolveAlpha2CountryCode(payee?.Country);
        }

        private string? ResolveAlpha2CountryCode(string? value)
        {
            var code = value?.Trim();

            if (string.IsNullOrEmpty(code))
                return null;

            var normalized = code.ToUpperInvariant();

            return Uow.Countries
                .Find(c => c.IsActive
                    && (c.ISOAlpha2 == normalized
                        || c.ISOAlpha3 == normalized
                        || c.CountryCode == normalized
                        || c.CountryName == code))
                .Select(c => c.ISOAlpha2)
                .FirstOrDefault();
        }
    }
}
