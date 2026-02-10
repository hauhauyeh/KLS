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
    public class TempTransferFundService : BaseService, ITempTransferFundService
    {
        public TempTransferFundService(IUnitOfWork uow) : base(uow)
        {

        }

        public void Update(TempTransferFund tempTransfer)
        {
            var temp = Uow.TempTransferFunds.GetById(tempTransfer.TempTFId);

            if (temp != null)
            {
                temp.Notes = tempTransfer.Notes;
                temp.IsApplied = tempTransfer.IsApplied;

                Uow.TempTransferFunds.Update(temp);
                Uow.Commit();
            }
        }

        public void AppliedAll(TFApplyReq applyReq)
        {
            Uow.TempTransferFunds.Find(c => c.EmpId == UserContext.EmpId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.IsApplied, x => applyReq.IsAppliedAll));
        }
    }
}
