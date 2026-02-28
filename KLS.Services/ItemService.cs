using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Polly.Caching;
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

            var totalRecords = Uow.Items.Count(itemListReq);

            var request = _httpContextAccessor.HttpContext?.Request;

            string baseUrl = "";
            if (request != null)
                baseUrl = $"{request.Scheme}://{request.Host}";

            foreach (var item in itemlist)
            {
                item.PrimaryImageUrl = string.IsNullOrEmpty(item.PrimaryImageUrl) ? null
                        : baseUrl + item.PrimaryImageUrl;
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
                    oldItem.ItemSearchTag = item.ItemSearchTag;
                    oldItem.ItemBoxDesc = item.ItemBoxDesc;
                    oldItem.ItemLongDesc = item.ItemLongDesc;
                    oldItem.ItemBrand = item.ItemBrand;

                    oldItem.SetPacking = item.SetPacking;
                    oldItem.PackSize = item.PackSize;

                    oldItem.PreferredVendorId = item.PreferredVendorId;
                    oldItem.PaletteFactor = item.PaletteFactor;
                    oldItem.SaftyInventory = item.SaftyInventory;
                    oldItem.CaseWeight = item.CaseWeight;
                    oldItem.CaseVolumeInCubicMeter = item.CaseVolumeInCubicMeter;
                    oldItem.CaseLength = item.CaseLength;
                    oldItem.CaseWidth = item.CaseWidth;
                    oldItem.CaseHeight = item.CaseHeight;

                    oldItem.Inactive = item.Inactive;
                    oldItem.IsTaxable = item.IsTaxable;
                    oldItem.IsHRExempt = item.IsHRExempt;
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
                                dbUnit.Unit = unit.Unit;
                                dbUnit.FactorToBase = unit.IsBaseUnit ? 1 : unit.FactorToBase;
                                dbUnit.IsDefaultSalesUnit = unit.IsDefaultSalesUnit;
                                //dbUnit.PricePercentToBase = unit.PricePercentToBase;
                                dbUnit.Barcode = unit.Barcode;
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
            }
            else
            {
                Uow.Items.Add(item);
                Uow.Commit();
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

        public ItemDefaultFreight GetDefaultFreight(int itemId)
        {
            return Uow.Items.GetDefaultFreight(itemId);
        }

        public void SaveFreight(ItemDefaultFreight defaultFreight)
        {
            var item = GetById(defaultFreight.ItemId);

            if (item != null)
            {
                item.PaletteFactor = defaultFreight.PaletteFactor;
                item.UpdatedAt = DateTime.UtcNow;

                Uow.Items.Update(item);
                Uow.Commit();
            }

            if (defaultFreight.PayeeId.HasValue)
            {
                var payee = Uow.Vendors.GetById(defaultFreight.PayeeId.Value);

                if (payee != null)
                {
                    payee.FreightRate = defaultFreight.FreightRate;

                    Uow.Vendors.Update(payee);
                    Uow.Commit();
                }
            }
        }

        //public void UpdateDefautCost(int itemId, decimal? defaultCost)
        //{
        //    var item = GetById(itemId);

        //    if (item != null && item.ItemId > 0)
        //    {
        //        if (item.DefaultCost != defaultCost)
        //        {
        //            item.DefaultCostB4 = item.DefaultCost;
        //            item.DefaultCost = defaultCost;

        //            Uow.Items.Update(item);
        //            Uow.Commit();

        //            SendCostChangeNotification(item);
        //        }
        //    }
        //}

        //public Item UpdateP1(int itemId, decimal? p1)
        //{
        //    var item = GetById(itemId);

        //    if (item != null)
        //    {
        //        item.P1 = p1;
        //        item.UpdatedAt = DateTime.UtcNow;

        //        var calcPrice = CalcRetailPriceProfit(new ItemCalcRetail
        //        {
        //            P1 = p1,
        //            RetailUnit = item.RetailUnit,
        //            RetailFactor = item.RetailFactor,
        //            RetailProfitPercent = item.RetailProfitPercent
        //        });

        //        item.RetailPrice = calcPrice.RetailPrice;

        //        Uow.Items.Update(item);
        //        Uow.Commit();
        //    }

        //    return item!;
        //}

        //public Item UpdateRetailPrice(int itemId, decimal? retailPrice)
        //{
        //    var item = GetById(itemId);

        //    if (item != null)
        //    {
        //        item.RetailPrice = retailPrice;
        //        item.UpdatedAt = DateTime.UtcNow;

        //        var calcPrice = CalcRetailPriceProfit(new ItemCalcRetail
        //        {
        //            P1 = item.P1,
        //            RetailUnit = item.RetailUnit,
        //            RetailFactor = item.RetailFactor,
        //            RetailPrice = retailPrice
        //        });

        //        item.RetailProfitPercent = calcPrice.RetailProfitPercent;

        //        Uow.Items.Update(item);
        //        Uow.Commit();
        //    }

        //    return item!;
        //}

        //public Item UpdateRetailProfit(int itemId, decimal? retailProfit)
        //{
        //    var item = GetById(itemId);

        //    if (item != null)
        //    {
        //        item.RetailProfitPercent = Utilities.Rounding(retailProfit / 100, 4);
        //        item.UpdatedAt = DateTime.UtcNow;

        //        var calcPrice = CalcRetailPriceProfit(new ItemCalcRetail
        //        {
        //            P1 = item.P1,
        //            RetailUnit = item.RetailUnit,
        //            RetailFactor = item.RetailFactor,
        //            RetailProfitPercent = item.RetailProfitPercent
        //        });

        //        item.RetailPrice = calcPrice.RetailPrice;

        //        Uow.Items.Update(item);
        //        Uow.Commit();
        //    }

        //    return item!;
        //}

        //public void SendCostChangeNotification(Item item)
        //{
        //    var perc = (item.DefaultCost - item.DefaultCostB4) / (item.DefaultCostB4 == 0 ? 1 : item.DefaultCostB4);

        //    perc = Math.Abs(Utilities.Rounding(perc, 2) ?? 0) * 100;

        //    if (perc > 10)
        //    {
        //        var msg = "";

        //        if (item.DefaultCost > item.DefaultCostB4)
        //            msg = "(" + item.ItemCode + ") " + item.ItemName + " +" + perc + "% to " + string.Format("{0:c}", item.DefaultCost);
        //        else
        //            msg = "(" + item.ItemCode + ") " + item.ItemName + " -" + perc + "% to " + string.Format("{0:c}", item.DefaultCost);

        //        var employee = (from p in Uow.Payees.GetAll()
        //                        join e in Uow.Employees.GetAll()
        //                        on p.PayeeId equals e.PayeeId
        //                        where e.IsPriceChangeNotify == true && p.IsClosed == false
        //                        select p).AsEnumerable();

        //        foreach (var emp in employee)
        //        {
        //            if (!string.IsNullOrEmpty(emp.Phone1))
        //                _twilioService.SendMessage(emp.Phone1, msg);
        //        }
        //    }
        //}
    }
}
