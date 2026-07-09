using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISystemSettingService
    {
        T? GetByKey<T>(string settingKey);

        // 4dp Section B Phase-2 (Slice 5): the active unit-price decimal places, guarded to 2 or 4.
        int GetPriceDecimals();
    }
}
