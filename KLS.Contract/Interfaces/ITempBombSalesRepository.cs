using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITempBombSalesRepository : IRepository<TempBombSales>
    {
        IQueryable<BombSalesItem> GetList(bool checkAgain, int? tempId);

        void Inject(BombSalesReq bombSalesReq);

        void SaveBomb();
    }
}
