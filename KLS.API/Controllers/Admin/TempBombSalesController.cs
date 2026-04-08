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
    [Display(Name = "Bomb Order Management", GroupName = "Customer")]
    public class TempBombSalesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempBombSalesService _tempBombSalesService;

        #endregion

        #region --- Constructor(s) ---

        public TempBombSalesController(ITempBombSalesService tempBombSalesService)
        {
            _tempBombSalesService = tempBombSalesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Bomb")]
        [PermissionKey("Customer.BombSale.List")]
        public IActionResult List(bool checkAgain)
        {
            return Ok(_tempBombSalesService.GetList(checkAgain));
        }


        [HttpPut]
        [DisplayName("Update Detail")]
        [PermissionKey("Customer.BombSale.Update")]
        public IActionResult Update([FromBody] BombSalesItem bombItem)
        {
            return Ok(_tempBombSalesService.Update(bombItem));
        }


        [HttpPut("UpdateUnit")]
        public IActionResult UpdateUnit([FromBody] BombSalesItem bombItem)
        {
            return Ok(_tempBombSalesService.UpdateUnit(bombItem));
        }


        [HttpPut("UpdateCode")]
        public IActionResult UpdateCode([FromBody] BombSalesItem bombItem)
        {
            return Ok(_tempBombSalesService.UpdateCode(bombItem));
        }


        [HttpPost("Inject")]
        public IActionResult Inject([FromBody] BombSalesReq bombSalesReq)
        {
            _tempBombSalesService.Inject(bombSalesReq);
            return Ok();
        }


        [HttpPost]
        [DisplayName("Save Bomb")]
        [PermissionKey("Customer.BombSale.Save")]
        public IActionResult SaveBomb()
        {
            _tempBombSalesService.SaveBomb();
            return Ok();
        }

        #endregion
    }
}
