using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmployeeList
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public bool IsClosed { get; set; }

        public string? FirstName { get; set; }

        public string? LastName { get; set; }

        public string? Department { get; set; }

        public string? RoleName { get; set; }

        public bool CanLogin { get; set; }

        public bool HasOutsideAccess { get; set; }
    }
}
