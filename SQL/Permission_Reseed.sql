-- ============================================================
-- Permission Table Reseed — 50-gap between resources
-- Module ranges: 1xxx=Accounting, 2xxx=Admin, 3xxx=Customer,
--   4xxx=Employee, 5xxx=Product, 6xxx=Report, 7xxx=Vendor
-- Pattern: x000=menu, x050/x100/x150=resource, +1..+49=actions
-- SortOrder = PermissionId
-- ============================================================

DELETE FROM RolePermission;
DELETE FROM Permission;
DBCC CHECKIDENT ('Permission', RESEED, 0);

SET IDENTITY_INSERT Permission ON;

-- ============================================================
-- ACCOUNTING (1000-1999) — 7 resources
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey) VALUES
(1000, 'Accounting', 'Accounting', 'Accounting', '', '', 'menu', NULL, 1000, NULL),

-- Account (1050)
(1050, 'Accounting.Account', 'Account Management', 'Accounting', 'Account', '', 'resource', 'Accounting', 1050, NULL),
(1051, 'Accounting.Account.List', 'List Accounts', 'Accounting', 'Account', 'List', 'page', 'Accounting.Account', 1051, 'Accounts-List'),
(1052, 'Accounting.Account.Create', 'Create Account', 'Accounting', 'Account', 'Create', 'button', 'Accounting.Account', 1052, 'Accounts-Create'),
(1053, 'Accounting.Account.Update', 'Update Account', 'Accounting', 'Account', 'Update', 'button', 'Accounting.Account', 1053, 'Accounts-Update'),
(1054, 'Accounting.Account.Delete', 'Delete Account', 'Accounting', 'Account', 'Delete', 'button', 'Accounting.Account', 1054, 'Accounts-Delete'),

-- BankRecon (1100)
(1100, 'Accounting.BankRecon', 'Bank Reconciliation', 'Accounting', 'BankRecon', '', 'resource', 'Accounting', 1100, NULL),
(1101, 'Accounting.BankRecon.List', 'List Reconciliations', 'Accounting', 'BankRecon', 'List', 'page', 'Accounting.BankRecon', 1101, 'BankRecons-List'),
(1102, 'Accounting.BankRecon.Create', 'Create Reconciliation', 'Accounting', 'BankRecon', 'Create', 'button', 'Accounting.BankRecon', 1102, 'BankRecons-Create'),
(1103, 'Accounting.BankRecon.Update', 'Update Reconciliation', 'Accounting', 'BankRecon', 'Update', 'button', 'Accounting.BankRecon', 1103, 'BankRecons-Update'),
(1104, 'Accounting.BankRecon.Delete', 'Delete Reconciliation', 'Accounting', 'BankRecon', 'Delete', 'button', 'Accounting.BankRecon', 1104, 'BankRecons-Delete'),

-- CheckRegister (1150)
(1150, 'Accounting.CheckRegister', 'Check Register', 'Accounting', 'CheckRegister', '', 'resource', 'Accounting', 1150, NULL),
(1151, 'Accounting.CheckRegister.List', 'List Check Register', 'Accounting', 'CheckRegister', 'List', 'page', 'Accounting.CheckRegister', 1151, 'CheckRegister-List'),
(1152, 'Accounting.CheckRegister.Update', 'Update Check Register', 'Accounting', 'CheckRegister', 'Update', 'button', 'Accounting.CheckRegister', 1152, 'CheckRegister-Update'),

-- GeneralJournal (1200)
(1200, 'Accounting.GeneralJournal', 'General Journal', 'Accounting', 'GeneralJournal', '', 'resource', 'Accounting', 1200, NULL),
(1201, 'Accounting.GeneralJournal.List', 'List General Journals', 'Accounting', 'GeneralJournal', 'List', 'page', 'Accounting.GeneralJournal', 1201, 'GeneralJournals-List'),
(1202, 'Accounting.GeneralJournal.Save', 'Create/Update General Journal', 'Accounting', 'GeneralJournal', 'Save', 'button', 'Accounting.GeneralJournal', 1202, 'GeneralJournals-Save'),
(1203, 'Accounting.GeneralJournal.Delete', 'Delete General Journal', 'Accounting', 'GeneralJournal', 'Delete', 'button', 'Accounting.GeneralJournal', 1203, 'GeneralJournals-Delete'),

-- IncomingPayment (1250)
(1250, 'Accounting.IncomingPayment', 'Incoming Payment', 'Accounting', 'IncomingPayment', '', 'resource', 'Accounting', 1250, NULL),
(1251, 'Accounting.IncomingPayment.List', 'List Incoming Payments', 'Accounting', 'IncomingPayment', 'List', 'page', 'Accounting.IncomingPayment', 1251, 'IncomingPayments-List'),
(1252, 'Accounting.IncomingPayment.Save', 'Create/Update Incoming Payment', 'Accounting', 'IncomingPayment', 'Save', 'button', 'Accounting.IncomingPayment', 1252, 'IncomingPayments-Save'),
(1253, 'Accounting.IncomingPayment.Delete', 'Delete Incoming Payment', 'Accounting', 'IncomingPayment', 'Delete', 'button', 'Accounting.IncomingPayment', 1253, 'IncomingPayments-Delete'),

-- Transaction (1300)
(1300, 'Accounting.Transaction', 'Transaction', 'Accounting', 'Transaction', '', 'resource', 'Accounting', 1300, NULL),
(1301, 'Accounting.Transaction.List', 'List Transactions', 'Accounting', 'Transaction', 'List', 'page', 'Accounting.Transaction', 1301, 'Transactions-List'),

-- TransferFund (1350)
(1350, 'Accounting.TransferFund', 'Transfer Fund', 'Accounting', 'TransferFund', '', 'resource', 'Accounting', 1350, NULL),
(1351, 'Accounting.TransferFund.List', 'List Transfer Funds', 'Accounting', 'TransferFund', 'List', 'page', 'Accounting.TransferFund', 1351, 'TransferFunds-List'),
(1352, 'Accounting.TransferFund.Save', 'Create/Update Transfer Fund', 'Accounting', 'TransferFund', 'Save', 'button', 'Accounting.TransferFund', 1352, 'TransferFunds-Save'),
(1353, 'Accounting.TransferFund.Delete', 'Delete Transfer Fund', 'Accounting', 'TransferFund', 'Delete', 'button', 'Accounting.TransferFund', 1353, 'TransferFunds-Delete');

-- ============================================================
-- ADMIN (2000-2999) — 13 resources
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey) VALUES
(2000, 'Admin', 'Admin', 'Admin', '', '', 'menu', NULL, 2000, NULL),

-- DocumentTemplate (2050)
(2050, 'Admin.DocumentTemplate', 'Document Template', 'Admin', 'DocumentTemplate', '', 'resource', 'Admin', 2050, NULL),
(2051, 'Admin.DocumentTemplate.List', 'List Document Templates', 'Admin', 'DocumentTemplate', 'List', 'page', 'Admin.DocumentTemplate', 2051, 'DocumentTemplates-List'),
(2052, 'Admin.DocumentTemplate.Create', 'Create Document Template', 'Admin', 'DocumentTemplate', 'Create', 'button', 'Admin.DocumentTemplate', 2052, 'DocumentTemplates-Create'),
(2053, 'Admin.DocumentTemplate.Update', 'Update Document Template', 'Admin', 'DocumentTemplate', 'Update', 'button', 'Admin.DocumentTemplate', 2053, 'DocumentTemplates-Update'),
(2054, 'Admin.DocumentTemplate.Delete', 'Delete Document Template', 'Admin', 'DocumentTemplate', 'Delete', 'button', 'Admin.DocumentTemplate', 2054, 'DocumentTemplates-Delete'),

