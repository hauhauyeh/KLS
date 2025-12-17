using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IDeleteLogService
    {
        void Add(string docType, int docId);
    }
}
