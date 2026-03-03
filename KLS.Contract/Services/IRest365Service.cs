using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IRest365Service
    {
        IEnumerable<Rest365> GetList();

        Rest365? GetById(int rest365Id);

        bool NameExists(Rest365 rest365);

        Rest365 Create(Rest365 rest365);

        Rest365? Update(Rest365 rest365);

        void Inactive(int rest365Id);
    }
}
