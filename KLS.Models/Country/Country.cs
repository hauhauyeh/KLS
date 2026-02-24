using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Reflection.Metadata.Ecma335;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Country
    {
        [Key]
        public string CountryCode { get; set; }

        public string CountryName { get; set; }
    }
}
