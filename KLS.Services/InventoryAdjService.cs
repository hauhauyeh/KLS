using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
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

        public InventoryAdjService(IUnitOfWork uow, IDeleteLogService deleteLogService) : base(uow)
        {
            _deleteLogService = deleteLogService;
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

        public IEnumerable<InventoryAdjList> Save(InventoryAdj inventoryAdj)
        {
            var newAdjId = Uow.InventoryAdjs.Save(inventoryAdj);

            return GetListById(newAdjId);
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
    }
}
