using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ICountryService
    {
        IEnumerable<CountryDto> GetList(bool activeOnly = true);
    }
}
