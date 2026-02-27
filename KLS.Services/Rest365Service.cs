using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Hosting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class Rest365Service : BaseService, IRest365Service
    {
        public Rest365Service(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
