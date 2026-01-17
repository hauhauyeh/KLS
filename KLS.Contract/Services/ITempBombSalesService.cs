using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempBombSalesService
    {
        IEnumerable<BombSalesItem> GetList(bool checkAgain);

        void Inject(BombSalesReq bombSalesReq);

        BombSalesItem Update(BombSalesItem bombItem);

        BombSalesItem UpdateUnit(BombSalesItem bombItem);

        BombSalesItem UpdateCode(BombSalesItem bombItem);

        void SaveBomb();
    }
}
