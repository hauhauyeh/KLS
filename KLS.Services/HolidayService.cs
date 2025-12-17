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
    public class HolidayService : BaseService, IHolidayService
    {
        public HolidayService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<Holiday> GetAllHolidays()
        {
            return Uow.Holidays.GetAll().OrderByDescending(h => h.HolidayDate).ToList();
        }

        public Holiday? GetById(int holidayId)
        {
            return Uow.Holidays.GetById(holidayId);
        }

        public bool NameExists(Holiday holiday)
        {
            return Uow.Holidays.Exists(c => c.HolidayName.ToLower() == holiday.HolidayName.ToLower()
            && c.HolidayDate.Value == holiday.HolidayDate.Value && c.HolidayId != holiday.HolidayId);
        }

        public Holiday CreateHoliday(Holiday holiday)
        {
            Uow.Holidays.Add(holiday);
            Uow.Commit();

            return holiday;
        }

        public Holiday? UpdateHoliday(Holiday holiday)
        {
            var existing = GetById(holiday.HolidayId);

            if (existing != null)
            {
                existing.HolidayName = holiday.HolidayName;
                existing.Description = holiday.Description;
                existing.HolidayDate = holiday.HolidayDate;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.Holidays.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void DeleteHoliday(int holidayId)
        {
            Uow.Holidays.RemoveById(holidayId);
            Uow.Commit();
        }
    }
}
