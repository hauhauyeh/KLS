using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Item Tariff Management", GroupName = "Admin")]
    public class ItemTariffsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemTariffService _itemTariffService;

        #endregion

        #region --- Constructor(s) ---

        public ItemTariffsController(IItemTariffService itemTariffService)
        {
            _itemTariffService = itemTariffService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Item Tariffs")]
        public IActionResult List([FromQuery] ItemTariffListReq tariffListReq)
        {
            return Ok(_itemTariffService.GetPagedList(tariffListReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var itemTariff = _itemTariffService.GetById(id);

            if (itemTariff == null)
                return NotFound($"ItemTariff with ID {id} not found.");

            return Ok(itemTariff);
        }


        [HttpPost]
        [DisplayName("Create Item Tariff")]
        public IActionResult Create([FromBody] ItemTariff itemTariff)
        {
            if (_itemTariffService.Exists(itemTariff))
                return Conflict("Item tariff already exists for this Item and Country.");

            return Ok(_itemTariffService.Create(itemTariff));
        }


        [HttpPut]
        [DisplayName("Update Item Tariff")]
        public IActionResult Update([FromBody] ItemTariff itemTariff)
        {
            if (_itemTariffService.Exists(itemTariff))
                return Conflict("Item tariff already exists for this Item and Country.");

            return Ok(_itemTariffService.Update(itemTariff));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Item Tariff")]
        public IActionResult Delete(int id)
        {
            _itemTariffService.Delete(id);
            return Ok();
        }


        [HttpGet("Countries")]
        public IActionResult Countries()
        {
            return Ok(_itemTariffService.GetCountriesList());
        }

        #endregion
    }
}
