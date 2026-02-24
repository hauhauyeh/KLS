using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemTariffService
    {
        PagingResponse<ItemTariffList> GetPagedList(ItemTariffListReq tariffListReq);

        ItemTariff? GetById(int itemTariffId);

        bool Exists(ItemTariff itemTariff);

        ItemTariff Create(ItemTariff itemTariff);

        ItemTariff? Update(ItemTariff itemTariff);

        void Delete(int itemTariffId);

        IEnumerable<Country>? GetCountriesList();
    }
}
