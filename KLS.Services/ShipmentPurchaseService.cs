using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ShipmentPurchaseService : BaseService, IShipmentPurchaseService
    {
        public ShipmentPurchaseService(IUnitOfWork uow) : base(uow)
        {
        }
    }
}
