using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Dtos
{
    public record TermDto(
       int TermId,
       string TermName,
       string? TermType,
       int? DueDays,
       decimal? Discount,
       bool Inactive,
       string? Notes
   );
}
