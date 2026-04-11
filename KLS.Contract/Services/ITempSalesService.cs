using KLS.Models;
using KLS.Models.Cart;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempSalesService
    {
        IEnumerable<TempSalesItem>? GetList(TempSalesReq tempReq);

        TempSalesItem Create(TempSalesItem tempItem);

        TempSalesItem Update(TempSalesItem tempItem);

        TempSalesItem? UpdateParentSalesNumber(TempSalesParentUpdateReq req);

        TempSalesItem UpdateUnit(TempSalesItem tempItem);

        void Delete(int tempId);

        void Clear(TempSalesReq tempReq);

        IEnumerable<PayeeSearch>? DraftCustomers();

        IEnumerable<ItemSearch> Search(TempSalesReq tempReq);

        TempSalesItem? AddLine(AddLineRequest req);


        //----Web

        IEnumerable<WebCartItem>? GetCartItems();

        WebCartItem? AddCartItem(AddToCartReq req);

        WebCartItem? UpdateCartQty(WebCartItem cartItem);

        WebCartItem? UpdateCartUnit(WebCartItem cartItem);

        void ClearCart();
    }
}
