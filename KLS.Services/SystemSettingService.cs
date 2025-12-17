using KLS.Contract.Interfaces;
using KLS.Contract.Services;
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
    }
}
