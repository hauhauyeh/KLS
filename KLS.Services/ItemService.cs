using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services.Items;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemService : BaseService, IItemService
    {
        private readonly ISystemSettingService _systemSettingService;
        private readonly ITwilioService _twilioService;
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ItemService(IUnitOfWork uow,
            ISystemSettingService systemSettingService,
            ITwilioService twilioService,
            IHttpContextAccessor httpContextAccessor) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _twilioService = twilioService;
            _httpContextAccessor = httpContextAccessor;
        }

        public PagingResponse<ItemList> GetPagedList(ItemListReq itemListReq)
        {
            var itemlist = Uow.Items.GetPagedList(itemListReq).ToList();
            var itemIds = itemlist.Select(i => i.ItemId).Distinct().ToList();
            var altUnits = Uow.ItemUnits
                .Find(u => itemIds.Contains(u.ItemId) && !u.IsBaseUnit && !u.Inactive)
                .OrderBy(u => u.ItemId)
                .ThenBy(u => u.ItemUnitId)
                .ToList()
                .GroupBy(u => u.ItemId)
                .ToDictionary(g => g.Key, g => g.First());

            var totalRecords = Uow.Items.Count(itemListReq);

            var request = _httpContextAccessor.HttpContext?.Request;

            string baseUrl = "";
            if (request != null)
                baseUrl = $"{request.Scheme}://{request.Host}";

            foreach (var item in itemlist)
            {
                item.PrimaryImageUrl = string.IsNullOrEmpty(item.PrimaryImageUrl) ? null
                        : baseUrl + item.PrimaryImageUrl;

                if (altUnits.TryGetValue(item.ItemId, out var altUnit))
                {
                    item.AltItemUnitId = altUnit.ItemUnitId;
                    item.AltUnit = altUnit.Unit;
                    item.AltFactorToBase = altUnit.FactorToBase;
                    item.AltMultipleToBase = altUnit.MultipleToBase;  // for the read-only ×N / ÷N ratio badge (A.5)
                    item.AltPricePercentToBase = altUnit.PricePercentToBase;
                    item.AltP1 = altUnit.P1;
                }
            }

            return new PagingResponse<ItemList>(totalRecords, itemListReq.Pageno, itemListReq.Pagesize)
            {
                RowData = itemlist,
            };
        }

        public IEnumerable<ItemSearch> ActiveItems()
        {
            return Uow.Items.Find(i => i.Inactive == false).OrderBy(i => i.ItemName)
                .Select(i => new ItemSearch
                {
                    ItemId = i.ItemId,
                    ItemName = i.ItemName,
                    ItemCode = i.ItemCode,
                    Inactive = i.Inactive,
                }).ToList();
        }

        public Item? GetById(int itemId)
        {
            var item = new Item();

            if (itemId > 0)
            {
                item = Uow.Items.GetById(itemId);

                item.ItemUnits = Uow.ItemUnits.Find(c => c.ItemId == itemId).ToList();

                //var cataog = from c in Uow.ItemCatalog.GetAll()
                //             join ic in Uow.ItemCatalogMap.GetAll() on c.CatalogId equals ic.CatalogId
                //             where ic.ItemId == itemId
                //             select c;

                //item.CatalogMaps = cataog.ToList();
            }
            else
            {
                item = new Item
                {
                    PaletteFactor = 50,
                    IsTaxable = _systemSettingService.GetByKey<bool>(GlobalKey.ITEM_DEFAULT_TAXABLE),
                    ItemType = _systemSettingService.GetByKey<string>(GlobalKey.ITEM_DEFAULT_TYPE)
                };
            }

            item.DefaultRetailPercent = _systemSettingService.GetByKey<decimal>(GlobalKey.ITEM_DEFAULT_RETAILPROFIT);

            return item;
        }

        public IEnumerable<Item> GetByIds(IEnumerable<int> itemIds)
        {
            var idList = itemIds.Distinct().ToList();
            return Uow.Items.Find(x => idList.Contains(x.ItemId)).ToList();
        }

        public Item? GetByItemCode(string? itemCode)
        {
            return Uow.Items.Find(c => c.ItemCode == itemCode).FirstOrDefault();
        }

        public Item? GetByItemName(string itemName)
        {
            return Uow.Items.Find(c => c.ItemName == itemName).FirstOrDefault();
        }

        public Item? GetBySearch(string itemCode)
        {
            if (string.IsNullOrEmpty(itemCode))
                return null;

            var item = GetByItemCode(itemCode);

            if (item == null)
            {
                item = GetByItemName(itemCode);
            }

            return item;
        }

        public IEnumerable<ItemSearch>? Search(ItemSearchReq searchReq)
        {
            return Uow.Items.Search(searchReq);
        }

        public void Delete(int itemId)
        {
            Uow.Items.Delete(itemId);
        }

        public void Inactive(int itemId)
        {
            Uow.Items.Find(c => c.ItemId == itemId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Inactive, x => !x.Inactive)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public bool ItemCodeExists(Item item)
        {
            return Uow.Items.Exists(c => c.ItemCode.ToLower() == item.ItemCode.ToLower() && c.ItemId != item.ItemId);
        }

        public bool ItemNameExists(Item item)
        {
            return Uow.Items.Exists(c => c.ItemName.ToLower() == item.ItemName.ToLower() && c.ItemId != item.ItemId);
        }

        public Item? Save(Item item)
        {
            if (item.ItemId > 0)
            {
                var oldItem = GetById(item.ItemId);

                if (oldItem != null)
                {
                    oldItem.ItemType = item.ItemType;
                    oldItem.CategoryId = item.CategoryId;
                    oldItem.StorageId = item.StorageId;
                    oldItem.ItemCode = item.ItemCode;
                    oldItem.ItemName = item.ItemName;
                    oldItem.ItemName2 = item.ItemName2;
                    oldItem.ItemSearchTag = item.ItemSearchTag;
                    oldItem.ItemBoxDesc = item.ItemBoxDesc;
                    oldItem.ItemLongDesc = item.ItemLongDesc;
                    oldItem.ItemBrand = item.ItemBrand;

                    oldItem.SetPacking = item.SetPacking;
                    oldItem.PackSize = item.PackSize;

                    oldItem.PreferredVendorId = item.PreferredVendorId;
                    oldItem.PaletteFactor = item.PaletteFactor;
                    oldItem.SaftyInventory = item.SaftyInventory;
                    oldItem.ActualSaftyInventory = item.ActualSaftyInventory;
                    oldItem.RefillInventory = item.RefillInventory;
                    oldItem.CaseWeight = item.CaseWeight;
                    oldItem.CaseVolumeInCubicMeter = item.CaseVolumeInCubicMeter;
                    oldItem.CaseLength = item.CaseLength;
                    oldItem.CaseWidth = item.CaseWidth;
                    oldItem.CaseHeight = item.CaseHeight;

                    oldItem.Inactive = item.Inactive;
                    oldItem.IsTaxable = item.IsTaxable;
                    // 2026-05-16 sales-tax-cleanup
                    // oldItem.IsHRExempt = item.IsHRExempt;
                    oldItem.IsHRTaxable = item.IsHRTaxable;
                    oldItem.IsHighlighted = item.IsHighlighted;

                    oldItem.UpdatedAt = DateTime.UtcNow;

                    Uow.Items.Update(oldItem);
                    Uow.Commit();
                }

                // --- sync ItemUnits (add / update) ---
                var existingUnits = Uow.ItemUnits
                    .Find(c => c.ItemId == item.ItemId)
                    .ToList();

                if (item.ItemUnits != null)
                {
                    Uow.ItemUnits.Find(x => x.ItemId == item.ItemId).ExecuteUpdate(s => s.SetProperty(x => x.IsDefaultSalesUnit, false));

                    foreach (var unit in item.ItemUnits)
                    {
                        if (unit.ItemUnitId == 0)
                        {
                            var baseUnitCost = existingUnits.FirstOrDefault(u => u.IsBaseUnit)?.RecentCost;

                            // NEW UNIT: add
                            unit.ItemId = item.ItemId;
                            unit.RecentCost = baseUnitCost / unit.FactorToBase;
                            Uow.ItemUnits.Add(unit);
                        }
                        else
                        {
                            // EXISTING UNIT: update
                            var dbUnit = existingUnits
                                .FirstOrDefault(u => u.ItemUnitId == unit.ItemUnitId);

                            if (dbUnit != null)
                            {
                                // Immutability (master plan §5.1/§5.2, "saved => immutable"): a saved unit's
                                // ratio is frozen. Do NOT reassign FactorToBase/MultipleToBase on an existing
                                // unit; reject an ACTUAL change (unchanged resend is a harmless no-op). To
                                // correct a ratio, inactivate this unit and add a new one. This also blocks
                                // rebasing a saved item (Set Base Unit rewrites a saved factor) -- by design.
                                if (unit.FactorToBase != dbUnit.FactorToBase || unit.MultipleToBase != dbUnit.MultipleToBase)
                                    throw new InvalidOperationException(
                                        "Cannot change the unit ratio on a saved unit. Inactivate this unit and add a new one instead.");

                                dbUnit.Unit = unit.Unit;
                                // FactorToBase / MultipleToBase intentionally NOT reassigned (immutable on saved units).
                                dbUnit.IsDefaultSalesUnit = unit.IsDefaultSalesUnit;
                                dbUnit.PricePercentToBase = unit.IsBaseUnit ? null : unit.PricePercentToBase;
                                dbUnit.Barcode = unit.Barcode?.Trim();
                                dbUnit.P1 = unit.P1;
                                dbUnit.MSRP = unit.MSRP;
                                dbUnit.MarketPrice = unit.MarketPrice;
                                dbUnit.Inactive = unit.Inactive;

                                Uow.ItemUnits.Update(dbUnit);
                            }
                        }
                    }
                }

                Uow.Commit();

                // Backend is authoritative on SetPacking. Reload units fresh
                // (newly Added units may not be reflected in oldItem.ItemUnits
                // navigation) and write the canonical value.
                ItemSetPackingRecomputer.Apply(Uow, item.ItemId);
            }
            else
            {
                Uow.Items.Add(item);
                Uow.Commit();

                // Canonicalize SetPacking from the persisted units.
                ItemSetPackingRecomputer.Apply(Uow, item.ItemId);
            }

            //var mapItems = Uow.ItemCatalogMap.Filter(c => c.ItemId == item.ItemId).ToList();

            //foreach (var mapItem in mapItems)
            //{
            //    Uow.ItemCatalogMap.Delete(mapItem);
            //}

            //Uow.Commit();

            //if (item.CatalogMaps != null && item.CatalogMaps.Count > 0)
            //{
            //    foreach (var catalog in item.CatalogMaps)
            //    {
            //        var mapItem = new ItemCatalogMap
            //        {
            //            ItemId = item.ItemId,
            //            CatalogId = catalog.CatalogId
            //        };

            //        Uow.ItemCatalogMap.Add(mapItem);
            //    }

            //    Uow.Commit();
            //}

            return GetById(item.ItemId);
        }

        public IEnumerable<ItemCalcUnit> GetCalcUnit(ItemPackingReq packingReq)
        {
            return Uow.Items.GetCalcUnit(packingReq);
        }

        public ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail)
        {
            return Uow.Items.CalcRetailPriceProfit(calcRetail);
        }

        public void UpdateBaseP1(ItemUpdateReq updateReq)
        {
            Uow.Items.UpdateBaseP1(updateReq);
        }

        public void UpdateInventorySettings(ItemInventorySettingsReq req)
        {
            var item = GetById(req.ItemId);
            if (item == null) return;

            if (req.ActualSaftyInventory.HasValue) item.ActualSaftyInventory = req.ActualSaftyInventory;
            if (req.RefillInventory.HasValue) item.RefillInventory = req.RefillInventory;

            if (req.CaseLength.HasValue) item.CaseLength = req.CaseLength;
            if (req.CaseWidth.HasValue) item.CaseWidth = req.CaseWidth;
            if (req.CaseHeight.HasValue) item.CaseHeight = req.CaseHeight;
            if (req.CaseWeight.HasValue) item.CaseWeight = req.CaseWeight;

            if (req.IsVolumeManual.HasValue)
                item.IsVolumeManual = req.IsVolumeManual.Value;

            if (req.CaseVolumeInCubicMeter.HasValue)
                item.CaseVolumeInCubicMeter = req.CaseVolumeInCubicMeter;
            else if (!item.IsVolumeManual
                && item.CaseLength.HasValue && item.CaseLength > 0
                && item.CaseWidth.HasValue && item.CaseWidth > 0
                && item.CaseHeight.HasValue && item.CaseHeight > 0)
            {
                item.CaseVolumeInCubicMeter = Math.Round(
                    (item.CaseLength.Value / 100m) * (item.CaseWidth.Value / 100m) * (item.CaseHeight.Value / 100m), 4);
            }

            item.UpdatedAt = DateTime.UtcNow;
            Uow.Items.Update(item);
            Uow.Commit();
        }

        public IEnumerable<ItemSearch> GetSearchList(int payeeId, string mode = "customer")
        {
            return Uow.Items.GetSearchList(payeeId, mode);
        }


        public PagingResponse<ItemWebList> GetWebPagedList(ItemWebListReq webListReq)
        {
            webListReq.PayeeId = UserContext.EmpId;

            return BuildWebPagedList(webListReq, false);
        }

        public PagingResponse<ItemWebList> GetPublicWebPagedList(ItemWebListReq webListReq)
        {
            webListReq.PayeeId = 0;

            return BuildWebPagedList(webListReq, true);
        }

        private PagingResponse<ItemWebList> BuildWebPagedList(ItemWebListReq webListReq, bool forceBasePrice)
        {
            var rows = Uow.Items.GetWebPagedList(webListReq).ToList();
            var totalRecords = Uow.Items.WebCount(webListReq);
            var unitIds = rows.Where(x => x.ItemUnitId > 0).Select(x => x.ItemUnitId).Distinct().ToArray();
            var basePrices = forceBasePrice
                ? Uow.ItemUnits.Find(x => unitIds.Contains(x.ItemUnitId)).ToDictionary(x => x.ItemUnitId, x => x)
                : new Dictionary<int, ItemUnit>();

            string baseUrl = GetbaseUrl();

            var dict = new Dictionary<int, ItemWebList>();

            foreach (var row in rows)
            {
                if (!dict.TryGetValue(row.ItemId, out var item))
                {
                    item = new ItemWebList
                    {
                        ItemId = row.ItemId,
                        ItemCode = row.ItemCode,
                        ItemName = row.ItemName,
                        ItemName2 = row.ItemName2,
                        ItemLongDesc = row.ItemLongDesc,
                        SetPacking = row.SetPacking,
                        PackSize = row.PackSize,
                        LCloseQty = row.LCloseQty,
                        ExpiryDate = row.ExpiryDate,
                        PrimaryImageUrl = string.IsNullOrEmpty(row.PrimaryImageUrl)
                            ? null
                            : baseUrl + row.PrimaryImageUrl,
                        ItemUnits = [],
                    };

                    dict.Add(row.ItemId, item);
                }

                // Units
                if (row.ItemUnitId > 0 && !item.ItemUnits!.Any(x => x.ItemUnitId == row.ItemUnitId))
                {
                    item.ItemUnits!.Add(new ItemWebUnitList
                    {
                        ItemUnitId = row.ItemUnitId,
                        Unit = row.Unit,
                        Barcode = string.IsNullOrWhiteSpace(row.Barcode)
                            ? row.Barcode
                            : Utilities.EAN13(row.Barcode),
                        IsBaseUnit = row.IsBaseUnit,
                        IsDefaultSalesUnit = row.IsDefaultSalesUnit,
                        MSRP = row.MSRP,
                        MarketPrice = row.MarketPrice,
                        Price = forceBasePrice && basePrices.TryGetValue(row.ItemUnitId, out var unit)
                            ? unit.P1
                            : row.Price,
                        Discount = row.Discount
                    });
                }
            }

            var itemIds = dict.Keys.ToArray();
            var allImages = Uow.ItemImages
                .Find(c => itemIds.Contains(c.ItemId))
                .OrderBy(c => c.SortOrder)
                .ToList();
            var imagesByItem = allImages.GroupBy(c => c.ItemId);

            foreach (var group in imagesByItem)
            {
                if (dict.TryGetValue(group.Key, out var item))
                {
                    var imageCount = group.Count();
                    item.Images = group.Select(c => ItemImageService.BuildImageDto(c, baseUrl, imageCount)).ToList();
                }
            }

            return new PagingResponse<ItemWebList>(totalRecords, webListReq.Pageno, webListReq.Pagesize)
            {
                RowData = dict.Values.ToList(),
            };
        }

        public IEnumerable<ItemWebSearchList>? WebSearch(string searchTerm)
        {
            return BuildWebSearch(searchTerm);
        }

        public IEnumerable<ItemWebSearchList>? PublicWebSearch(string searchTerm)
        {
            return BuildWebSearch(searchTerm);
        }

        private IEnumerable<ItemWebSearchList>? BuildWebSearch(string searchTerm)
        {
            // 2026-05-07: ItemSearchReq.IsActiveOnly was replaced by two ambient bits
            // (ShowInactive / ShowDeleted), both default false. The old "IsActiveOnly = true"
            // (active-only) maps cleanly to both bits = false, so this just constructs an
            // empty-defaulted req. Old:
            //   var items = Uow.Items.Search(new ItemSearchReq { IsActiveOnly = true, Term = searchTerm })?.ToList();
            var items = Uow.Items.Search(new ItemSearchReq { Term = searchTerm })?.ToList();

            string baseUrl = GetbaseUrl();

            return items?.Select(c => new ItemWebSearchList
            {
                ItemId = c.ItemId,
                ItemCode = c.ItemCode,
                ItemName = c.ItemName,
                PrimaryImageUrl = string.IsNullOrEmpty(c.PrimaryImageUrl)
                            ? null
                            : baseUrl + c.PrimaryImageUrl,
            });
        }

        private string GetbaseUrl()
        {
            var request = _httpContextAccessor.HttpContext?.Request;
            string baseUrl = "";
            if (request != null)
                baseUrl = $"{request.Scheme}://{request.Host}";

            return baseUrl;
        }
    }
}
