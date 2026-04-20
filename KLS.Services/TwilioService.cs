using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Twilio;
using Twilio.Rest.Api.V2010.Account;

namespace KLS.Services
{
    public class TwilioService : BaseService, ITwilioService
    {
        private readonly ISystemSettingService _systemSettingService;

        public TwilioService(IUnitOfWork uow, ISystemSettingService systemSettingService) : base(uow)
        {
            _systemSettingService = systemSettingService;
        }

        public bool SendMessage(string to, string messageBody)
        {
            string? accountSid = _systemSettingService.GetByKey<string>(GlobalKey.TWILIO_SID);
            string? authToken = _systemSettingService.GetByKey<string>(GlobalKey.TWILIO_TOKEN);
            string? from = _systemSettingService.GetByKey<string>(GlobalKey.TWILIO_FROM);

            if (!string.IsNullOrEmpty(accountSid) && !string.IsNullOrEmpty(to))
            {
                TwilioClient.Init(accountSid, authToken);

                var message = MessageResource.Create(
                    body: messageBody,
                    from: new Twilio.Types.PhoneNumber(from),
                    to: new Twilio.Types.PhoneNumber(to)
                );

                return message.ErrorCode == null;

                //return true;
            }

            return false;
        }
    }
}
