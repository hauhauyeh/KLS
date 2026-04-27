using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class LoginResult
    {
        public bool Success { get; set; }
        public string? ErrorMessage { get; set; }

        public string? Token { get; set; }
        public string? RefreshToken { get; set; }

        public string? Username { get; set; }
        public bool IsAdmin { get; set; }
        public bool IsSalesRole { get; set; }
        public int EmpId { get; set; }
        public string? EmpSortName { get; set; }

        public ICollection<string>? Permissions { get; set; }
    }
}
