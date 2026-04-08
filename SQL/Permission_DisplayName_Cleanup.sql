-- ============================================================
-- Permission DisplayName Cleanup
-- Rules: View (not List), Edit (not Update), Create or Edit (not Create/Update),
--   expand abbreviations, Item->Product, title case, consistent pluralization
-- Only changes DisplayName column — nothing else.
-- ============================================================

-- ===================== ACCOUNTING =====================

-- Resources (keep as-is, already clean)
-- 1050 Account Management — OK but simplify to "Account" per plan
UPDATE Permission SET DisplayName = 'Account' WHERE PermissionId = 1050;

-- Pages: List -> View
UPDATE Permission SET DisplayName = 'View Accounts' WHERE PermissionId = 1051;
UPDATE Permission SET DisplayName = 'Edit Account' WHERE PermissionId = 1053;

UPDATE Permission SET DisplayName = 'View Bank Reconciliations' WHERE PermissionId = 1101;
UPDATE Permission SET DisplayName = 'Edit Reconciliation' WHERE PermissionId = 1103;

UPDATE Permission SET DisplayName = 'View Check Register' WHERE PermissionId = 1151;
UPDATE Permission SET DisplayName = 'Edit Check Register' WHERE PermissionId = 1152;

UPDATE Permission SET DisplayName = 'View General Journals' WHERE PermissionId = 1201;
UPDATE Permission SET DisplayName = 'Create or Edit General Journal' WHERE PermissionId = 1202;

UPDATE Permission SET DisplayName = 'View Incoming Payments' WHERE PermissionId = 1251;
UPDATE Permission SET DisplayName = 'Create or Edit Incoming Payment' WHERE PermissionId = 1252;

UPDATE Permission SET DisplayName = 'View Transactions' WHERE PermissionId = 1301;

UPDATE Permission SET DisplayName = 'View Transfer Funds' WHERE PermissionId = 1351;
UPDATE Permission SET DisplayName = 'Create or Edit Transfer Fund' WHERE PermissionId = 1352;

-- ===================== ADMIN =====================

UPDATE Permission SET DisplayName = 'View Document Templates' WHERE PermissionId = 2051;
UPDATE Permission SET DisplayName = 'Edit Document Template' WHERE PermissionId = 2053;

UPDATE Permission SET DisplayName = 'View Email Logs' WHERE PermissionId = 2101;

-- Export pages already OK

UPDATE Permission SET DisplayName = 'View Holidays' WHERE PermissionId = 2201;
UPDATE Permission SET DisplayName = 'Edit Holiday' WHERE PermissionId = 2203;

-- ItemTag -> Product Tag
UPDATE Permission SET DisplayName = 'Product Tag' WHERE PermissionId = 2250;
UPDATE Permission SET DisplayName = 'View Product Tags' WHERE PermissionId = 2251;
UPDATE Permission SET DisplayName = 'Create Product Tag' WHERE PermissionId = 2252;
UPDATE Permission SET DisplayName = 'Edit Product Tag' WHERE PermissionId = 2253;
UPDATE Permission SET DisplayName = 'Delete Product Tag' WHERE PermissionId = 2254;

-- ItemTariff -> Product Tariff
UPDATE Permission SET DisplayName = 'Product Tariff' WHERE PermissionId = 2300;
UPDATE Permission SET DisplayName = 'View Product Tariffs' WHERE PermissionId = 2301;
UPDATE Permission SET DisplayName = 'Create Product Tariff' WHERE PermissionId = 2302;
UPDATE Permission SET DisplayName = 'Edit Product Tariff' WHERE PermissionId = 2303;
UPDATE Permission SET DisplayName = 'Delete Product Tariff' WHERE PermissionId = 2304;

UPDATE Permission SET DisplayName = 'View Promotions' WHERE PermissionId = 2351;
UPDATE Permission SET DisplayName = 'Edit Promotion' WHERE PermissionId = 2353;

