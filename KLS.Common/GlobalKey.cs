using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public class GlobalKey
    {
        public const string SYS_IPADDRESS = "SYS_IPADDRESS";

        public const string ITEM_DEFAULT_TYPE = "ITEM_DEFAULT_TYPE";
        public const string ITEM_DEFAULT_TAXABLE = "ITEM_DEFAULT_TAXABLE";
        public const string ITEM_DEFAULT_WHOLEPROFIT = "ITEM_DEFAULT_WHOLEPROFIT";
        public const string ITEM_DEFAULT_RETAILPROFIT = "ITEM_DEFAULT_RETAILPROFIT";
        public const string ITEM_DEFAULT_MINPROFIT = "ITEM_DEFAULT_MINPROFIT";

        // 4-decimal pricing (Section B Phase-2): unit-price decimal places for calc + display. Allowed 2 or 4; default 2.
        public const string PRICE_DISPLAY_DECIMALS = "PRICE_DISPLAY_DECIMALS";

        public const string PAYROLL_DEFAULT_PAYFREQ = "PAYROLL_DEFAULT_PAYFREQ";
        public const string PAYROLL_DEFAULT_BANK = "PAYROLL_DEFAULT_BANK";
        public const string PAYROLL_BEGINDAYOFWEEK = "PAYROLL_BEGINDAYOFWEEK";

        public const string PAYMENT_DEFAULT_BANK = "PAYMENT_DEFAULT_BANK";

        public const string GOOGLEMAPS_APIKEY = "GOOGLEMAPS_APIKEY";

        public const string TWILIO_SID = "TWILIO_SID";
        public const string TWILIO_TOKEN = "TWILIO_TOKEN";
        public const string TWILIO_FROM = "TWILIO_FROM";

        public const string IRONPDF_KEY = "IRONPDF_KEY";

        public const string SYSTEM_HAS_DISCOUNT = "SYSTEM_HAS_DISCOUNT";
        public const string SYSTEM_DEFAULT_TAXRATE = "SYSTEM_DEFAULT_TAXRATE";
        public const string DOCUMENT_FORMAT = "DOCUMENT_FORMAT";
        public const string INVOICE_PRINT_USE_POPUP = "INVOICE_PRINT_USE_POPUP";
        public const string SALES_DOC_NUMBER_DISPLAY_ENABLED = "SALES_DOC_NUMBER_DISPLAY_ENABLED";
        public const string SALES_ORDER_DOCUMENT_MENU_JSON = "SALES_ORDER_DOCUMENT_MENU_JSON";
        public const string SALES_TRANSIT_UPDATE_DOCUMENT_ACTION = "SALES_TRANSIT_UPDATE_DOCUMENT_ACTION";
        public const string CREDIT_MEMO_DEFAULT_STAGE = "CREDIT_MEMO_DEFAULT_STAGE";

        public const string INTERCOMPANY_ITEM_SYNC_ENABLED = "INTERCOMPANY_ITEM_SYNC_ENABLED";
        public const string INTERCOMPANY_SALES_TRANSFER_ENABLED = "INTERCOMPANY_SALES_TRANSFER_ENABLED";

        public const string LABEL_PRINTER_NAME = "LABEL_PRINTER_NAME";
        public const string DEFAULT_CCFEE_PERCENTAGE = "DEFAULT_CCFEE_PERCENTAGE";

        public const string WEB_ENFORCE_STOCK_LIMIT = "WEB_ENFORCE_STOCK_LIMIT";
        public const string WEB_PUBLIC_PRODUCT_LIST_ENABLE = "WEB_PUBLIC_PRODUCT_LIST_ENABLE";
        public const string WEB_PORTAL_MODE = "WEB_PORTAL_MODE";
        public const string WEB_ORDER_CHECKOUT_HOUR = "WEB_ORDER_CHECKOUT_HOUR";
        public const string WEB_CLIENT_EXPERIENCE_JSON = "WEB_CLIENT_EXPERIENCE_JSON";
        public const string WEB_CLIENT_EXPERIENCE_JSON_PREVIOUS = "WEB_CLIENT_EXPERIENCE_JSON_PREVIOUS";

        public const string AUTO_PRINTINVOICE = "AUTO_PRINTINVOICE";
        public const string SALES_LOAD_SEPARATE = "SALES_LOAD_SEPARATE";

        /// <summary>The date every opening balance journal is posted on.</summary>
        public const string SYSTEM_START_DATE = "SYSTEM_START_DATE";

    }
}
