using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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

        public ItemService(IUnitOfWork uow, ISystemSettingService systemSettingService, ITwilioService twilioService) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _twilioService = twilioService;
        }

        public PagingResponse<ItemList> GetAllItems(ItemListReq itemListReq)
        {
            var itemlist = Uow.Items.GetAllItems(itemListReq);

            var totalRecords = Uow.Items.CountAllItems(itemListReq);

            return new PagingResponse<ItemList>(totalRecords, itemListReq.Pageno, itemListReq.Pagesize)
            {
                RowData = itemlist,
            };
        }

        public Item? GetById(int itemId)
        {
            if (itemId > 0)
            {
                var item = Uow.Items.GetById(itemId);

                //var cataog = from c in Uow.ItemCatalog.GetAll()
                //             join ic in Uow.ItemCatalogMap.GetAll() on c.CatalogId equals ic.CatalogId
                //             where ic.ItemId == itemId
                //             select c;

                //item.CatalogMaps = cataog.ToList();

                return item;
            }
            else
            {
                return new Item
                {
                    PaletteFactor = 50,
                    DefaultUnit = EnumHelper.ItemDefaultUnit.Whole.ToString(),
                    RetailFactor = 1,
                    RetailPrice = 0,
                    DefaultCost = 0,
                    RetailProfitPercent = _systemSettingService.GetByKey<decimal>(GlobalKey.ITEM_DEFAULT_RETAILPROFIT),
                    IsTaxable = _systemSettingService.GetByKey<bool>(GlobalKey.ITEM_DEFAULT_TAXABLE),
                    ItemType = _systemSettingService.GetByKey<string>(GlobalKey.ITEM_DEFAULT_TYPE)
                };
            }
        }

        public Item? GetByItemCode(string? itemCode)
        {
            return Uow.Items.Find(c => c.ItemCode == itemCode).FirstOrDefault();
        }

        public Item? GetByItemName(string itemName)
        {
            return Uow.Items.Find(c => c.ItemName == itemName).FirstOrDefault();
        }

        public Item? GetByBarcodeW(string barcodeW)
        {
            return Uow.Items.Find(c => c.BarcodeW == barcodeW).FirstOrDefault();
        }

        public Item? GetByBarcodeR(string barcodeR)
        {
            return Uow.Items.Find(c => c.BarcodeR == barcodeR).FirstOrDefault();
        }

        public Item? GetBySearch(string itemCode)
        {
            if (string.IsNullOrEmpty(itemCode))
                return null;

            var item = GetByItemCode(itemCode);

            if (item == null)
            {
                item = GetByItemName(itemCode);

                if (item == null)
                {
                    item = GetByBarcodeW(itemCode);

                    if (item == null)
                        item = GetByBarcodeR(itemCode);
                }
            }

            return item;
        }

        public IEnumerable<ItemSearch>? SearchItem(ItemSearchReq searchReq)
        {
            return Uow.Items.SearchItem(searchReq);
        }

        public void DeleteItem(int itemId)
        {
            Uow.Items.DeleteItem(itemId);
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

        public Item? SaveItem(Item item)
        {
            if (item.ItemId > 0)
            {
                var oldItem = GetById(item.ItemId);

                if (oldItem != null)
                {
                    oldItem.ItemType = item.ItemType;
                    oldItem.CategoryId = item.CategoryId;
                    oldItem.StorageId = item.StorageId;
                    oldItem.BarcodeW = item.BarcodeW;
                    oldItem.ItemCode = item.ItemCode;
                    oldItem.ItemName = item.ItemName;
                    oldItem.ItemSearchTag = item.ItemSearchTag;
                    oldItem.ItemForeignName = item.ItemForeignName;
                    //oldItem.SpanishDesc = item.SpanishDesc;
                    oldItem.ItemBoxDesc = item.ItemBoxDesc;
                    oldItem.ItemLongDesc = item.ItemLongDesc;
                    oldItem.ItemBrand = item.ItemBrand;

                    oldItem.PackSize = item.PackSize;
                    oldItem.Pack1 = item.Pack1;
                    oldItem.DefaultUnit = item.DefaultUnit;
                    oldItem.WholeUnit = item.WholeUnit;
                    oldItem.DisplayUnit = item.DisplayUnit;
                    oldItem.RetailUnit = item.RetailUnit;
                    oldItem.RetailFactor = item.RetailFactor;
                    oldItem.RetailProfitPercent = item.RetailProfitPercent;
                    oldItem.RetailPrice = item.RetailPrice;

                    oldItem.DefaultCost = item.DefaultCost;
                    oldItem.RecentCost = item.RecentCost;
                    oldItem.P1 = item.P1;
                    oldItem.MSRP = item.MSRP;

                    oldItem.PreferredVendorId = item.PreferredVendorId;
                    oldItem.PaletteFactor = item.PaletteFactor;
                    oldItem.SaftyInventory = item.SaftyInventory;
                    oldItem.CaseWeight = item.CaseWeight;
                    oldItem.CaseVolume = item.CaseVolume;
                    oldItem.CaseLength = item.CaseLength;
                    oldItem.CaseWidth = item.CaseWidth;
                    oldItem.CaseHeight = item.CaseHeight;
                    oldItem.AisleNumber = item.AisleNumber;
                    oldItem.BayNumber = item.BayNumber;

                    oldItem.Inactive = item.Inactive;
                    oldItem.IsTaxable = item.IsTaxable;
                    oldItem.IsHRExempt = item.IsHRExempt;
                    oldItem.IsHighlighted = item.IsHighlighted;
                    oldItem.IsLabelPrint = item.IsLabelPrint;
                    oldItem.IsSameDayReturn = item.IsSameDayReturn;

                    oldItem.UpdatedAt = DateTime.UtcNow;

                    Uow.Items.Update(oldItem);
                    Uow.Commit();
                }
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

        public ItemCalcUnit GetCalcUnit(ItemPackingReq packingReq)
        {
            return Uow.Items.GetCalcUnit(packingReq);
        }

        public ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail)
        {
            return Uow.Items.CalcRetailPriceProfit(calcRetail);
        }

        public void UpdateDefautCost(int itemId, decimal? defaultCost)
        {
            var item = GetById(itemId);

            if (item != null && item.ItemId > 0)
            {
                if (item.DefaultCost != defaultCost)
                {
                    item.DefaultCostB4 = item.DefaultCost;
                    item.DefaultCost = defaultCost;

                    Uow.Items.Update(item);
                    Uow.Commit();

                    SendCostChangeNotification(item);
                }
            }
        }

        public Item UpdateP1(int itemId, decimal? p1)
        {
            var item = GetById(itemId);

            if (item != null)
            {
                item.P1 = p1;
                item.UpdatedAt = DateTime.UtcNow;

                var calcPrice = CalcRetailPriceProfit(new ItemCalcRetail
                {
                    P1 = p1,
                    RetailUnit = item.RetailUnit,
                    RetailFactor = item.RetailFactor,
                    RetailProfitPercent = item.RetailProfitPercent
                });

                item.RetailPrice = calcPrice.RetailPrice;

                Uow.Items.Update(item);
                Uow.Commit();
            }

            return item!;
        }

        public Item UpdateRetailPrice(int itemId, decimal? retailPrice)
        {
            var item = GetById(itemId);

            if (item != null)
            {
                item.RetailPrice = retailPrice;
                item.UpdatedAt = DateTime.UtcNow;

                var calcPrice = CalcRetailPriceProfit(new ItemCalcRetail
                {
                    P1 = item.P1,
                    RetailUnit = item.RetailUnit,
                    RetailFactor = item.RetailFactor,
                    RetailPrice = retailPrice
                });

                item.RetailProfitPercent = calcPrice.RetailProfitPercent;

                Uow.Items.Update(item);
                Uow.Commit();
            }

            return item!;
        }

        public Item UpdateRetailProfit(int itemId, decimal? retailProfit)
        {
            var item = GetById(itemId);

            if (item != null)
            {
                item.RetailProfitPercent = Utilities.Rounding(retailProfit / 100, 4);
                item.UpdatedAt = DateTime.UtcNow;

                var calcPrice = CalcRetailPriceProfit(new ItemCalcRetail
                {
                    P1 = item.P1,
                    RetailUnit = item.RetailUnit,
                    RetailFactor = item.RetailFactor,
                    RetailProfitPercent = item.RetailProfitPercent
                });

                item.RetailPrice = calcPrice.RetailPrice;

                Uow.Items.Update(item);
                Uow.Commit();
            }

            return item!;
        }

        public void SendCostChangeNotification(Item item)
        {
            var perc = (item.DefaultCost - item.DefaultCostB4) / (item.DefaultCostB4 == 0 ? 1 : item.DefaultCostB4);

            perc = Math.Abs(Utilities.Rounding(perc, 2) ?? 0) * 100;

            if (perc > 10)
            {
                var msg = "";

                if (item.DefaultCost > item.DefaultCostB4)
                    msg = "(" + item.ItemCode + ") " + item.ItemName + " +" + perc + "% to " + string.Format("{0:c}", item.DefaultCost);
                else
                    msg = "(" + item.ItemCode + ") " + item.ItemName + " -" + perc + "% to " + string.Format("{0:c}", item.DefaultCost);

                var employee = (from p in Uow.Payees.GetAll()
                                join e in Uow.Employees.GetAll()
                                on p.PayeeId equals e.PayeeId
                                where e.IsPriceChangeNotify == true && p.IsClosed == false
                                select p).AsEnumerable();

                foreach (var emp in employee)
                {
                    if (!string.IsNullOrEmpty(emp.Phone1))
                        _twilioService.SendMessage(emp.Phone1, msg);
                }
            }
        }
    }
}
