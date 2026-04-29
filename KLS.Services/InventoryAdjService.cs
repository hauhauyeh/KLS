using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Diagnostics;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class InventoryAdjService : BaseService, IInventoryAdjService
    {
        private readonly IDeleteLogService _deleteLogService;
        private readonly ILogger<InventoryAdjService> _logger;

        public InventoryAdjService(IUnitOfWork uow, IDeleteLogService deleteLogService, ILogger<InventoryAdjService> logger) : base(uow)
        {
            _deleteLogService = deleteLogService;
            _logger = logger;
        }

        public PagingResponse<InventoryAdjList> GetPagedList(InventoryAdjListReq inventoryAdjListReq)
        {
            var list = Uow.InventoryAdjs.GetPagedList(inventoryAdjListReq);

            var totalRecords = Uow.InventoryAdjs.Count(inventoryAdjListReq);

            return new PagingResponse<InventoryAdjList>(totalRecords, inventoryAdjListReq.Pageno, inventoryAdjListReq.Pagesize)
            {
                RowData = list,
            };
        }

        public IEnumerable<InventoryAdjList> GetHistoryByItem(int itemId)
        {
            return Uow.InventoryAdjs.GetHistoryByItem(itemId);
        }

        public InventoryAdj GetById(int adjId)
        {
            return Uow.InventoryAdjs.GetById(adjId);
        }

        public IEnumerable<InventoryAdjList> GetListById(int adjId)
        {
            var listReq = new InventoryAdjListReq
            {
                Id = adjId
            };

            return Uow.InventoryAdjs.GetPagedList(listReq);
        }

        public int Save(InventoryAdj inventoryAdj)
        {
            var totalSw = Stopwatch.StartNew();
            var saveSw = Stopwatch.StartNew();
            var newAdjId = Uow.InventoryAdjs.Save(inventoryAdj);
            saveSw.Stop();
            totalSw.Stop();

            _logger.LogInformation(
                "InventoryAdj Save timing: Mode={Mode}, AdjId={AdjId}, NewAdjId={NewAdjId}, AdjType={AdjType}, SaveDbMs={SaveDbMs}, ReadbackMs={ReadbackMs}, TotalMs={TotalMs}",
                inventoryAdj.AdjId > 0 ? "Edit" : "Create",
                inventoryAdj.AdjId,
                newAdjId,
                inventoryAdj.AdjType,
                saveSw.ElapsedMilliseconds,
                0,
                totalSw.ElapsedMilliseconds);

            return newAdjId;
        }

        public void Inject(int adjId)
        {
            Uow.InventoryAdjs.Inject(adjId);
        }

        public void Delete(int adjId)
        {
            //Uow.InventoryAdjs.Find(c => c.AdjId == adjId).ExecuteDelete();

            var inventoryAdj = GetById(adjId);

            if (inventoryAdj != null && !inventoryAdj.IsLocked)
            {
                Uow.InventoryAdjs.Find(c => c.AdjId == adjId).ExecuteDelete();

                string docType = EnumHelper.DocType.InventoryAdj.ToString();

                _deleteLogService.Add(docType, adjId);
            }
        }

        public void DeleteDetail(int adjDetailId)
        {
            Uow.InventoryAdjs.DeleteDetail(adjDetailId);
        }

        public void UpdateNotes(InventoryAdj inventoryAdj)
        {
            var existing = GetById(inventoryAdj.AdjId);

            if (existing != null)
            {
                existing.Notes = inventoryAdj.Notes;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.InventoryAdjs.Update(existing);
                Uow.Commit();
            }
        }

        public void UpdateDetailNotes(InventoryAdjList inventoryAdjList)
        {
            var existing = Uow.InventoryAdjDetails.GetById(inventoryAdjList.AdjDetailId);

            if (existing != null)
            {
                existing.Notes = inventoryAdjList.DetailNotes;

                Uow.InventoryAdjDetails.Update(existing);
                Uow.Commit();
            }
        }

        public InventoryClosingDetail QtyAdj(QtyAdjReq adjReq)
        {
            // Read the current average cost before posting.
            // The product-list qty-adj flow patches the visible inventory qty
            // immediately after save, and the just-created @INV journal row may
            // still be pre-recalc at that moment. Returning adjReq.NewQty avoids
            // flashing 0/on old state in the UI while recalculation catches up.
            var currentSnapshot = GetClosingQty(adjReq.ItemId);
            Uow.InventoryAdjs.QtyAdj(adjReq);

            return new InventoryClosingDetail
            {
                ItemId = adjReq.ItemId,
                ClosingQty = adjReq.NewQty,
                AverageCost = currentSnapshot?.AverageCost
            };
        }

        public InventoryClosingDetail GetClosingQty(int itemId)
        {
            return Uow.InventoryAdjs.GetClosingQty(itemId);
        }
    }
}
