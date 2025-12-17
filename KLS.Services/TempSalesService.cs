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
    public class TempSalesService : BaseService, ITempSalesService
    {
        public TempSalesService(IUnitOfWork uow) : base(uow)
        {
        }

        public TempSalesItem CreateTempSales()
        {
            throw new NotImplementedException();
        }

        public TempSalesItem UpdateTempSales()
        {
            throw new NotImplementedException();
        }

        public void DeleteTempSales(int tempId)
        {
            var temp = Uow.TempSales.GetById(tempId);

            if (temp != null)
            {
                if (temp.SalesDetailId.HasValue)
                {
                    temp.ChangeStatus = EnumHelper.ChangeStatus.D.ToString();
                    Uow.TempSales.Update(temp);
                }
                else
                {
                    Uow.TempSales.Remove(temp);
                }
                Uow.Commit();
            }
        }

        public void ClearTempSales(TempSalesReq tempReq)
        {
            Uow.TempSales.Find(c => c.EmpId == UserContext.EmpId && c.SalesId == tempReq.SalesId && c.PayeeId == tempReq.PayeeId).ExecuteDelete();
        }
    }
}
