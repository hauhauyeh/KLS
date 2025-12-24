using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IHolidayService
    {
        IEnumerable<Holiday> GetList();

        Holiday? GetById(int holidayId);

        bool NameExists(Holiday holiday);

        Holiday Create(Holiday holiday);

        Holiday? Update(Holiday holiday);

        void Delete(int holidayId);
    }
}
