using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IHolidayService
    {
        IEnumerable<Holiday> GetAllHolidays();

        Holiday? GetById(int holidayId);

        bool NameExists(Holiday holiday);

        Holiday CreateHoliday(Holiday holiday);

        Holiday? UpdateHoliday(Holiday holiday);

        void DeleteHoliday(int holidayId);
    }
}
