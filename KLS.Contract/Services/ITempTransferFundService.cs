using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempTransferFundService
    {
        void Update(TempTransferFund tempTransfer);

        void AppliedAll(TFApplyReq applyReq);
    }
}
