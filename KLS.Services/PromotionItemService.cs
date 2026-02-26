using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PromotionItemService : BaseService, IPromotionItemService
    {
        public PromotionItemService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
