using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IEmailService
    {
        string SendEmail(EmailSetting emailSetting, string to, string subject, string htmlbody, string[]? attachfiles = null);

        string RenderEmailTemplate(string template, object model);
    }
}
