using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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

        public PagingResponse<InventoryAdjList> GetinventoryAdj(InventoryAdjListReq inventoryAdjListReq)
        {
            var inventoryAdjlist = Uow.InventoryAdjs.GetInventoryAdjs(inventoryAdjListReq);

            var totalRecords = Uow.InventoryAdjs.CountAllInventoryAdjs(inventoryAdjListReq);

            return new PagingResponse<InventoryAdjList>(totalRecords, inventoryAdjListReq.Pageno, inventoryAdjListReq.Pagesize)
            {
                RowData = inventoryAdjlist,
            };
        }

        public InventoryAdj GetById(int adjId)
        {
            return Uow.InventoryAdjs.GetById(adjId);
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
