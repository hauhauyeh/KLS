using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PrintLabelReq
    {
        public PrintLabelReq()
        {
            PrintCopy = 1;
        }

        public string? Content { get; set; }

        public short PrintCopy { get; set; }

        public bool IsCenter { get; set; }

        public string? IPAddress { get; set; }
    }
}