-- EmailLog (2100)
(2100, 'Admin.EmailLog', 'Email Log', 'Admin', 'EmailLog', '', 'resource', 'Admin', 2100, NULL),
(2101, 'Admin.EmailLog.List', 'List Email Logs', 'Admin', 'EmailLog', 'List', 'page', 'Admin.EmailLog', 2101, 'EmailLogs-List'),

-- Export (2150)
(2150, 'Admin.Export', 'Export', 'Admin', 'Export', '', 'resource', 'Admin', 2150, NULL),
(2151, 'Admin.Export.Customers', 'Export Customers', 'Admin', 'Export', 'Customers', 'page', 'Admin.Export', 2151, 'Export-Customers'),
(2152, 'Admin.Export.Vendors', 'Export Vendors', 'Admin', 'Export', 'Vendors', 'button', 'Admin.Export', 2152, 'Export-Vendors'),
(2153, 'Admin.Export.Order', 'Export Orders', 'Admin', 'Export', 'Order', 'button', 'Admin.Export', 2153, 'Export-Order'),

-- Holiday (2200)
(2200, 'Admin.Holiday', 'Holiday', 'Admin', 'Holiday', '', 'resource', 'Admin', 2200, NULL),
(2201, 'Admin.Holiday.List', 'List Holidays', 'Admin', 'Holiday', 'List', 'page', 'Admin.Holiday', 2201, 'Holidays-List'),
(2202, 'Admin.Holiday.Create', 'Create Holiday', 'Admin', 'Holiday', 'Create', 'button', 'Admin.Holiday', 2202, 'Holidays-Create'),
(2203, 'Admin.Holiday.Update', 'Update Holiday', 'Admin', 'Holiday', 'Update', 'button', 'Admin.Holiday', 2203, 'Holidays-Update'),
(2204, 'Admin.Holiday.Delete', 'Delete Holiday', 'Admin', 'Holiday', 'Delete', 'button', 'Admin.Holiday', 2204, 'Holidays-Delete'),

-- ItemTag (2250)
(2250, 'Admin.ItemTag', 'Item Tag', 'Admin', 'ItemTag', '', 'resource', 'Admin', 2250, NULL),
(2251, 'Admin.ItemTag.List', 'List Item Tags', 'Admin', 'ItemTag', 'List', 'page', 'Admin.ItemTag', 2251, 'ItemTags-List'),
(2252, 'Admin.ItemTag.Create', 'Create Item Tag', 'Admin', 'ItemTag', 'Create', 'button', 'Admin.ItemTag', 2252, 'ItemTags-Create'),
(2253, 'Admin.ItemTag.Update', 'Update Item Tag', 'Admin', 'ItemTag', 'Update', 'button', 'Admin.ItemTag', 2253, 'ItemTags-Update'),
(2254, 'Admin.ItemTag.Delete', 'Delete Item Tag', 'Admin', 'ItemTag', 'Delete', 'button', 'Admin.ItemTag', 2254, 'ItemTags-Delete'),

-- ItemTariff (2300)
(2300, 'Admin.ItemTariff', 'Item Tariff', 'Admin', 'ItemTariff', '', 'resource', 'Admin', 2300, NULL),
(2301, 'Admin.ItemTariff.List', 'List Item Tariffs', 'Admin', 'ItemTariff', 'List', 'page', 'Admin.ItemTariff', 2301, 'ItemTariffs-List'),
(2302, 'Admin.ItemTariff.Create', 'Create Item Tariff', 'Admin', 'ItemTariff', 'Create', 'button', 'Admin.ItemTariff', 2302, 'ItemTariffs-Create'),
(2303, 'Admin.ItemTariff.Update', 'Update Item Tariff', 'Admin', 'ItemTariff', 'Update', 'button', 'Admin.ItemTariff', 2303, 'ItemTariffs-Update'),
(2304, 'Admin.ItemTariff.Delete', 'Delete Item Tariff', 'Admin', 'ItemTariff', 'Delete', 'button', 'Admin.ItemTariff', 2304, 'ItemTariffs-Delete'),

-- Promotion (2350)
(2350, 'Admin.Promotion', 'Promotion', 'Admin', 'Promotion', '', 'resource', 'Admin', 2350, NULL),
(2351, 'Admin.Promotion.List', 'List Promotion', 'Admin', 'Promotion', 'List', 'page', 'Admin.Promotion', 2351, 'Promotions-List'),
(2352, 'Admin.Promotion.Create', 'Create Promotion', 'Admin', 'Promotion', 'Create', 'button', 'Admin.Promotion', 2352, 'Promotions-Create'),
(2353, 'Admin.Promotion.Update', 'Update Promotion', 'Admin', 'Promotion', 'Update', 'button', 'Admin.Promotion', 2353, 'Promotions-Update'),
(2354, 'Admin.Promotion.Delete', 'Delete Promotion', 'Admin', 'Promotion', 'Delete', 'button', 'Admin.Promotion', 2354, 'Promotions-Delete'),

-- RecalcLog (2400)
(2400, 'Admin.RecalcLog', 'Recalculation Log', 'Admin', 'RecalcLog', '', 'resource', 'Admin', 2400, NULL),
(2401, 'Admin.RecalcLog.List', 'List Logs', 'Admin', 'RecalcLog', 'List', 'page', 'Admin.RecalcLog', 2401, 'RecalculationLogs-List'),

-- Rest365 (2450)
(2450, 'Admin.Rest365', 'Rest365', 'Admin', 'Rest365', '', 'resource', 'Admin', 2450, NULL),
(2451, 'Admin.Rest365.List', 'List Rest365', 'Admin', 'Rest365', 'List', 'page', 'Admin.Rest365', 2451, 'Rest365-List'),
(2452, 'Admin.Rest365.Create', 'Create Rest365', 'Admin', 'Rest365', 'Create', 'button', 'Admin.Rest365', 2452, 'Rest365-Create'),
(2453, 'Admin.Rest365.Update', 'Update Rest365', 'Admin', 'Rest365', 'Update', 'button', 'Admin.Rest365', 2453, 'Rest365-Update'),
(2454, 'Admin.Rest365.Inactive', 'Inactive', 'Admin', 'Rest365', 'Inactive', 'button', 'Admin.Rest365', 2454, 'Rest365-Inactive'),

-- Role (2500)
(2500, 'Admin.Role', 'Role Management', 'Admin', 'Role', '', 'resource', 'Admin', 2500, NULL),
(2501, 'Admin.Role.List', 'List Roles', 'Admin', 'Role', 'List', 'page', 'Admin.Role', 2501, 'Roles-List'),
(2502, 'Admin.Role.Create', 'Create Role', 'Admin', 'Role', 'Create', 'button', 'Admin.Role', 2502, 'Roles-Create'),
(2503, 'Admin.Role.Update', 'Update Role', 'Admin', 'Role', 'Update', 'button', 'Admin.Role', 2503, 'Roles-Update'),
(2504, 'Admin.Role.Delete', 'Delete Role', 'Admin', 'Role', 'Delete', 'button', 'Admin.Role', 2504, 'Roles-Delete'),
(2505, 'Admin.Role.ViewPermission', 'View Permission', 'Admin', 'Role', 'ViewPermission', 'button', 'Admin.Role', 2505, 'Roles-GetControllers'),
(2506, 'Admin.Role.SavePermission', 'Save Permission', 'Admin', 'Role', 'SavePermission', 'button', 'Admin.Role', 2506, 'Roles-SavePermission'),

-- SchedulerConfig (2550)
(2550, 'Admin.SchedulerConfig', 'Scheduler Config', 'Admin', 'SchedulerConfig', '', 'resource', 'Admin', 2550, NULL),
(2551, 'Admin.SchedulerConfig.List', 'List Scheduler Configs', 'Admin', 'SchedulerConfig', 'List', 'page', 'Admin.SchedulerConfig', 2551, 'SchedulerConfigs-List'),
(2552, 'Admin.SchedulerConfig.Update', 'Update Scheduler Config', 'Admin', 'SchedulerConfig', 'Update', 'button', 'Admin.SchedulerConfig', 2552, 'SchedulerConfigs-Update'),

