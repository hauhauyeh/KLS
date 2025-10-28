using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public static class EnumHelper
    {
        public enum PayeeType
        {
            E = 1,
            V = 2,
            C = 3,
            L = 4,
            O = 5
        }

        public enum PayrollServiceCode
        {
            PAYROLLCHECK = 1,
            PAYROLLTAXPMT = 2,
            LOANPMTDEDUCTION = 3,
            GARNISHMENT = 4
        }

        public enum PaymentMethod
        {
            ACH = 1,
            CASH = 2,
            CHECK = 3,
            CREDIT_CARD = 4,
            E_CHECK = 5,
            HANDWRITE_CHECK = 6
        }

        public enum AccountCategory
        {
            Asset = 1,
            Liability = 2,
            Capital = 3,
            Income = 4,
            Expense = 5
        }
    }
}