UPDATE Permission SET DisplayName = 'View Recalculation Logs' WHERE PermissionId = 2401;

UPDATE Permission SET DisplayName = 'View Rest365' WHERE PermissionId = 2451;
UPDATE Permission SET DisplayName = 'Edit Rest365' WHERE PermissionId = 2453;
UPDATE Permission SET DisplayName = 'Mark as Inactive' WHERE PermissionId = 2454;

-- Role
UPDATE Permission SET DisplayName = 'Role' WHERE PermissionId = 2500;
UPDATE Permission SET DisplayName = 'View Roles' WHERE PermissionId = 2501;
UPDATE Permission SET DisplayName = 'Edit Role' WHERE PermissionId = 2503;
UPDATE Permission SET DisplayName = 'View Permissions' WHERE PermissionId = 2505;
UPDATE Permission SET DisplayName = 'Save Permissions' WHERE PermissionId = 2506;

UPDATE Permission SET DisplayName = 'View Scheduler Configs' WHERE PermissionId = 2551;
UPDATE Permission SET DisplayName = 'Edit Scheduler Config' WHERE PermissionId = 2552;

UPDATE Permission SET DisplayName = 'View Terms' WHERE PermissionId = 2601;
UPDATE Permission SET DisplayName = 'Edit Term' WHERE PermissionId = 2603;

UPDATE Permission SET DisplayName = 'View Trucks' WHERE PermissionId = 2651;
UPDATE Permission SET DisplayName = 'Edit Truck' WHERE PermissionId = 2653;

-- ===================== CUSTOMER =====================

UPDATE Permission SET DisplayName = 'Accounts Receivable' WHERE PermissionId = 3050;
UPDATE Permission SET DisplayName = 'View Accounts Receivable' WHERE PermissionId = 3051;

UPDATE Permission SET DisplayName = 'View Customer Payments' WHERE PermissionId = 3101;
UPDATE Permission SET DisplayName = 'Delete Customer Payment' WHERE PermissionId = 3102;
UPDATE Permission SET DisplayName = 'Create or Edit Customer Payment' WHERE PermissionId = 3103;

UPDATE Permission SET DisplayName = 'View Customers' WHERE PermissionId = 3151;
UPDATE Permission SET DisplayName = 'Edit Customer' WHERE PermissionId = 3153;
UPDATE Permission SET DisplayName = 'Activate or Deactivate Customer' WHERE PermissionId = 3155;
UPDATE Permission SET DisplayName = 'Email Price Sheet' WHERE PermissionId = 3156;

UPDATE Permission SET DisplayName = 'View Deposits' WHERE PermissionId = 3201;
UPDATE Permission SET DisplayName = 'Create or Edit Deposit' WHERE PermissionId = 3202;

UPDATE Permission SET DisplayName = 'Create Payment Method' WHERE PermissionId = 3251;
UPDATE Permission SET DisplayName = 'Delete Payment Method' WHERE PermissionId = 3252;

UPDATE Permission SET DisplayName = 'View Sales Orders' WHERE PermissionId = 3301;
UPDATE Permission SET DisplayName = 'Edit Route' WHERE PermissionId = 3302;
UPDATE Permission SET DisplayName = 'Edit Stage' WHERE PermissionId = 3303;
UPDATE Permission SET DisplayName = 'Edit Instruction' WHERE PermissionId = 3304;
UPDATE Permission SET DisplayName = 'Edit Purchase Order Number' WHERE PermissionId = 3305;
UPDATE Permission SET DisplayName = 'Edit Load Separate' WHERE PermissionId = 3306;
UPDATE Permission SET DisplayName = 'Edit Carrier' WHERE PermissionId = 3307;
UPDATE Permission SET DisplayName = 'Delete Sales Order' WHERE PermissionId = 3308;
UPDATE Permission SET DisplayName = 'View PDF Document' WHERE PermissionId = 3309;
UPDATE Permission SET DisplayName = 'Email PDF Document' WHERE PermissionId = 3310;
UPDATE Permission SET DisplayName = 'Create Sales Order' WHERE PermissionId = 3311;
UPDATE Permission SET DisplayName = 'Edit Sales Order' WHERE PermissionId = 3312;
UPDATE Permission SET DisplayName = 'Merge Sales Order' WHERE PermissionId = 3314;
UPDATE Permission SET DisplayName = 'Merge PDF Document' WHERE PermissionId = 3315;
UPDATE Permission SET DisplayName = 'View Payment' WHERE PermissionId = 3316;

