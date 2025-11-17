using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ITwilioService
    {
        bool SendMessage(string to, string messageBody);
    }
}
