using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class UserLogService : BaseService, IUserLogService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public UserLogService(IUnitOfWork uow, IHttpContextAccessor httpContextAccessor) : base(uow)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public void Create(int payeeId)
        {
            var log = new UserLog
            {
                PayeeId = payeeId,
                IPAddress = Utilities.GetIpAddress(_httpContextAccessor.HttpContext)
            };

            Uow.UserLogs.Add(log);
            Uow.Commit();
        }
    }
}
