using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempInventoryAdjService : BaseService, ITempInventoryAdjService
    {
        private readonly IItemService _itemService;

        public TempInventoryAdjService(IUnitOfWork uow, IItemService itemService) : base(uow)
        {
            _itemService = itemService;
        }

        public IEnumerable<TempInventoryItem>? GetTempAdjItems(TempInventoryReq tempReq)
        {
            return Uow.TempInventoryAdjs.GetTempAdjItems(tempReq);
        }

        public TempInventoryItem CreateTempItem(TempInventoryItem tempItem)
        {
            var item = _itemService.GetBySearch(tempItem.ItemCode);

            if (item == null)
                throw new InvalidOperationException("Item code not found");

            if (item.Inactive)
                throw new InvalidOperationException("This product already discontinue");

            var itemExist = Uow.TempInventoryAdjs.Exists(c => c.EmpId == UserContext.EmpId && c.ItemId == item.ItemId && c.AdjId == tempItem.AdjId);

            if (itemExist)
                throw new InvalidOperationException("Item already in the list");

            tempItem.ItemCode = item.ItemCode;
            tempItem.ItemName = item.ItemName;
            tempItem.ItemId = item.ItemId;
            tempItem.PackSize = item.PackSize;
            tempItem.NewQty = tempItem.NewQty ?? 0;
            tempItem.NewPrice = 0;

            var tempAdj = new TempInventoryAdj();
            tempAdj.InjectFrom(tempItem);
            tempAdj.ChangeStatus = EnumHelper.ChangeStatus.I.ToString();
            tempAdj.QtyDiffer = 0;
            tempAdj.EmpId = UserContext.EmpId;

            Uow.TempInventoryAdjs.Add(tempAdj);
            Uow.Commit();

            tempItem.TempAdjId = tempAdj.TempAdjId;

            return tempItem;
        }

        public void UpdateTempItem(TempInventoryAdj tempAdj)
        {
            var existing = Uow.TempInventoryAdjs.GetById(tempAdj.TempAdjId);

            if (existing != null)
            {
                existing.NewQty = tempAdj.NewQty;
                existing.NewPrice = tempAdj.NewPrice;
                existing.Notes = tempAdj.Notes;

                if (existing.AdjDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                Uow.TempInventoryAdjs.Update(existing);
                Uow.Commit();
            }
        }

        public void DeleteTempItem(int tempAdjId)
        {
            var temp = Uow.TempInventoryAdjs.GetById(tempAdjId);

            if (temp != null)
            {
                if (temp.AdjDetailId.HasValue)
                {
                    temp.ChangeStatus = EnumHelper.ChangeStatus.D.ToString();
                    Uow.TempInventoryAdjs.Update(temp);
                }
                else
                {
                    Uow.TempInventoryAdjs.RemoveById(tempAdjId);
                }

                Uow.Commit();
            }
        }

        public void ClearTempItem(TempInventoryReq tempReq)
        {
            Uow.TempInventoryAdjs.Find(c => c.EmpId == UserContext.EmpId && c.AdjId == tempReq.AdjId).ExecuteDelete();
        }
    }
}
