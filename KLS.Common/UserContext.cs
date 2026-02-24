using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public static class UserContext
    {
        private static readonly AsyncLocal<int> _empId = new();
        private static readonly AsyncLocal<bool> _isAdmin = new();
        private static readonly AsyncLocal<int> _systemUserId = new();
        private static readonly AsyncLocal<string> _userTimezone = new();

        public static int EmpId
        {
            get => _empId.Value;
            set => _empId.Value = value;
        }

        public static bool IsAdmin
        {
            get => _isAdmin.Value;
            set => _isAdmin.Value = value;
        }

        public static int SystemUserId
        {
            get => _systemUserId.Value;
            set => _systemUserId.Value = value;
        }

        public static string UserTimezone
        {
            get => _userTimezone.Value;
            set => _userTimezone.Value = value;
        }

        public static void Clear()
        {
            _empId.Value = 0;
            _systemUserId.Value = 0;
            _userTimezone.Value = null!;
        }
    }
}
