using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempSalesService
    {
        TempSalesItem Create();

        TempSalesItem Update();

        void Delete(int tempId);

        void Clear(TempSalesReq tempReq);
    }
}