UPDATE Permission SET DisplayName = 'View Bomb Sales' WHERE PermissionId = 3351;
UPDATE Permission SET DisplayName = 'Edit Bomb Sale Detail' WHERE PermissionId = 3352;
UPDATE Permission SET DisplayName = 'Save Bomb Sale' WHERE PermissionId = 3353;

-- ===================== EMPLOYEE =====================

UPDATE Permission SET DisplayName = 'View Employee Advances' WHERE PermissionId = 4051;
UPDATE Permission SET DisplayName = 'Create or Edit Advance Payment' WHERE PermissionId = 4052;

UPDATE Permission SET DisplayName = 'View Employees' WHERE PermissionId = 4101;
UPDATE Permission SET DisplayName = 'Edit Employee' WHERE PermissionId = 4103;

UPDATE Permission SET DisplayName = 'View Payroll Services' WHERE PermissionId = 4151;
UPDATE Permission SET DisplayName = 'Create or Edit Payroll Service' WHERE PermissionId = 4152;

UPDATE Permission SET DisplayName = 'View Payrolls' WHERE PermissionId = 4201;
UPDATE Permission SET DisplayName = 'Create or Edit Payroll' WHERE PermissionId = 4202;

UPDATE Permission SET DisplayName = 'View Timesheets' WHERE PermissionId = 4251;
UPDATE Permission SET DisplayName = 'Create or Edit Timesheet' WHERE PermissionId = 4252;

-- ===================== PRODUCT =====================

UPDATE Permission SET DisplayName = 'View Inventory Adjustments' WHERE PermissionId = 5051;
UPDATE Permission SET DisplayName = 'Create or Edit Adjustment' WHERE PermissionId = 5052;
UPDATE Permission SET DisplayName = 'Delete Adjustment Detail' WHERE PermissionId = 5054;
UPDATE Permission SET DisplayName = 'Quantity Adjustment' WHERE PermissionId = 5055;

-- ItemCategory -> Product Category
UPDATE Permission SET DisplayName = 'Product Category' WHERE PermissionId = 5100;
UPDATE Permission SET DisplayName = 'View Product Categories' WHERE PermissionId = 5101;
UPDATE Permission SET DisplayName = 'Create Product Category' WHERE PermissionId = 5102;
UPDATE Permission SET DisplayName = 'Edit Product Category' WHERE PermissionId = 5103;
UPDATE Permission SET DisplayName = 'Delete Product Category' WHERE PermissionId = 5104;
UPDATE Permission SET DisplayName = 'Reorder Product Category' WHERE PermissionId = 5105;

-- ItemHistory -> Product History
UPDATE Permission SET DisplayName = 'Product History' WHERE PermissionId = 5150;
UPDATE Permission SET DisplayName = 'View Sales History' WHERE PermissionId = 5151;
UPDATE Permission SET DisplayName = 'View Purchase History' WHERE PermissionId = 5152;
UPDATE Permission SET DisplayName = 'View Inventory History' WHERE PermissionId = 5153;
UPDATE Permission SET DisplayName = 'View Sales and Cost History' WHERE PermissionId = 5154;

