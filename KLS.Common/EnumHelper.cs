using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public static class EnumHelper
    {
        public enum PayeeType
        {
            E = 1,
            V = 2,
            C = 3,
            L = 4,
            O = 5
        }

        public enum PayrollServiceCode
        {
            PAYROLLCHECK = 1,
            PAYROLLTAXPMT = 2,
            LOANPMTDEDUCTION = 3,
            GARNISHMENT = 4
        }

        public enum EnumPaymentMethod
        {
            ACH = 1,
            CASH = 2,
            CHECK = 3,
            CREDIT_CARD = 4,
            E_CHECK = 5,
            HANDWRITE_CHECK = 6
        }

        public enum AccountClass
        {
            A, // Asset
            C, // Capital
            I, // Income
            L, // Liability
            Q, // Equity
            X  // Expense

            //Asset = 1,
            //Liability = 2,
            //Equity = 3,
            //Income = 4,
            //Expense = 5
        }

        public enum ChangeStatus
        {
            I = 1,  //Insert
            U = 2,  //Update
            D = 3   //Delete
        }

        public enum LineType
        {
            I = 1,  //Item
            A = 2,  //Account
        }

        public enum ItemDefaultUnit
        {
            Whole = 1,
            Retail = 2
            //Half = 3,
            //X = 4
        }

        public enum ReturnTypes
        {
            [Display(Name = "NSF")]
            NSF = 1,
            [Display(Name = "STOP")]
            STOP = 2,
            [Display(Name = "DISPUTE")]
            DISPUTE = 3,
            [Display(Name = "BANK ERROR")]
            BANKERROR = 4
        }

        public enum DocType
        {
            GeneralJournal = 100,
            Paycheck = 200,
            PayrollTaxPayment = 210,
            Purchase = 300,
            Check = 310,
            CreditCardCharge = 320,
            BillPayment = 400,
            BillCCard = 410,
            Sales = 500,
            SalesTaxPayment = 510,
            CustomerPayment = 520,
            CustomerRefund = 530,
            OtherTaxPayment = 550,
            InventoryAdj = 600,
            LoanRepayment = 710,
            Deposit = 800,
            Transfer = 810,
            LoantoEmployee = 920,
            OtherIncomingPayment = 940,
            PayrollService = 930
        }

        public enum Portal
        {
            Admin = 1,
            Web = 2,
            Sales = 3,
            Timesheet = 4
        }

        public enum DocumentTemplate
        {
            PO = 1
        }

        public enum PurchaseDocType
        {
            PO = 1,
            Bill = 2
        }

        public enum TempPurchaseUpdateKind
        {
            General = 0,
            Price = 1,
            Quantity = 2,
            Flag = 3,
            Unit = 4,
            Metadata = 5,
            QuantityUnit = 6
        }

        public enum EmailLogEvent
        {
            Invoice = 1,
            RevInvoice = 2,
            Statement = 3,
            PriceSheet = 4,
            ACHReceipt = 5,
            Report = 6
        }

        public enum ShipmentStatus
        {
            Draft = 1,
            Assigned = 2,
            Allocated = 3,
            Closed = 4
        }

        public enum PromotionType
        {
            DISCOUNT_FLAT,
            DISCOUNT_PERCENTAGE,
            DISCOUNT_ITEM_FLAT,
            DISCOUNT_ITEM_PERCENTAGE,
            BOGO_ITEM_CATEGORY,
            BOGO_CART
        }

        public enum ConditionType { CART, ITEM, CATEGORY }
        public enum RewardType    { SAME_AS_CONDITION, ITEM, CATEGORY }
        public enum DiscountType  { FREE, FLAT, PERCENTAGE }
    }
}
