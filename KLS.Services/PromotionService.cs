using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PromotionService : BaseService, IPromotionService
    {
        public PromotionService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