-- ItemImage -> Product Image
UPDATE Permission SET DisplayName = 'Product Image' WHERE PermissionId = 5200;
UPDATE Permission SET DisplayName = 'View Product Images' WHERE PermissionId = 5201;
UPDATE Permission SET DisplayName = 'Upload Product Image' WHERE PermissionId = 5202;
UPDATE Permission SET DisplayName = 'Delete Product Image' WHERE PermissionId = 5203;

-- ItemStorage -> Product Storage
UPDATE Permission SET DisplayName = 'Product Storage' WHERE PermissionId = 5250;
UPDATE Permission SET DisplayName = 'View Product Storages' WHERE PermissionId = 5251;
UPDATE Permission SET DisplayName = 'Create Product Storage' WHERE PermissionId = 5252;
UPDATE Permission SET DisplayName = 'Edit Product Storage' WHERE PermissionId = 5253;
UPDATE Permission SET DisplayName = 'Delete Product Storage' WHERE PermissionId = 5254;

-- Item -> Product
UPDATE Permission SET DisplayName = 'Product' WHERE PermissionId = 5300;
UPDATE Permission SET DisplayName = 'View Products' WHERE PermissionId = 5301;
UPDATE Permission SET DisplayName = 'Create or Edit Product' WHERE PermissionId = 5303;
UPDATE Permission SET DisplayName = 'Edit Base Price (P1)' WHERE PermissionId = 5304;
UPDATE Permission SET DisplayName = 'Edit Product Unit' WHERE PermissionId = 5306;
UPDATE Permission SET DisplayName = 'Create Product Unit' WHERE PermissionId = 5307;
UPDATE Permission SET DisplayName = 'Delete Product Unit' WHERE PermissionId = 5308;

-- ===================== REPORT =====================

-- PL reports — already clean, keep as-is
UPDATE Permission SET DisplayName = 'Profit and Loss' WHERE PermissionId = 6052;
UPDATE Permission SET DisplayName = 'Ledger by Account' WHERE PermissionId = 6053;

-- Sales reports
UPDATE Permission SET DisplayName = 'Sales by Responsible' WHERE PermissionId = 6103;

-- Customer reports
UPDATE Permission SET DisplayName = 'Customer Statement' WHERE PermissionId = 6153;
UPDATE Permission SET DisplayName = 'Price Sheet' WHERE PermissionId = 6155;
UPDATE Permission SET DisplayName = 'Product Volume History' WHERE PermissionId = 6157;
UPDATE Permission SET DisplayName = 'Customer Sales by Product' WHERE PermissionId = 6158;

-- AP reports — expand abbreviations
UPDATE Permission SET DisplayName = 'Accounts Payable Check' WHERE PermissionId = 6251;
UPDATE Permission SET DisplayName = 'Checks To Be Printed' WHERE PermissionId = 6252;
UPDATE Permission SET DisplayName = 'Accounts Payable From Invoice' WHERE PermissionId = 6253;

-- AR reports
UPDATE Permission SET DisplayName = 'Accounts Receivable From Invoice' WHERE PermissionId = 6301;
UPDATE Permission SET DisplayName = 'Accounts Receivable by Month' WHERE PermissionId = 6302;

-- ===================== VENDOR =====================

-- Liability
UPDATE Permission SET DisplayName = 'View Loans' WHERE PermissionId = 7051;
UPDATE Permission SET DisplayName = 'View Tax Liabilities' WHERE PermissionId = 7052;
UPDATE Permission SET DisplayName = 'View Credit Cards' WHERE PermissionId = 7053;
UPDATE Permission SET DisplayName = 'Edit Liability' WHERE PermissionId = 7055;
UPDATE Permission SET DisplayName = 'View Transactions' WHERE PermissionId = 7058;
UPDATE Permission SET DisplayName = 'Create or Edit Loan Payment' WHERE PermissionId = 7059;
UPDATE Permission SET DisplayName = 'Create or Edit Credit Card Payment' WHERE PermissionId = 7060;

