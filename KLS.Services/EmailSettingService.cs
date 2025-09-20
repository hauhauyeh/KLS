using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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
