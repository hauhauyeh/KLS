using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemTariffService : BaseService, IItemTariffService
    {
        public ItemTariffService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<ItemTariffList> GetPagedList(ItemTariffListReq tariffListReq)
        {
            var list = Uow.ItemTariffs.GetPagedList(tariffListReq);

            var totalRecords = Uow.ItemTariffs.Count(tariffListReq);

            return new PagingResponse<ItemTariffList>(totalRecords, tariffListReq.Pageno, tariffListReq.Pagesize)
            {
                RowData = list,
            };
        }

        public ItemTariff? GetById(int itemTariffId)
        {
            return Uow.ItemTariffs.GetById(itemTariffId);
        }

        public bool Exists(ItemTariff itemTariff)
        {
            var cc = (itemTariff.CountryCode ?? string.Empty).Trim().ToLower();

            return Uow.ItemTariffs.Exists(x =>
                x.ItemId == itemTariff.ItemId &&
                x.CountryCode.Trim().ToLower() == cc &&
                x.ItemTariffId != itemTariff.ItemTariffId
            );
        }

        public ItemTariff Create(ItemTariff itemTariff)
        {
            itemTariff.CountryCode = (itemTariff.CountryCode ?? string.Empty).Trim().ToUpper();

            Uow.ItemTariffs.Add(itemTariff);
            Uow.Commit();

            return itemTariff;
        }

        public ItemTariff? Update(ItemTariff itemTariff)
        {
            var existing = GetById(itemTariff.ItemTariffId);

            if (existing != null)
            {
                existing.ItemId = itemTariff.ItemId;
                existing.CountryCode = (itemTariff.CountryCode ?? string.Empty).Trim().ToUpper();
                existing.DutyRate = itemTariff.DutyRate;
                existing.TariffRate = itemTariff.TariffRate;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.ItemTariffs.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Delete(int itemTariffId)
        {
            Uow.ItemTariffs.RemoveById(itemTariffId);
            Uow.Commit();
        }

        public IEnumerable<Country>? GetCountriesList()
        {
            return Uow.Countries.GetAll().OrderBy(c => c.CountryName);
        }
    }
}