-- PurchaseOrder — expand PO
UPDATE Permission SET DisplayName = 'View Purchase Orders' WHERE PermissionId = 7101;
UPDATE Permission SET DisplayName = 'Create or Edit Purchase Order' WHERE PermissionId = 7102;
UPDATE Permission SET DisplayName = 'Delete Purchase Order' WHERE PermissionId = 7103;
UPDATE Permission SET DisplayName = 'Receive Product' WHERE PermissionId = 7104;
UPDATE Permission SET DisplayName = 'Print Purchase Order' WHERE PermissionId = 7105;
UPDATE Permission SET DisplayName = 'Convert to Bill' WHERE PermissionId = 7106;
UPDATE Permission SET DisplayName = 'Create or Edit Advance Payment' WHERE PermissionId = 7107;
UPDATE Permission SET DisplayName = 'View Advance Payments' WHERE PermissionId = 7108;

-- Purchase / Bill
UPDATE Permission SET DisplayName = 'Purchase Bill' WHERE PermissionId = 7150;
UPDATE Permission SET DisplayName = 'View Purchase Bills' WHERE PermissionId = 7151;
UPDATE Permission SET DisplayName = 'Edit Document Number' WHERE PermissionId = 7152;
UPDATE Permission SET DisplayName = 'Edit Invoice Date' WHERE PermissionId = 7153;
UPDATE Permission SET DisplayName = 'Edit Commission' WHERE PermissionId = 7154;
UPDATE Permission SET DisplayName = 'Edit Pallet' WHERE PermissionId = 7155;
UPDATE Permission SET DisplayName = 'Edit Container' WHERE PermissionId = 7156;
UPDATE Permission SET DisplayName = 'Create Purchase Bill' WHERE PermissionId = 7157;
UPDATE Permission SET DisplayName = 'Edit Purchase Bill' WHERE PermissionId = 7158;
UPDATE Permission SET DisplayName = 'Delete Purchase Bill' WHERE PermissionId = 7159;
UPDATE Permission SET DisplayName = 'Upload Bill PDF' WHERE PermissionId = 7160;
UPDATE Permission SET DisplayName = 'View Bill PDF' WHERE PermissionId = 7161;

-- Shipment
UPDATE Permission SET DisplayName = 'View Shipments' WHERE PermissionId = 7201;
UPDATE Permission SET DisplayName = 'Edit Shipment' WHERE PermissionId = 7203;
UPDATE Permission SET DisplayName = 'Unallocate Shipment' WHERE PermissionId = 7207;

-- VendorPayment
UPDATE Permission SET DisplayName = 'View Vendor Payments' WHERE PermissionId = 7251;
UPDATE Permission SET DisplayName = 'Create or Edit Vendor Payment' WHERE PermissionId = 7252;
UPDATE Permission SET DisplayName = 'Unvoid Check' WHERE PermissionId = 7255;
UPDATE Permission SET DisplayName = 'Create Return Payment' WHERE PermissionId = 7256;
UPDATE Permission SET DisplayName = 'Delete Return Payment' WHERE PermissionId = 7257;
UPDATE Permission SET DisplayName = 'Create or Edit Pay Now' WHERE PermissionId = 7258;
UPDATE Permission SET DisplayName = 'Import Pay Now' WHERE PermissionId = 7259;

-- Vendor
UPDATE Permission SET DisplayName = 'View Vendors' WHERE PermissionId = 7301;
UPDATE Permission SET DisplayName = 'Edit Vendor' WHERE PermissionId = 7303;
UPDATE Permission SET DisplayName = 'Activate or Deactivate Vendor' WHERE PermissionId = 7305;

PRINT 'DisplayName cleanup complete';

-- Verify a sample
SELECT PermissionId, PermissionKey, DisplayName, PermissionType
FROM Permission
WHERE [Module] = 'Customer' AND [Resource] = 'Sale'
ORDER BY PermissionId;