-- Term (2600)
(2600, 'Admin.Term', 'Term', 'Admin', 'Term', '', 'resource', 'Admin', 2600, NULL),
(2601, 'Admin.Term.List', 'List Terms', 'Admin', 'Term', 'List', 'page', 'Admin.Term', 2601, 'Terms-List'),
(2602, 'Admin.Term.Create', 'Create Term', 'Admin', 'Term', 'Create', 'button', 'Admin.Term', 2602, 'Terms-Create'),
(2603, 'Admin.Term.Update', 'Update Term', 'Admin', 'Term', 'Update', 'button', 'Admin.Term', 2603, 'Terms-Update'),
(2604, 'Admin.Term.Delete', 'Delete Term', 'Admin', 'Term', 'Delete', 'button', 'Admin.Term', 2604, 'Terms-Delete'),

-- Truck (2650)
(2650, 'Admin.Truck', 'Truck', 'Admin', 'Truck', '', 'resource', 'Admin', 2650, NULL),
(2651, 'Admin.Truck.List', 'List Trucks', 'Admin', 'Truck', 'List', 'page', 'Admin.Truck', 2651, 'Trucks-List'),
(2652, 'Admin.Truck.Create', 'Create Truck', 'Admin', 'Truck', 'Create', 'button', 'Admin.Truck', 2652, 'Trucks-Create'),
(2653, 'Admin.Truck.Update', 'Update Truck', 'Admin', 'Truck', 'Update', 'button', 'Admin.Truck', 2653, 'Trucks-Update'),
(2654, 'Admin.Truck.Delete', 'Delete Truck', 'Admin', 'Truck', 'Delete', 'button', 'Admin.Truck', 2654, 'Trucks-Delete');

-- ============================================================
-- CUSTOMER (3000-3999) — 7 resources
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey) VALUES
(3000, 'Customer', 'Customer', 'Customer', '', '', 'menu', NULL, 3000, NULL),

-- AR (3050)
(3050, 'Customer.AR', 'AR (Accounts Receivable)', 'Customer', 'AR', '', 'resource', 'Customer', 3050, NULL),
(3051, 'Customer.AR.List', 'List AR', 'Customer', 'AR', 'List', 'page', 'Customer.AR', 3051, 'AR-List'),
(3052, 'Customer.AR.ChargePayment', 'Charge Payment', 'Customer', 'AR', 'ChargePayment', 'button', 'Customer.AR', 3052, 'AR-ChargePayment'),

-- CustomerPayment (3100)
(3100, 'Customer.CustomerPayment', 'Customer Payment', 'Customer', 'CustomerPayment', '', 'resource', 'Customer', 3100, NULL),
(3101, 'Customer.CustomerPayment.List', 'List Customer Payments', 'Customer', 'CustomerPayment', 'List', 'page', 'Customer.CustomerPayment', 3101, 'CustomerPayments-List'),
(3102, 'Customer.CustomerPayment.Delete', 'Delete Payment', 'Customer', 'CustomerPayment', 'Delete', 'button', 'Customer.CustomerPayment', 3102, 'CustomerPayments-Delete'),
(3103, 'Customer.CustomerPayment.Save', 'Create/Update Customer Payment', 'Customer', 'CustomerPayment', 'Save', 'button', 'Customer.CustomerPayment', 3103, 'CustomerPayments-Save'),
(3104, 'Customer.CustomerPayment.SaveReturn', 'Return Payment', 'Customer', 'CustomerPayment', 'SaveReturn', 'button', 'Customer.CustomerPayment', 3104, 'CustomerPayments-SaveReturn'),
(3105, 'Customer.CustomerPayment.DeleteReturn', 'Delete Return Payment', 'Customer', 'CustomerPayment', 'DeleteReturn', 'button', 'Customer.CustomerPayment', 3105, 'CustomerPayments-DeleteReturn'),

-- Customer (3150)
(3150, 'Customer.Customer', 'Customer', 'Customer', 'Customer', '', 'resource', 'Customer', 3150, NULL),
(3151, 'Customer.Customer.List', 'List Customers', 'Customer', 'Customer', 'List', 'page', 'Customer.Customer', 3151, 'Customers-List'),
(3152, 'Customer.Customer.Create', 'Create Customer', 'Customer', 'Customer', 'Create', 'button', 'Customer.Customer', 3152, 'Customers-Create'),
(3153, 'Customer.Customer.Update', 'Update Customer', 'Customer', 'Customer', 'Update', 'button', 'Customer.Customer', 3153, 'Customers-Update'),
(3154, 'Customer.Customer.Delete', 'Delete Customer', 'Customer', 'Customer', 'Delete', 'button', 'Customer.Customer', 3154, 'Customers-Delete'),
(3155, 'Customer.Customer.OpenClose', 'Open/Close Customer', 'Customer', 'Customer', 'OpenClose', 'button', 'Customer.Customer', 3155, 'Customers-OpenClose'),
(3156, 'Customer.Customer.EmailPricesheet', 'Email Pricesheet', 'Customer', 'Customer', 'EmailPricesheet', 'button', 'Customer.Customer', 3156, 'Customers-EmailPricesheet'),
(3157, 'Customer.Customer.EmailStatement', 'Email Statement', 'Customer', 'Customer', 'EmailStatement', 'button', 'Customer.Customer', 3157, 'Customers-EmailStatement'),

-- Deposit (3200)
(3200, 'Customer.Deposit', 'Deposit', 'Customer', 'Deposit', '', 'resource', 'Customer', 3200, NULL),
(3201, 'Customer.Deposit.List', 'List Deposits', 'Customer', 'Deposit', 'List', 'page', 'Customer.Deposit', 3201, 'Deposits-List'),
(3202, 'Customer.Deposit.Save', 'Create/Update Deposit', 'Customer', 'Deposit', 'Save', 'button', 'Customer.Deposit', 3202, 'Deposits-Save'),
(3203, 'Customer.Deposit.Delete', 'Delete Deposit', 'Customer', 'Deposit', 'Delete', 'button', 'Customer.Deposit', 3203, 'Deposits-Delete'),

-- PaymentMethod (3250)
(3250, 'Customer.PaymentMethod', 'Payment Method', 'Customer', 'PaymentMethod', '', 'resource', 'Customer', 3250, NULL),
(3251, 'Customer.PaymentMethod.Create', 'Create Method', 'Customer', 'PaymentMethod', 'Create', 'button', 'Customer.PaymentMethod', 3251, 'PaymentMethods-Create'),
(3252, 'Customer.PaymentMethod.Delete', 'Delete Method', 'Customer', 'PaymentMethod', 'Delete', 'button', 'Customer.PaymentMethod', 3252, 'PaymentMethods-Delete'),

