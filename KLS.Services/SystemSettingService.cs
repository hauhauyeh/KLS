using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        public void SetByKey(string settingKey, string? settingValue, string dataType, string? description = null, bool commit = true)
        {
            if (string.IsNullOrWhiteSpace(settingKey))
                throw new ArgumentException("Setting key is required.");

            var normalizedKey = settingKey.Trim();
            var setting = Uow.SystemSettings
                .Find(c => c.SettingKey == normalizedKey)
                .FirstOrDefault();

            if (setting == null)
            {
                Uow.SystemSettings.Add(new SystemSetting
                {
                    SettingKey = normalizedKey,
                    SettingValue = settingValue,
                    DataType = dataType,
                    Description = description,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                setting.SettingValue = settingValue;
                setting.DataType = dataType;
                if (description != null)
                    setting.Description = description;
                setting.UpdatedAt = DateTime.UtcNow;
                Uow.SystemSettings.Update(setting);
            }

            if (commit)
                Uow.Commit();
        }

        // 4dp Section B Phase-2 (Slice 5): single source of the guard so every caller uses exactly == 4 ? 4 : 2.
        // Absent/0/2/invalid -> 2; only an explicit 4 enables 4-decimal unit-price rounding.
        public int GetPriceDecimals()
        {
            return GetByKey<int>(GlobalKey.PRICE_DISPLAY_DECIMALS) == 4 ? 4 : 2;
        }
    }
}
