using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IUnitService
    {
        IQueryable<Unit> GetAllUnits();

        Unit GetById(int unitId);

        bool ExistsCode(Unit unit);

        bool ExistsName(Unit unit);

        Unit CreateUnit(Unit unit);

        Unit? UpdateUnit(Unit unit);

        void DeleteUnit(int unitId);
    }
}
