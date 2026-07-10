using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SystemSettingService : BaseService, ISystemSettingService
    {
        public SystemSettingService(IUnitOfWork uow) : base(uow)
        {
        }

        public T? GetByKey<T>(string settingKey)
        {
            var setting = Uow.SystemSettings
                .Find(c => c.SettingKey == settingKey)
                .AsNoTracking()
                .FirstOrDefault();

            if (setting == null || string.IsNullOrEmpty(setting.SettingValue))
                return default;

            try
            {
                return (T)Convert.ChangeType(setting.SettingValue, typeof(T));
            }
            catch
            {
                return default;
            }
        }

        // 4dp Section B Phase-2 (Slice 5): single source of the guard so every caller uses exactly == 4 ? 4 : 2.
        // Absent/0/2/invalid -> 2; only an explicit 4 enables 4-decimal unit-price rounding.
        public int GetPriceDecimals()
        {
            return GetByKey<int>(GlobalKey.PRICE_DISPLAY_DECIMALS) == 4 ? 4 : 2;
        }
    }
}