-- Sale (3300)
(3300, 'Customer.Sale', 'Sales Order', 'Customer', 'Sale', '', 'resource', 'Customer', 3300, NULL),
(3301, 'Customer.Sale.List', 'List Orders', 'Customer', 'Sale', 'List', 'page', 'Customer.Sale', 3301, 'Sales-List'),
(3302, 'Customer.Sale.UpdateRoute', 'Update Route', 'Customer', 'Sale', 'UpdateRoute', 'button', 'Customer.Sale', 3302, 'Sales-UpdateRoute'),
(3303, 'Customer.Sale.UpdateStage', 'Update Stage', 'Customer', 'Sale', 'UpdateStage', 'button', 'Customer.Sale', 3303, 'Sales-UpdateStage'),
(3304, 'Customer.Sale.UpdateInstruction', 'Update Instruction', 'Customer', 'Sale', 'UpdateInstruction', 'button', 'Customer.Sale', 3304, 'Sales-UpdateInstruction'),
(3305, 'Customer.Sale.UpdatePO', 'Update PO', 'Customer', 'Sale', 'UpdatePO', 'button', 'Customer.Sale', 3305, 'Sales-UpdatePO'),
(3306, 'Customer.Sale.UpdateLoadSeparate', 'Update Load Separate', 'Customer', 'Sale', 'UpdateLoadSeparate', 'button', 'Customer.Sale', 3306, 'Sales-UpdateLoadSeparate'),
(3307, 'Customer.Sale.UpdateCarrier', 'Update Carrier', 'Customer', 'Sale', 'UpdateCarrier', 'button', 'Customer.Sale', 3307, 'Sales-UpdateCarrier'),
(3308, 'Customer.Sale.Delete', 'Delete Order', 'Customer', 'Sale', 'Delete', 'button', 'Customer.Sale', 3308, 'Sales-Delete'),
(3309, 'Customer.Sale.SeePdf', 'See Pdf Image', 'Customer', 'Sale', 'SeePdf', 'button', 'Customer.Sale', 3309, 'Sales-SeePdf'),
(3310, 'Customer.Sale.EmailPdf', 'Email Pdf Image', 'Customer', 'Sale', 'EmailPdf', 'button', 'Customer.Sale', 3310, 'Sales-EmailPdf'),
(3311, 'Customer.Sale.Create', 'Create Order', 'Customer', 'Sale', 'Create', 'button', 'Customer.Sale', 3311, 'Sales-Checkout'),
(3312, 'Customer.Sale.Update', 'Update Order', 'Customer', 'Sale', 'Update', 'button', 'Customer.Sale', 3312, 'Sales-UpdatePartially'),
(3313, 'Customer.Sale.ShippingCharge', 'Add Shipping Charge', 'Customer', 'Sale', 'ShippingCharge', 'button', 'Customer.Sale', 3313, 'Sales-ShippingCharge'),
(3314, 'Customer.Sale.MergeOrder', 'Merge Order', 'Customer', 'Sale', 'MergeOrder', 'button', 'Customer.Sale', 3314, 'Sales-MergeOrder'),
(3315, 'Customer.Sale.MergePdf', 'Merge Pdf', 'Customer', 'Sale', 'MergePdf', 'button', 'Customer.Sale', 3315, 'Sales-MergePdf'),
(3316, 'Customer.Sale.SeePayment', 'See Payment', 'Customer', 'Sale', 'SeePayment', 'button', 'Customer.Sale', 3316, 'Sales-SeePayment'),

-- BombSale (3350)
(3350, 'Customer.BombSale', 'Bomb Sale', 'Customer', 'BombSale', '', 'resource', 'Customer', 3350, NULL),
(3351, 'Customer.BombSale.List', 'List Bomb', 'Customer', 'BombSale', 'List', 'page', 'Customer.BombSale', 3351, 'TempBombSales-List'),
(3352, 'Customer.BombSale.Update', 'Update Detail', 'Customer', 'BombSale', 'Update', 'button', 'Customer.BombSale', 3352, 'TempBombSales-Update'),
(3353, 'Customer.BombSale.Save', 'Save Bomb', 'Customer', 'BombSale', 'Save', 'button', 'Customer.BombSale', 3353, 'TempBombSales-SaveBomb');

-- ============================================================
-- EMPLOYEE (4000-4999) — 5 resources
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey) VALUES
(4000, 'Employee', 'Employee', 'Employee', '', '', 'menu', NULL, 4000, NULL),

-- EmpAdvance (4050)
(4050, 'Employee.EmpAdvance', 'Employee Advance', 'Employee', 'EmpAdvance', '', 'resource', 'Employee', 4050, NULL),
(4051, 'Employee.EmpAdvance.List', 'List Advance Payments', 'Employee', 'EmpAdvance', 'List', 'page', 'Employee.EmpAdvance', 4051, 'EmpAdvances-List'),
(4052, 'Employee.EmpAdvance.Save', 'Create/Update Advance Payment', 'Employee', 'EmpAdvance', 'Save', 'button', 'Employee.EmpAdvance', 4052, 'EmpAdvances-Save'),
(4053, 'Employee.EmpAdvance.Delete', 'Delete Advance Payment', 'Employee', 'EmpAdvance', 'Delete', 'button', 'Employee.EmpAdvance', 4053, 'EmpAdvances-Delete'),

-- Employee (4100)
(4100, 'Employee.Employee', 'Employee', 'Employee', 'Employee', '', 'resource', 'Employee', 4100, NULL),
(4101, 'Employee.Employee.List', 'List Employees', 'Employee', 'Employee', 'List', 'page', 'Employee.Employee', 4101, 'Employees-List'),
(4102, 'Employee.Employee.Create', 'Create Employee', 'Employee', 'Employee', 'Create', 'button', 'Employee.Employee', 4102, 'Employees-Create'),
(4103, 'Employee.Employee.Update', 'Update Employee', 'Employee', 'Employee', 'Update', 'button', 'Employee.Employee', 4103, 'Employees-Update'),
(4104, 'Employee.Employee.Delete', 'Delete Employee', 'Employee', 'Employee', 'Delete', 'button', 'Employee.Employee', 4104, 'Employees-Delete'),

-- PayrollService (4150)
(4150, 'Employee.PayrollService', 'Payroll Service', 'Employee', 'PayrollService', '', 'resource', 'Employee', 4150, NULL),
(4151, 'Employee.PayrollService.List', 'List Payroll Service', 'Employee', 'PayrollService', 'List', 'page', 'Employee.PayrollService', 4151, 'PayrollServices-List'),
(4152, 'Employee.PayrollService.Save', 'Create/Update Payroll Service', 'Employee', 'PayrollService', 'Save', 'button', 'Employee.PayrollService', 4152, 'PayrollServices-Save'),
(4153, 'Employee.PayrollService.Delete', 'Delete Payroll Service', 'Employee', 'PayrollService', 'Delete', 'button', 'Employee.PayrollService', 4153, 'PayrollServices-Delete'),

-- Payroll (4200)
(4200, 'Employee.Payroll', 'Payroll', 'Employee', 'Payroll', '', 'resource', 'Employee', 4200, NULL),
(4201, 'Employee.Payroll.List', 'List Payrolls', 'Employee', 'Payroll', 'List', 'page', 'Employee.Payroll', 4201, 'Payrolls-List'),
(4202, 'Employee.Payroll.Save', 'Create/Update Payroll', 'Employee', 'Payroll', 'Save', 'button', 'Employee.Payroll', 4202, 'Payrolls-Save'),
(4203, 'Employee.Payroll.Delete', 'Delete Payroll', 'Employee', 'Payroll', 'Delete', 'button', 'Employee.Payroll', 4203, 'Payrolls-Delete'),
(4204, 'Employee.Payroll.Import', 'Import Payroll', 'Employee', 'Payroll', 'Import', 'button', 'Employee.Payroll', 4204, 'Payrolls-Import'),

-- Timesheet (4250)
(4250, 'Employee.Timesheet', 'Timesheet', 'Employee', 'Timesheet', '', 'resource', 'Employee', 4250, NULL),
(4251, 'Employee.Timesheet.List', 'List Timesheets', 'Employee', 'Timesheet', 'List', 'page', 'Employee.Timesheet', 4251, 'Timesheets-List'),
(4252, 'Employee.Timesheet.Save', 'Create/Update Timesheet', 'Employee', 'Timesheet', 'Save', 'button', 'Employee.Timesheet', 4252, 'Timesheets-Save'),
(4253, 'Employee.Timesheet.Delete', 'Delete Timesheet', 'Employee', 'Timesheet', 'Delete', 'button', 'Employee.Timesheet', 4253, 'Timesheets-Delete');

-- ============================================================
-- PRODUCT (5000-5999) — 6 resources
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey) VALUES
(5000, 'Product', 'Product', 'Product', '', '', 'menu', NULL, 5000, NULL),

