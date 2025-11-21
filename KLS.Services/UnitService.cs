using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class UnitService : BaseService, IUnitService
    {
        public UnitService(IUnitOfWork uow) : base(uow)
        {
        }

        public IQueryable<Unit> GetAllUnits()
        {
            return Uow.Units.GetAll().OrderBy(u => u.UnitName);
        }

        public Unit GetById(int unitId)
        {
            return Uow.Units.GetById(unitId);
        }

        public bool ExistsCode(Unit unit)
        {
            return Uow.Units.Exists(u =>
                u.UnitCode.ToLower() == unit.UnitCode.ToLower()
                && u.UnitId != unit.UnitId);
        }

        public bool ExistsName(Unit unit)
        {
            return Uow.Units.Exists(u =>
                u.UnitName.ToLower() == unit.UnitName.ToLower()
                && u.UnitId != unit.UnitId);
        }

        public Unit CreateUnit(Unit unit)
        {
            Uow.Units.Add(unit);
            Uow.Commit();

            return unit;
        }

        public Unit? UpdateUnit(Unit unit)
        {
            var existing = GetById(unit.UnitId);

            if (existing != null)
            {
                existing.UnitCode = unit.UnitCode;
                existing.UnitName = unit.UnitName;

                Uow.Units.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void DeleteUnit(int unitId)
        {
            Uow.Units.RemoveById(unitId);
            Uow.Commit();
        }
    }
}
