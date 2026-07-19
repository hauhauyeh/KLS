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
            var country = FindActiveCountry(itemTariff.CountryCode);
            var alpha2 = country.ISOAlpha2.Trim().ToUpper();
            var alpha3 = country.ISOAlpha3.Trim().ToUpper();

            return Uow.ItemTariffs.Exists(x =>
                x.ItemId == itemTariff.ItemId &&
                (x.CountryCode.Trim().ToUpper() == alpha2 ||
                 x.CountryCode.Trim().ToUpper() == alpha3) &&
                x.ItemTariffId != itemTariff.ItemTariffId
            );
        }

        public ItemTariff Create(ItemTariff itemTariff)
        {
            itemTariff.CountryCode = NormalizeCountryCodeToAlpha2(itemTariff.CountryCode);

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
                existing.CountryCode = NormalizeCountryCodeToAlpha2(itemTariff.CountryCode);
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

        private string NormalizeCountryCodeToAlpha2(string? countryCode)
        {
            return FindActiveCountry(countryCode).ISOAlpha2.Trim().ToUpper();
        }

        private Country FindActiveCountry(string? countryCode)
        {
            var code = (countryCode ?? string.Empty).Trim().ToUpper();

            if (string.IsNullOrWhiteSpace(code))
            {
                throw new ArgumentException("Country is required.");
            }

            var country = Uow.Countries.GetAll().FirstOrDefault(c =>
                c.IsActive &&
                (c.ISOAlpha2.Trim().ToUpper() == code ||
                 c.ISOAlpha3.Trim().ToUpper() == code ||
                 c.CountryCode.Trim().ToUpper() == code));

            if (country == null)
            {
                throw new ArgumentException("Country must be a valid active country.");
            }

            return country;
        }
    }
}