-- InventoryAdj (5050)
(5050, 'Product.InventoryAdj', 'Inventory Adjustment', 'Product', 'InventoryAdj', '', 'resource', 'Product', 5050, NULL),
(5051, 'Product.InventoryAdj.List', 'List Adjustments', 'Product', 'InventoryAdj', 'List', 'page', 'Product.InventoryAdj', 5051, 'InventoryAdjs-List'),
(5052, 'Product.InventoryAdj.Save', 'Create/Update Adjustment', 'Product', 'InventoryAdj', 'Save', 'button', 'Product.InventoryAdj', 5052, 'InventoryAdjs-Save'),
(5053, 'Product.InventoryAdj.Delete', 'Delete Adjustment', 'Product', 'InventoryAdj', 'Delete', 'button', 'Product.InventoryAdj', 5053, 'InventoryAdjs-Delete'),
(5054, 'Product.InventoryAdj.DeleteDetail', 'Delete Detail', 'Product', 'InventoryAdj', 'DeleteDetail', 'button', 'Product.InventoryAdj', 5054, 'InventoryAdjs-DeleteDetail'),
(5055, 'Product.InventoryAdj.QtyAdj', 'Qty Adjustment', 'Product', 'InventoryAdj', 'QtyAdj', 'button', 'Product.InventoryAdj', 5055, 'InventoryAdjs-QtyAdj'),

-- ItemCategory (5100)
(5100, 'Product.ItemCategory', 'Item Category', 'Product', 'ItemCategory', '', 'resource', 'Product', 5100, NULL),
(5101, 'Product.ItemCategory.List', 'List Categories', 'Product', 'ItemCategory', 'List', 'page', 'Product.ItemCategory', 5101, 'ItemCategories-List'),
(5102, 'Product.ItemCategory.Create', 'Create Category', 'Product', 'ItemCategory', 'Create', 'button', 'Product.ItemCategory', 5102, 'ItemCategories-Create'),
(5103, 'Product.ItemCategory.Update', 'Update Category', 'Product', 'ItemCategory', 'Update', 'button', 'Product.ItemCategory', 5103, 'ItemCategories-Update'),
(5104, 'Product.ItemCategory.Delete', 'Delete Category', 'Product', 'ItemCategory', 'Delete', 'button', 'Product.ItemCategory', 5104, 'ItemCategories-Delete'),
(5105, 'Product.ItemCategory.Reorder', 'Reorder Category', 'Product', 'ItemCategory', 'Reorder', 'button', 'Product.ItemCategory', 5105, 'ItemCategories-ReorderNode'),

-- ItemHistory (5150)
(5150, 'Product.ItemHistory', 'Item History', 'Product', 'ItemHistory', '', 'resource', 'Product', 5150, NULL),
(5151, 'Product.ItemHistory.Sales', 'View Order History', 'Product', 'ItemHistory', 'Sales', 'page', 'Product.ItemHistory', 5151, 'ItemHistories-Sales'),
(5152, 'Product.ItemHistory.Purchase', 'View Cost History', 'Product', 'ItemHistory', 'Purchase', 'button', 'Product.ItemHistory', 5152, 'ItemHistories-Purchase'),
(5153, 'Product.ItemHistory.Inventory', 'View Inventory History', 'Product', 'ItemHistory', 'Inventory', 'button', 'Product.ItemHistory', 5153, 'ItemHistories-Inventory'),
(5154, 'Product.ItemHistory.SalesCost', 'View Cost + Order History', 'Product', 'ItemHistory', 'SalesCost', 'button', 'Product.ItemHistory', 5154, 'ItemHistories-SalesCost'),
(5155, 'Product.ItemHistory.Adjustment', 'View Adjustment History', 'Product', 'ItemHistory', 'Adjustment', 'button', 'Product.ItemHistory', 5155, 'ItemHistories-Adjustment'),

-- ItemImage (5200)
(5200, 'Product.ItemImage', 'Item Image', 'Product', 'ItemImage', '', 'resource', 'Product', 5200, NULL),
(5201, 'Product.ItemImage.List', 'List Images', 'Product', 'ItemImage', 'List', 'page', 'Product.ItemImage', 5201, 'ItemImages-List'),
(5202, 'Product.ItemImage.Upload', 'Upload Image', 'Product', 'ItemImage', 'Upload', 'button', 'Product.ItemImage', 5202, 'ItemImages-Upload'),
(5203, 'Product.ItemImage.Delete', 'Delete Image', 'Product', 'ItemImage', 'Delete', 'button', 'Product.ItemImage', 5203, 'ItemImages-Delete'),

-- ItemStorage (5250)
(5250, 'Product.ItemStorage', 'Item Storage', 'Product', 'ItemStorage', '', 'resource', 'Product', 5250, NULL),
(5251, 'Product.ItemStorage.List', 'List Storages', 'Product', 'ItemStorage', 'List', 'page', 'Product.ItemStorage', 5251, 'ItemStorages-List'),
(5252, 'Product.ItemStorage.Create', 'Create Storage', 'Product', 'ItemStorage', 'Create', 'button', 'Product.ItemStorage', 5252, 'ItemStorages-Create'),
(5253, 'Product.ItemStorage.Update', 'Update Storage', 'Product', 'ItemStorage', 'Update', 'button', 'Product.ItemStorage', 5253, 'ItemStorages-Update'),
(5254, 'Product.ItemStorage.Delete', 'Delete Storage', 'Product', 'ItemStorage', 'Delete', 'button', 'Product.ItemStorage', 5254, 'ItemStorages-Delete'),

-- Item (5300)
(5300, 'Product.Item', 'Item', 'Product', 'Item', '', 'resource', 'Product', 5300, NULL),
(5301, 'Product.Item.List', 'List Products', 'Product', 'Item', 'List', 'page', 'Product.Item', 5301, 'Items-List'),
(5302, 'Product.Item.Delete', 'Delete Product', 'Product', 'Item', 'Delete', 'button', 'Product.Item', 5302, 'Items-Delete'),
(5303, 'Product.Item.Save', 'Create/Update Product', 'Product', 'Item', 'Save', 'button', 'Product.Item', 5303, 'Items-Save'),
(5304, 'Product.Item.UpdateBaseP1', 'Edit P1', 'Product', 'Item', 'UpdateBaseP1', 'button', 'Product.Item', 5304, 'Items-UpdateBaseP1'),
(5305, 'Product.Item.UpdateInventorySettings', 'Edit Inventory Settings', 'Product', 'Item', 'UpdateInventorySettings', 'button', 'Product.Item', 5305, 'Items-UpdateInventorySettings'),
(5306, 'Product.Item.UpdateItemUnit', 'Edit Item Unit', 'Product', 'Item', 'UpdateItemUnit', 'button', 'Product.Item', 5306, 'Items-UpdateItemUnit'),
(5307, 'Product.Item.CreateItemUnit', 'Create Item Unit', 'Product', 'Item', 'CreateItemUnit', 'button', 'Product.Item', 5307, 'Items-CreateItemUnit'),
(5308, 'Product.Item.DeleteItemUnit', 'Delete Item Unit', 'Product', 'Item', 'DeleteItemUnit', 'button', 'Product.Item', 5308, 'Items-DeleteItemUnit');

-- ============================================================
-- REPORT (6000-6999) — 9 resources
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey) VALUES
(6000, 'Report', 'Report', 'Report', '', '', 'menu', NULL, 6000, NULL),

