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
    public class EmailSettingService : BaseService, IEmailSettingService
    {
        public EmailSettingService(IUnitOfWork uow) : base(uow)
        {

        }

        public EmailSetting GetSetting()
        {
            return Uow.EmailSettings.GetAll().FirstOrDefault();
        }
    }
}
