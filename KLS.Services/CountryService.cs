using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class CountryService : BaseService, ICountryService
    {
        public CountryService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<CountryDto> GetList(bool activeOnly = true)
        {
            var query = Uow.Countries.GetAll();

            if (activeOnly)
            {
                query = query.Where(c => c.IsActive);
            }

            return query
                .OrderBy(c => c.SortOrder ?? int.MaxValue)
                .ThenBy(c => c.CountryName)
                .Select(c => new CountryDto
                {
                    CountryId = c.CountryId,
                    CountryName = c.CountryName,
                    ISOAlpha2 = c.ISOAlpha2,
                    ISOAlpha3 = c.ISOAlpha3,
                    NumericCode = c.NumericCode,
                    CallingCode = c.CallingCode,
                    Continent = c.Continent,
                    IsActive = c.IsActive,
                    SortOrder = c.SortOrder
                });
        }
    }
}