-- PL (6050)
(6050, 'Report.PL', 'Profit and Loss', 'Report', 'PL', '', 'resource', 'Report', 6050, NULL),
(6051, 'Report.PL.BalanceSheet', 'Balance Sheet', 'Report', 'PL', 'BalanceSheet', 'page', 'Report.PL', 6051, 'Reports-BalanceSheet'),
(6052, 'Report.PL.ProfitLoss', 'Profit Loss', 'Report', 'PL', 'ProfitLoss', 'page', 'Report.PL', 6052, 'Reports-ProfitLoss'),
(6053, 'Report.PL.Ledger', 'Ledger', 'Report', 'PL', 'Ledger', 'page', 'Report.PL', 6053, 'Reports-Ledger'),
(6054, 'Report.PL.LedgerByPayee', 'Ledger By Payee', 'Report', 'PL', 'LedgerByPayee', 'page', 'Report.PL', 6054, 'Reports-LedgerByPayee'),

-- Sales (6100)
(6100, 'Report.Sales', 'Sales Report', 'Report', 'Sales', '', 'resource', 'Report', 6100, NULL),
(6101, 'Report.Sales.SalesDaily', 'Sales Daily', 'Report', 'Sales', 'SalesDaily', 'page', 'Report.Sales', 6101, 'Reports-SalesDaily'),
(6102, 'Report.Sales.SalesTax', 'Sales Tax', 'Report', 'Sales', 'SalesTax', 'page', 'Report.Sales', 6102, 'Reports-SalesTax'),
(6103, 'Report.Sales.Responsible', 'Responsible', 'Report', 'Sales', 'Responsible', 'page', 'Report.Sales', 6103, 'Reports-Responsible'),
(6104, 'Report.Sales.DailySummary', 'Daily Summary', 'Report', 'Sales', 'DailySummary', 'page', 'Report.Sales', 6104, 'Reports-DailySummary'),
(6105, 'Report.Sales.CreditMemo', 'Credit Memo', 'Report', 'Sales', 'CreditMemo', 'page', 'Report.Sales', 6105, 'Reports-CreditMemo'),
(6106, 'Report.Sales.SalesByItem', 'Sales By Item', 'Report', 'Sales', 'SalesByItem', 'page', 'Report.Sales', 6106, 'Reports-SalesByItem'),
(6107, 'Report.Sales.SalesDetail', 'Sales Detail', 'Report', 'Sales', 'SalesDetail', 'page', 'Report.Sales', 6107, 'Reports-SalesDetail'),
(6108, 'Report.Sales.SalesDaily2', 'Sales Daily 2', 'Report', 'Sales', 'SalesDaily2', 'page', 'Report.Sales', 6108, 'Reports-SalesDaily2'),
(6109, 'Report.Sales.SalesYearly', 'Sales Yearly', 'Report', 'Sales', 'SalesYearly', 'page', 'Report.Sales', 6109, 'Reports-SalesYearly'),
(6110, 'Report.Sales.SalesCommission', 'Sales Commission', 'Report', 'Sales', 'SalesCommission', 'page', 'Report.Sales', 6110, 'Reports-SalesCommission'),
(6111, 'Report.Sales.SalesCommission2', 'Sales Commission 2', 'Report', 'Sales', 'SalesCommission2', 'page', 'Report.Sales', 6111, 'Reports-SalesCommission2'),

-- Customer (6150)
(6150, 'Report.Customer', 'Customer Report', 'Report', 'Customer', '', 'resource', 'Report', 6150, NULL),
(6151, 'Report.Customer.DescDollar', 'Descending Dollar', 'Report', 'Customer', 'DescDollar', 'page', 'Report.Customer', 6151, 'Reports-DescDollar'),
(6152, 'Report.Customer.PaymentHistory', 'Payment History', 'Report', 'Customer', 'PaymentHistory', 'page', 'Report.Customer', 6152, 'Reports-PaymentHistory'),
(6153, 'Report.Customer.Statement', 'Statement', 'Report', 'Customer', 'Statement', 'page', 'Report.Customer', 6153, 'Reports-CustStmt'),
(6154, 'Report.Customer.AccountHistory', 'Account History', 'Report', 'Customer', 'AccountHistory', 'page', 'Report.Customer', 6154, 'Reports-AccountHistory'),
(6155, 'Report.Customer.Pricesheet', 'Pricesheet', 'Report', 'Customer', 'Pricesheet', 'page', 'Report.Customer', 6155, 'Reports-Pricesheet'),
(6156, 'Report.Customer.OrderGuide', 'Order Guide', 'Report', 'Customer', 'OrderGuide', 'page', 'Report.Customer', 6156, 'Reports-OrderGuide'),
(6157, 'Report.Customer.ItemVolume', 'Item Volume History', 'Report', 'Customer', 'ItemVolume', 'page', 'Report.Customer', 6157, 'Reports-CustItemVolume'),
(6158, 'Report.Customer.SalesByItem', 'Sales By Item', 'Report', 'Customer', 'SalesByItem', 'page', 'Report.Customer', 6158, 'Reports-CustSalesByItem'),
(6159, 'Report.Customer.SalesHistory', 'Sales History', 'Report', 'Customer', 'SalesHistory', 'page', 'Report.Customer', 6159, 'Reports-SalesHistory'),
(6160, 'Report.Customer.CustPayment', 'Customer Payment', 'Report', 'Customer', 'CustPayment', 'page', 'Report.Customer', 6160, 'Reports-CustPayment'),

-- Banking (6200)
(6200, 'Report.Banking', 'Banking Report', 'Report', 'Banking', '', 'resource', 'Report', 6200, NULL),
(6201, 'Report.Banking.BankRecon', 'Bank Reconciliation', 'Report', 'Banking', 'BankRecon', 'page', 'Report.Banking', 6201, 'Reports-BankRecon'),
(6202, 'Report.Banking.PmtReceipt', 'Payment Receipt', 'Report', 'Banking', 'PmtReceipt', 'page', 'Report.Banking', 6202, 'Reports-PmtReceipt'),

-- AP (6250)
(6250, 'Report.AP', 'Accounts Payable', 'Report', 'AP', '', 'resource', 'Report', 6250, NULL),
(6251, 'Report.AP.APCheck', 'AP Check', 'Report', 'AP', 'APCheck', 'page', 'Report.AP', 6251, 'Reports-APCheck'),
(6252, 'Report.AP.CheckToBePrinted', 'Check To Be Printed', 'Report', 'AP', 'CheckToBePrinted', 'page', 'Report.AP', 6252, 'Reports-CheckToBePrinted'),
(6253, 'Report.AP.APInvoice', 'AP From Invoice', 'Report', 'AP', 'APInvoice', 'page', 'Report.AP', 6253, 'Reports-APInvoice'),

-- AR (6300)
(6300, 'Report.AR', 'Accounts Receivable', 'Report', 'AR', '', 'resource', 'Report', 6300, NULL),
(6301, 'Report.AR.ARInvoice', 'AR From Invoice', 'Report', 'AR', 'ARInvoice', 'page', 'Report.AR', 6301, 'Reports-ARInvoice'),
(6302, 'Report.AR.ARMonth', 'AR Month', 'Report', 'AR', 'ARMonth', 'page', 'Report.AR', 6302, 'Reports-ARMonth'),

-- Timesheet (6350)
(6350, 'Report.Timesheet', 'Timesheet Report', 'Report', 'Timesheet', '', 'resource', 'Report', 6350, NULL),
(6351, 'Report.Timesheet.Timesheet', 'Timesheet', 'Report', 'Timesheet', 'Timesheet', 'page', 'Report.Timesheet', 6351, 'Reports-Timesheet'),
(6352, 'Report.Timesheet.JobSummary', 'Job Summary', 'Report', 'Timesheet', 'JobSummary', 'page', 'Report.Timesheet', 6352, 'Reports-JobSummary'),

-- Payroll (6400)
(6400, 'Report.Payroll', 'Payroll Report', 'Report', 'Payroll', '', 'resource', 'Report', 6400, NULL),
(6401, 'Report.Payroll.Payroll', 'Payroll', 'Report', 'Payroll', 'Payroll', 'page', 'Report.Payroll', 6401, 'Reports-Payroll'),
(6402, 'Report.Payroll.EmpLoanLedger', 'Employee Loan Ledger', 'Report', 'Payroll', 'EmpLoanLedger', 'page', 'Report.Payroll', 6402, 'Reports-EmpLoanLedger'),

