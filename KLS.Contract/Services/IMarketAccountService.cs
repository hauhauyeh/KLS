using KLS.Contract.Dtos;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IMarketAccountService
    {
        IEnumerable<MarketAccountDto> GetAll();

        IEnumerable<MarketAccountDto> GetActive();

        MarketAccountDto? GetById(int id);

        bool NameExists(string accountName, int excludeId = 0);

        MarketAccountDto Save(MarketAccountSaveReq req);

        void Delete(int id);

        void ToggleActive(int id);

        string? DecryptSettings(int id);
    }
}
