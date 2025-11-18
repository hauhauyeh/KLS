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
    public class InventoryAdjService : BaseService, IInventoryAdjService
    {
        public InventoryAdjService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<InventoryAdjList> GetAllInventoryAdj(InventoryAdjListReq inventoryAdjListReq)
        {
            var inventoryAdjlist = Uow.InventoryAdjs.GetAllInventoryAdj(inventoryAdjListReq);

            var totalRecords = Uow.InventoryAdjs.CountAllInventoryAdj(inventoryAdjListReq);

            return new PagingResponse<InventoryAdjList>(totalRecords, inventoryAdjListReq.Pageno, inventoryAdjListReq.Pagesize)
            {
                RowData = inventoryAdjlist,
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

            return Uow.InventoryAdjs.GetAllInventoryAdj(listReq);
        }

        public IEnumerable<InventoryAdjList> SaveInventoryAdj(InventoryAdj inventoryAdj)
        {
            var newAdjId = Uow.InventoryAdjs.SaveInventoryAdj(inventoryAdj);

            return GetListById(newAdjId);
        }

        public void InjectInventoryAdj(int adjId)
        {
            Uow.InventoryAdjs.InjectInventoryAdj(adjId);
        }

        public void DeleteInventoryAdj(int adjId)
        {
            Uow.InventoryAdjs.Find(c => c.AdjId == adjId).ExecuteDelete();
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

        public void UpdateDetailNotes(InventoryAdj inventoryAdj)
        {
            //var existing = Uow.InventoryAdjDetails.GetById(inventoryAdj.AdjDetailId);

            //if (existing != null)
            //{
            //    existing.Notes = inventoryAdj.Notes;
            //    existing.UpdatedAt = DateTime.UtcNow;

            //    Uow.InventoryAdjs.Update(existing);
            //    Uow.Commit();
            //}
        }
    }
}