-- Inventory (6450)
(6450, 'Report.Inventory', 'Inventory Report', 'Report', 'Inventory', '', 'resource', 'Report', 6450, NULL),
(6451, 'Report.Inventory.InventoryStatus', 'Inventory Status', 'Report', 'Inventory', 'InventoryStatus', 'page', 'Report.Inventory', 6451, 'Reports-InventoryStatus'),
(6452, 'Report.Inventory.Reorder', 'Reorder', 'Report', 'Inventory', 'Reorder', 'page', 'Report.Inventory', 6452, 'Reports-Reorder'),
(6453, 'Report.Inventory.InventoryValuation', 'Inventory Valuation', 'Report', 'Inventory', 'InventoryValuation', 'page', 'Report.Inventory', 6453, 'Reports-InventoryValuation'),
(6454, 'Report.Inventory.InventoryMovement', 'Inventory Movement', 'Report', 'Inventory', 'InventoryMovement', 'page', 'Report.Inventory', 6454, 'Reports-InventoryMovement'),
(6455, 'Report.Inventory.InventoryIncoming', 'Incoming Purchases', 'Report', 'Inventory', 'InventoryIncoming', 'page', 'Report.Inventory', 6455, 'Reports-InventoryIncoming');

-- ============================================================
-- VENDOR (7000-7999) — 6 resources
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey) VALUES
(7000, 'Vendor', 'Vendor', 'Vendor', '', '', 'menu', NULL, 7000, NULL),

-- Liability (7050)
(7050, 'Vendor.Liability', 'Liability', 'Vendor', 'Liability', '', 'resource', 'Vendor', 7050, NULL),
(7051, 'Vendor.Liability.LoanList', 'Loan Manager', 'Vendor', 'Liability', 'LoanList', 'page', 'Vendor.Liability', 7051, 'Liabilities-LoanList'),
(7052, 'Vendor.Liability.TaxList', 'Tax Manager', 'Vendor', 'Liability', 'TaxList', 'page', 'Vendor.Liability', 7052, 'Liabilities-TaxList'),
(7053, 'Vendor.Liability.CCList', 'CC Manager', 'Vendor', 'Liability', 'CCList', 'page', 'Vendor.Liability', 7053, 'Liabilities-CCList'),
(7054, 'Vendor.Liability.Create', 'Create Liability', 'Vendor', 'Liability', 'Create', 'button', 'Vendor.Liability', 7054, 'Liabilities-Create'),
(7055, 'Vendor.Liability.Update', 'Update Liability', 'Vendor', 'Liability', 'Update', 'button', 'Vendor.Liability', 7055, 'Liabilities-Update'),
(7056, 'Vendor.Liability.Delete', 'Delete Liability', 'Vendor', 'Liability', 'Delete', 'button', 'Vendor.Liability', 7056, 'Liabilities-Delete'),
(7057, 'Vendor.Liability.DeletePayment', 'Delete Payment', 'Vendor', 'Liability', 'DeletePayment', 'button', 'Vendor.Liability', 7057, 'Liabilities-DeletePayment'),
(7058, 'Vendor.Liability.TxList', 'Tx List', 'Vendor', 'Liability', 'TxList', 'button', 'Vendor.Liability', 7058, 'Liabilities-TxList'),
(7059, 'Vendor.Liability.SaveLoanPayment', 'Save Loan Payment', 'Vendor', 'Liability', 'SaveLoanPayment', 'button', 'Vendor.Liability', 7059, 'Liabilities-SaveLoanPayment'),
(7060, 'Vendor.Liability.SaveCCPayment', 'Save CC Payment', 'Vendor', 'Liability', 'SaveCCPayment', 'button', 'Vendor.Liability', 7060, 'Liabilities-SaveCCPayment'),
(7061, 'Vendor.Liability.ImportTaxPayment', 'Import Tax Payment', 'Vendor', 'Liability', 'ImportTaxPayment', 'button', 'Vendor.Liability', 7061, 'Liabilities-ImportTaxPayment'),

-- PurchaseOrder (7100)
(7100, 'Vendor.PurchaseOrder', 'Purchase Order', 'Vendor', 'PurchaseOrder', '', 'resource', 'Vendor', 7100, NULL),
(7101, 'Vendor.PurchaseOrder.List', 'List PO', 'Vendor', 'PurchaseOrder', 'List', 'page', 'Vendor.PurchaseOrder', 7101, 'PurchaseOrders-List'),
(7102, 'Vendor.PurchaseOrder.Create', 'Create/Update PO', 'Vendor', 'PurchaseOrder', 'Create', 'button', 'Vendor.PurchaseOrder', 7102, 'PurchaseOrders-Checkout'),
(7103, 'Vendor.PurchaseOrder.Delete', 'Delete PO', 'Vendor', 'PurchaseOrder', 'Delete', 'button', 'Vendor.PurchaseOrder', 7103, 'PurchaseOrders-Delete'),
(7104, 'Vendor.PurchaseOrder.CopyToBill', 'Receive Product', 'Vendor', 'PurchaseOrder', 'CopyToBill', 'button', 'Vendor.PurchaseOrder', 7104, 'PurchaseOrders-CopyToBill'),
(7105, 'Vendor.PurchaseOrder.Print', 'Print PO', 'Vendor', 'PurchaseOrder', 'Print', 'button', 'Vendor.PurchaseOrder', 7105, 'PurchaseOrders-PrintPO'),
(7106, 'Vendor.PurchaseOrder.ConvertToBill', 'Convert To Bill', 'Vendor', 'PurchaseOrder', 'ConvertToBill', 'button', 'Vendor.PurchaseOrder', 7106, 'PurchaseOrders-UpdateToBillStage'),
(7107, 'Vendor.PurchaseOrder.SaveAdvance', 'Save Advance Payment', 'Vendor', 'PurchaseOrder', 'SaveAdvance', 'button', 'Vendor.PurchaseOrder', 7107, 'PurchaseOrders-SaveAdvance'),
(7108, 'Vendor.PurchaseOrder.GetAdvances', 'Advance Payments', 'Vendor', 'PurchaseOrder', 'GetAdvances', 'button', 'Vendor.PurchaseOrder', 7108, 'PurchaseOrders-GetAdvances'),
(7109, 'Vendor.PurchaseOrder.DeleteAdvance', 'Delete Advance Payment', 'Vendor', 'PurchaseOrder', 'DeleteAdvance', 'button', 'Vendor.PurchaseOrder', 7109, 'PurchaseOrders-DeleteAdvance'),

