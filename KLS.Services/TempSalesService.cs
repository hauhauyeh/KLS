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

        public TempSalesItem Create()
        {
            throw new NotImplementedException();
        }

        public TempSalesItem Update()
        {
            throw new NotImplementedException();
        }

        public void Delete(int tempId)
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

        public void Clear(TempSalesReq tempReq)
        {
            Uow.TempSales.Find(c => c.EmpId == UserContext.EmpId && c.SalesId == tempReq.SalesId && c.PayeeId == tempReq.PayeeId).ExecuteDelete();
        }
    }
}