-- Purchase (7150)
(7150, 'Vendor.Purchase', 'Purchase / Bill', 'Vendor', 'Purchase', '', 'resource', 'Vendor', 7150, NULL),
(7151, 'Vendor.Purchase.List', 'List Bills', 'Vendor', 'Purchase', 'List', 'page', 'Vendor.Purchase', 7151, 'Purchases-List'),
(7152, 'Vendor.Purchase.UpdateDocNumber', 'Update Doc Number', 'Vendor', 'Purchase', 'UpdateDocNumber', 'button', 'Vendor.Purchase', 7152, 'Purchases-UpdateDocNumber'),
(7153, 'Vendor.Purchase.UpdateInvoiceDate', 'Update Invoice Date', 'Vendor', 'Purchase', 'UpdateInvoiceDate', 'button', 'Vendor.Purchase', 7153, 'Purchases-UpdateInvoiceDate'),
(7154, 'Vendor.Purchase.UpdateCommission', 'Update Commission', 'Vendor', 'Purchase', 'UpdateCommission', 'button', 'Vendor.Purchase', 7154, 'Purchases-UpdateCommission'),
(7155, 'Vendor.Purchase.UpdatePallet', 'Update Pallet', 'Vendor', 'Purchase', 'UpdatePallet', 'button', 'Vendor.Purchase', 7155, 'Purchases-UpdatePallet'),
(7156, 'Vendor.Purchase.UpdateContainer', 'Update Container', 'Vendor', 'Purchase', 'UpdateContainer', 'button', 'Vendor.Purchase', 7156, 'Purchases-UpdateContainer'),
(7157, 'Vendor.Purchase.Create', 'Create Bill', 'Vendor', 'Purchase', 'Create', 'button', 'Vendor.Purchase', 7157, 'Purchases-Checkout'),
(7158, 'Vendor.Purchase.Update', 'Update Bill', 'Vendor', 'Purchase', 'Update', 'button', 'Vendor.Purchase', 7158, 'Purchases-UpdatePartially'),
(7159, 'Vendor.Purchase.Delete', 'Delete Bill', 'Vendor', 'Purchase', 'Delete', 'button', 'Vendor.Purchase', 7159, 'Purchases-Delete'),
(7160, 'Vendor.Purchase.UploadBillPDF', 'Upload Bill Pdf', 'Vendor', 'Purchase', 'UploadBillPDF', 'button', 'Vendor.Purchase', 7160, 'Purchases-UploadBillPDF'),
(7161, 'Vendor.Purchase.SeePdf', 'See PDF Image', 'Vendor', 'Purchase', 'SeePdf', 'button', 'Vendor.Purchase', 7161, 'Purchases-SeePdf'),
(7162, 'Vendor.Purchase.AssignShipment', 'Assign Shipment', 'Vendor', 'Purchase', 'AssignShipment', 'button', 'Vendor.Purchase', 7162, 'Purchases-AssignShipment'),

-- Shipment (7200)
(7200, 'Vendor.Shipment', 'Shipment', 'Vendor', 'Shipment', '', 'resource', 'Vendor', 7200, NULL),
(7201, 'Vendor.Shipment.List', 'List Shipments', 'Vendor', 'Shipment', 'List', 'page', 'Vendor.Shipment', 7201, 'Shipments-List'),
(7202, 'Vendor.Shipment.Create', 'Create Shipment', 'Vendor', 'Shipment', 'Create', 'button', 'Vendor.Shipment', 7202, 'Shipments-Create'),
(7203, 'Vendor.Shipment.Update', 'Update Shipment', 'Vendor', 'Shipment', 'Update', 'button', 'Vendor.Shipment', 7203, 'Shipments-Update'),
(7204, 'Vendor.Shipment.Delete', 'Delete Shipment', 'Vendor', 'Shipment', 'Delete', 'button', 'Vendor.Shipment', 7204, 'Shipments-Delete'),
(7205, 'Vendor.Shipment.Reopen', 'Reopen Shipment', 'Vendor', 'Shipment', 'Reopen', 'button', 'Vendor.Shipment', 7205, 'Shipments-Reopen'),
(7206, 'Vendor.Shipment.GenerateBill', 'Generate Bill', 'Vendor', 'Shipment', 'GenerateBill', 'button', 'Vendor.Shipment', 7206, 'Shipments-GenerateBill'),
(7207, 'Vendor.Shipment.UnAllocation', 'UnAllocation Shipment', 'Vendor', 'Shipment', 'UnAllocation', 'button', 'Vendor.Shipment', 7207, 'Shipments-UnAllocation'),

-- VendorPayment (7250)
(7250, 'Vendor.VendorPayment', 'Vendor Payment', 'Vendor', 'VendorPayment', '', 'resource', 'Vendor', 7250, NULL),
(7251, 'Vendor.VendorPayment.List', 'List Vendor Payments', 'Vendor', 'VendorPayment', 'List', 'page', 'Vendor.VendorPayment', 7251, 'VendorPayments-List'),
(7252, 'Vendor.VendorPayment.Save', 'Create/Update Vendor Payment', 'Vendor', 'VendorPayment', 'Save', 'button', 'Vendor.VendorPayment', 7252, 'VendorPayments-Save'),
(7253, 'Vendor.VendorPayment.Delete', 'Delete Vendor Payment', 'Vendor', 'VendorPayment', 'Delete', 'button', 'Vendor.VendorPayment', 7253, 'VendorPayments-Delete'),
(7254, 'Vendor.VendorPayment.VoidCheck', 'Void Check', 'Vendor', 'VendorPayment', 'VoidCheck', 'button', 'Vendor.VendorPayment', 7254, 'VendorPayments-VoidCheck'),
(7255, 'Vendor.VendorPayment.UnVoidCheck', 'UnVoid Check', 'Vendor', 'VendorPayment', 'UnVoidCheck', 'button', 'Vendor.VendorPayment', 7255, 'VendorPayments-UnVoidCheck'),
(7256, 'Vendor.VendorPayment.Return', 'Create Return Vendor Payment', 'Vendor', 'VendorPayment', 'Return', 'button', 'Vendor.VendorPayment', 7256, 'VendorPayments-Return'),
(7257, 'Vendor.VendorPayment.DeleteReturn', 'Delete Return Vendor Payment', 'Vendor', 'VendorPayment', 'DeleteReturn', 'button', 'Vendor.VendorPayment', 7257, 'VendorPayments-DeleteReturn'),
(7258, 'Vendor.VendorPayment.SavePayNow', 'Create/Update Pay NOW', 'Vendor', 'VendorPayment', 'SavePayNow', 'button', 'Vendor.VendorPayment', 7258, 'VendorPayments-SavePayNow'),
(7259, 'Vendor.VendorPayment.ImportPayNow', 'Import Pay NOW', 'Vendor', 'VendorPayment', 'ImportPayNow', 'button', 'Vendor.VendorPayment', 7259, 'VendorPayments-ImportPayNow'),
(7260, 'Vendor.VendorPayment.ApplyAdvance', 'Apply Advance Payment', 'Vendor', 'VendorPayment', 'ApplyAdvance', 'button', 'Vendor.VendorPayment', 7260, 'VendorPayments-ApplyAdvance'),
(7261, 'Vendor.VendorPayment.UnapplyAdvance', 'Unapply Advance Payment', 'Vendor', 'VendorPayment', 'UnapplyAdvance', 'button', 'Vendor.VendorPayment', 7261, 'VendorPayments-UnapplyAdvance'),

-- Vendor (7300)
(7300, 'Vendor.Vendor', 'Vendor', 'Vendor', 'Vendor', '', 'resource', 'Vendor', 7300, NULL),
(7301, 'Vendor.Vendor.List', 'List Vendors', 'Vendor', 'Vendor', 'List', 'page', 'Vendor.Vendor', 7301, 'Vendors-List'),
(7302, 'Vendor.Vendor.Create', 'Create Vendor', 'Vendor', 'Vendor', 'Create', 'button', 'Vendor.Vendor', 7302, 'Vendors-Create'),
(7303, 'Vendor.Vendor.Update', 'Update Vendor', 'Vendor', 'Vendor', 'Update', 'button', 'Vendor.Vendor', 7303, 'Vendors-Update'),
(7304, 'Vendor.Vendor.Delete', 'Delete Vendor', 'Vendor', 'Vendor', 'Delete', 'button', 'Vendor.Vendor', 7304, 'Vendors-Delete'),
(7305, 'Vendor.Vendor.OpenClose', 'Open/Close Vendor', 'Vendor', 'Vendor', 'OpenClose', 'button', 'Vendor.Vendor', 7305, 'Vendors-OpenClose');

SET IDENTITY_INSERT Permission OFF;

-- ============================================================
-- VERIFY
-- ============================================================
SELECT PermissionType, COUNT(*) AS Cnt FROM Permission GROUP BY PermissionType ORDER BY PermissionType;
SELECT COUNT(*) AS TotalPermissions FROM Permission;
