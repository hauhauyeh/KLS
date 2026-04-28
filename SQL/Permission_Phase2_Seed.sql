-- ============================================================
-- Phase 2: Permission System — Seed Data (253 records)
-- Database: KLS_Latest
-- Run after Phase 1 DDL. Idempotent (checks before insert).
-- ============================================================

-- Clear existing data if re-running
DELETE FROM RolePermission;
DELETE FROM Permission;
DBCC CHECKIDENT ('Permission', RESEED, 0);
PRINT 'Cleared existing data';

SET IDENTITY_INSERT Permission ON;

-- ============================================================
-- MENU-LEVEL PERMISSIONS (7 records)
-- ============================================================
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(1, 'Accounting',  'Accounting',  'Accounting', '', '', 'menu', NULL, 100, NULL),
(2, 'Admin',       'Admin',       'Admin',      '', '', 'menu', NULL, 200, NULL),
(3, 'Customer',    'Customer',    'Customer',   '', '', 'menu', NULL, 300, NULL),
(4, 'Employee',    'Employee',    'Employee',   '', '', 'menu', NULL, 400, NULL),
(5, 'Product',     'Product',     'Product',    '', '', 'menu', NULL, 500, NULL),
(6, 'Report',      'Report',      'Report',     '', '', 'menu', NULL, 600, NULL),
(7, 'Vendor',      'Vendor',      'Vendor',     '', '', 'menu', NULL, 700, NULL);

-- ============================================================
-- ACCOUNTING MODULE (20 records)
-- ============================================================

-- Account (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(8,  'Accounting.Account.List',   'List Accounts',   'Accounting', 'Account', 'List',   'page',   'Accounting', 101, 'Accounts-List'),
(9,  'Accounting.Account.Create', 'Create Account',  'Accounting', 'Account', 'Create', 'button', 'Accounting.Account.List', 102, 'Accounts-Create'),
(10, 'Accounting.Account.Update', 'Update Account',  'Accounting', 'Account', 'Update', 'button', 'Accounting.Account.List', 103, 'Accounts-Update'),
(11, 'Accounting.Account.Delete', 'Delete Account',  'Accounting', 'Account', 'Delete', 'button', 'Accounting.Account.List', 104, 'Accounts-Delete');

-- BankRecon (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(12, 'Accounting.BankRecon.List',   'List Reconciliations',   'Accounting', 'BankRecon', 'List',   'page',   'Accounting', 111, 'BankRecons-List'),
(13, 'Accounting.BankRecon.Create', 'Create Reconciliation',  'Accounting', 'BankRecon', 'Create', 'button', 'Accounting.BankRecon.List', 112, 'BankRecons-Create'),
(14, 'Accounting.BankRecon.Update', 'Update Reconciliation',  'Accounting', 'BankRecon', 'Update', 'button', 'Accounting.BankRecon.List', 113, 'BankRecons-Update'),
(15, 'Accounting.BankRecon.Delete', 'Delete Reconciliation',  'Accounting', 'BankRecon', 'Delete', 'button', 'Accounting.BankRecon.List', 114, 'BankRecons-Delete');

-- CheckRegister (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(16, 'Accounting.CheckRegister.List',   'List Check Register',   'Accounting', 'CheckRegister', 'List',   'page',   'Accounting', 121, 'CheckRegister-List'),
(17, 'Accounting.CheckRegister.Update', 'Update Check Register', 'Accounting', 'CheckRegister', 'Update', 'button', 'Accounting.CheckRegister.List', 122, 'CheckRegister-Update');

-- GeneralJournal (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(18, 'Accounting.GeneralJournal.List',   'List General Journals',          'Accounting', 'GeneralJournal', 'List',   'page',   'Accounting', 131, 'GeneralJournals-List'),
(19, 'Accounting.GeneralJournal.Save',   'Create/Update General Journal',  'Accounting', 'GeneralJournal', 'Save',   'button', 'Accounting.GeneralJournal.List', 132, 'GeneralJournals-Save'),
(20, 'Accounting.GeneralJournal.Delete', 'Delete General Journal',         'Accounting', 'GeneralJournal', 'Delete', 'button', 'Accounting.GeneralJournal.List', 133, 'GeneralJournals-Delete');

-- IncomingPayment (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(21, 'Accounting.IncomingPayment.List',   'List Incoming Payments',          'Accounting', 'IncomingPayment', 'List',   'page',   'Accounting', 141, 'IncomingPayments-List'),
(22, 'Accounting.IncomingPayment.Save',   'Create/Update Incoming Payment',  'Accounting', 'IncomingPayment', 'Save',   'button', 'Accounting.IncomingPayment.List', 142, 'IncomingPayments-Save'),
(23, 'Accounting.IncomingPayment.Delete', 'Delete Incoming Payment',         'Accounting', 'IncomingPayment', 'Delete', 'button', 'Accounting.IncomingPayment.List', 143, 'IncomingPayments-Delete');

-- Transaction (1)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(24, 'Accounting.Transaction.List', 'List Transactions', 'Accounting', 'Transaction', 'List', 'page', 'Accounting', 151, 'Transactions-List');

-- TransferFund (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(25, 'Accounting.TransferFund.List',   'List Transfer Funds',          'Accounting', 'TransferFund', 'List',   'page',   'Accounting', 161, 'TransferFunds-List'),
(26, 'Accounting.TransferFund.Save',   'Create/Update Transfer Fund',  'Accounting', 'TransferFund', 'Save',   'button', 'Accounting.TransferFund.List', 162, 'TransferFunds-Save'),
(27, 'Accounting.TransferFund.Delete', 'Delete Transfer Fund',         'Accounting', 'TransferFund', 'Delete', 'button', 'Accounting.TransferFund.List', 163, 'TransferFunds-Delete');

-- ============================================================
-- ADMIN MODULE (45 records)
-- ============================================================

-- DocumentTemplate (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(28, 'Admin.DocumentTemplate.List',   'List Document Templates',   'Admin', 'DocumentTemplate', 'List',   'page',   'Admin', 201, 'DocumentTemplates-List'),
(29, 'Admin.DocumentTemplate.Create', 'Create Document Template',  'Admin', 'DocumentTemplate', 'Create', 'button', 'Admin.DocumentTemplate.List', 202, 'DocumentTemplates-Create'),
(30, 'Admin.DocumentTemplate.Update', 'Update Document Template',  'Admin', 'DocumentTemplate', 'Update', 'button', 'Admin.DocumentTemplate.List', 203, 'DocumentTemplates-Update'),
(31, 'Admin.DocumentTemplate.Delete', 'Delete Document Template',  'Admin', 'DocumentTemplate', 'Delete', 'button', 'Admin.DocumentTemplate.List', 204, 'DocumentTemplates-Delete');

-- EmailLog (1)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(32, 'Admin.EmailLog.List', 'List Email Logs', 'Admin', 'EmailLog', 'List', 'page', 'Admin', 211, 'EmailLogs-List');

-- Export (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(33, 'Admin.Export.Customers', 'Export Customers', 'Admin', 'Export', 'Customers', 'page',   'Admin', 221, 'Export-Customers'),
(34, 'Admin.Export.Vendors',   'Export Vendors',   'Admin', 'Export', 'Vendors',   'button', 'Admin.Export.Customers', 222, 'Export-Vendors'),
(35, 'Admin.Export.Order',     'Export Orders',    'Admin', 'Export', 'Order',     'button', 'Admin.Export.Customers', 223, 'Export-Order');

-- Holiday (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(36, 'Admin.Holiday.List',   'List Holidays',   'Admin', 'Holiday', 'List',   'page',   'Admin', 231, 'Holidays-List'),
(37, 'Admin.Holiday.Create', 'Create Holiday',  'Admin', 'Holiday', 'Create', 'button', 'Admin.Holiday.List', 232, 'Holidays-Create'),
(38, 'Admin.Holiday.Update', 'Update Holiday',  'Admin', 'Holiday', 'Update', 'button', 'Admin.Holiday.List', 233, 'Holidays-Update'),
(39, 'Admin.Holiday.Delete', 'Delete Holiday',  'Admin', 'Holiday', 'Delete', 'button', 'Admin.Holiday.List', 234, 'Holidays-Delete');

-- ItemTag (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(40, 'Admin.ItemTag.List',   'List Item Tags',   'Admin', 'ItemTag', 'List',   'page',   'Admin', 241, 'ItemTags-List'),
(41, 'Admin.ItemTag.Create', 'Create Item Tag',  'Admin', 'ItemTag', 'Create', 'button', 'Admin.ItemTag.List', 242, 'ItemTags-Create'),
(42, 'Admin.ItemTag.Update', 'Update Item Tag',  'Admin', 'ItemTag', 'Update', 'button', 'Admin.ItemTag.List', 243, 'ItemTags-Update'),
(43, 'Admin.ItemTag.Delete', 'Delete Item Tag',  'Admin', 'ItemTag', 'Delete', 'button', 'Admin.ItemTag.List', 244, 'ItemTags-Delete');

-- ItemTariff (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(44, 'Admin.ItemTariff.List',   'List Item Tariffs',   'Admin', 'ItemTariff', 'List',   'page',   'Admin', 251, 'ItemTariffs-List'),
(45, 'Admin.ItemTariff.Create', 'Create Item Tariff',  'Admin', 'ItemTariff', 'Create', 'button', 'Admin.ItemTariff.List', 252, 'ItemTariffs-Create'),
(46, 'Admin.ItemTariff.Update', 'Update Item Tariff',  'Admin', 'ItemTariff', 'Update', 'button', 'Admin.ItemTariff.List', 253, 'ItemTariffs-Update'),
(47, 'Admin.ItemTariff.Delete', 'Delete Item Tariff',  'Admin', 'ItemTariff', 'Delete', 'button', 'Admin.ItemTariff.List', 254, 'ItemTariffs-Delete');

-- Promotion (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(48, 'Admin.Promotion.List',   'List Promotion',   'Admin', 'Promotion', 'List',   'page',   'Admin', 261, 'Promotions-List'),
(49, 'Admin.Promotion.Create', 'Create Promotion', 'Admin', 'Promotion', 'Create', 'button', 'Admin.Promotion.List', 262, 'Promotions-Create'),
(50, 'Admin.Promotion.Update', 'Update Promotion', 'Admin', 'Promotion', 'Update', 'button', 'Admin.Promotion.List', 263, 'Promotions-Update'),
(51, 'Admin.Promotion.Delete', 'Delete Promotion', 'Admin', 'Promotion', 'Delete', 'button', 'Admin.Promotion.List', 264, 'Promotions-Delete');

-- RecalcLog (1)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(52, 'Admin.RecalcLog.List', 'List Logs', 'Admin', 'RecalcLog', 'List', 'page', 'Admin', 271, 'RecalculationLogs-List');

-- Rest365 (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(53, 'Admin.Rest365.List',     'List Rest365',   'Admin', 'Rest365', 'List',     'page',   'Admin', 281, 'Rest365-List'),
(54, 'Admin.Rest365.Create',   'Create Rest365',  'Admin', 'Rest365', 'Create',   'button', 'Admin.Rest365.List', 282, 'Rest365-Create'),
(55, 'Admin.Rest365.Update',   'Update Rest365',  'Admin', 'Rest365', 'Update',   'button', 'Admin.Rest365.List', 283, 'Rest365-Update'),
(56, 'Admin.Rest365.Inactive', 'Inactive',        'Admin', 'Rest365', 'Inactive', 'button', 'Admin.Rest365.List', 284, 'Rest365-Inactive');

-- Role (6)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(57, 'Admin.Role.List',            'List Roles',       'Admin', 'Role', 'List',            'page',   'Admin', 291, 'Roles-List'),
(58, 'Admin.Role.Create',          'Create Role',      'Admin', 'Role', 'Create',          'button', 'Admin.Role.List', 292, 'Roles-Create'),
(59, 'Admin.Role.Update',          'Update Role',      'Admin', 'Role', 'Update',          'button', 'Admin.Role.List', 293, 'Roles-Update'),
(60, 'Admin.Role.Delete',          'Delete Role',      'Admin', 'Role', 'Delete',          'button', 'Admin.Role.List', 294, 'Roles-Delete'),
(61, 'Admin.Role.PermissionSetup', 'Permission Setup', 'Admin', 'Role', 'PermissionSetup', 'button', 'Admin.Role.List', 295, 'Roles-GetControllers'),
(62, 'Admin.Role.SavePermission',  'Save Permission',  'Admin', 'Role', 'SavePermission',  'button', 'Admin.Role.List', 296, 'Roles-SavePermission');

-- SchedulerConfig (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(63, 'Admin.SchedulerConfig.List',   'List Scheduler Configs',   'Admin', 'SchedulerConfig', 'List',   'page',   'Admin', 301, 'SchedulerConfigs-List'),
(64, 'Admin.SchedulerConfig.Update', 'Update Scheduler Config',  'Admin', 'SchedulerConfig', 'Update', 'button', 'Admin.SchedulerConfig.List', 302, 'SchedulerConfigs-Update');

-- Term (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(65, 'Admin.Term.List',   'List Terms',   'Admin', 'Term', 'List',   'page',   'Admin', 311, 'Terms-List'),
(66, 'Admin.Term.Create', 'Create Term',  'Admin', 'Term', 'Create', 'button', 'Admin.Term.List', 312, 'Terms-Create'),
(67, 'Admin.Term.Update', 'Update Term',  'Admin', 'Term', 'Update', 'button', 'Admin.Term.List', 313, 'Terms-Update'),
(68, 'Admin.Term.Delete', 'Delete Term',  'Admin', 'Term', 'Delete', 'button', 'Admin.Term.List', 314, 'Terms-Delete');

-- Truck (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(69, 'Admin.Truck.List',   'List Trucks',   'Admin', 'Truck', 'List',   'page',   'Admin', 321, 'Trucks-List'),
(70, 'Admin.Truck.Create', 'Create Truck',  'Admin', 'Truck', 'Create', 'button', 'Admin.Truck.List', 322, 'Trucks-Create'),
(71, 'Admin.Truck.Update', 'Update Truck',  'Admin', 'Truck', 'Update', 'button', 'Admin.Truck.List', 323, 'Trucks-Update'),
(72, 'Admin.Truck.Delete', 'Delete Truck',  'Admin', 'Truck', 'Delete', 'button', 'Admin.Truck.List', 324, 'Trucks-Delete');

-- ============================================================
-- CUSTOMER MODULE (38 records)
-- ============================================================

-- AR (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(73, 'Customer.AR.List',          'List AR',        'Customer', 'AR', 'List',          'page',   'Customer', 301, 'AR-List'),
(74, 'Customer.AR.ChargePayment', 'Charge Payment', 'Customer', 'AR', 'ChargePayment', 'button', 'Customer.AR.List', 302, 'AR-ChargePayment');

-- CustomerPayment (5)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(75, 'Customer.CustomerPayment.List',         'List Customer Payments',          'Customer', 'CustomerPayment', 'List',         'page',   'Customer', 311, 'CustomerPayments-List'),
(76, 'Customer.CustomerPayment.Delete',       'Delete Payment',                  'Customer', 'CustomerPayment', 'Delete',       'button', 'Customer.CustomerPayment.List', 312, 'CustomerPayments-Delete'),
(77, 'Customer.CustomerPayment.Save',         'Create/Update Customer Payment',  'Customer', 'CustomerPayment', 'Save',         'button', 'Customer.CustomerPayment.List', 313, 'CustomerPayments-Save'),
(78, 'Customer.CustomerPayment.SaveReturn',   'Return Payment',                  'Customer', 'CustomerPayment', 'SaveReturn',   'button', 'Customer.CustomerPayment.List', 314, 'CustomerPayments-SaveReturn'),
(79, 'Customer.CustomerPayment.DeleteReturn', 'Delete Return Payment',           'Customer', 'CustomerPayment', 'DeleteReturn', 'button', 'Customer.CustomerPayment.List', 315, 'CustomerPayments-DeleteReturn');

-- Customer (7)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(80, 'Customer.Customer.List',            'List Customers',      'Customer', 'Customer', 'List',            'page',   'Customer', 321, 'Customers-List'),
(81, 'Customer.Customer.Create',          'Create Customer',     'Customer', 'Customer', 'Create',          'button', 'Customer.Customer.List', 322, 'Customers-Create'),
(82, 'Customer.Customer.Update',          'Update Customer',     'Customer', 'Customer', 'Update',          'button', 'Customer.Customer.List', 323, 'Customers-Update'),
(83, 'Customer.Customer.Delete',          'Delete Customer',     'Customer', 'Customer', 'Delete',          'button', 'Customer.Customer.List', 324, 'Customers-Delete'),
(84, 'Customer.Customer.OpenClose',       'Open/Close Customer', 'Customer', 'Customer', 'OpenClose',       'button', 'Customer.Customer.List', 325, 'Customers-OpenClose'),
(85, 'Customer.Customer.EmailPricesheet', 'Email Pricesheet',    'Customer', 'Customer', 'EmailPricesheet', 'button', 'Customer.Customer.List', 326, 'Customers-EmailPricesheet'),
(86, 'Customer.Customer.EmailStatement',  'Email Statement',     'Customer', 'Customer', 'EmailStatement',  'button', 'Customer.Customer.List', 327, 'Customers-EmailStatement');

-- Deposit (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(87, 'Customer.Deposit.List',   'List Deposits',          'Customer', 'Deposit', 'List',   'page',   'Customer', 331, 'Deposits-List'),
(88, 'Customer.Deposit.Save',   'Create/Update Deposit',  'Customer', 'Deposit', 'Save',   'button', 'Customer.Deposit.List', 332, 'Deposits-Save'),
(89, 'Customer.Deposit.Delete', 'Delete Deposit',         'Customer', 'Deposit', 'Delete', 'button', 'Customer.Deposit.List', 333, 'Deposits-Delete');

-- PaymentMethod (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(90, 'Customer.PaymentMethod.Create', 'Create Method', 'Customer', 'PaymentMethod', 'Create', 'button', 'Customer.Customer.List', 341, 'PaymentMethods-Create'),
(91, 'Customer.PaymentMethod.Delete', 'Delete Method', 'Customer', 'PaymentMethod', 'Delete', 'button', 'Customer.Customer.List', 342, 'PaymentMethods-Delete');

-- Sale (16)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(92,  'Customer.Sale.List',              'List Orders',         'Customer', 'Sale', 'List',              'page',   'Customer', 351, 'Sales-List'),
(93,  'Customer.Sale.UpdateRoute',       'Update Route',        'Customer', 'Sale', 'UpdateRoute',       'button', 'Customer.Sale.List', 352, 'Sales-UpdateRoute'),
(94,  'Customer.Sale.UpdateStage',       'Update Stage',        'Customer', 'Sale', 'UpdateStage',       'button', 'Customer.Sale.List', 353, 'Sales-UpdateStage'),
(95,  'Customer.Sale.UpdateInstruction', 'Update Instruction',  'Customer', 'Sale', 'UpdateInstruction', 'button', 'Customer.Sale.List', 354, 'Sales-UpdateInstruction'),
(96,  'Customer.Sale.UpdatePO',          'Update PO',           'Customer', 'Sale', 'UpdatePO',          'button', 'Customer.Sale.List', 355, 'Sales-UpdatePO'),
(97,  'Customer.Sale.UpdateLoadSeparate','Update Load Separate','Customer', 'Sale', 'UpdateLoadSeparate','button', 'Customer.Sale.List', 356, 'Sales-UpdateLoadSeparate'),
(98,  'Customer.Sale.UpdateCarrier',     'Update Carrier',      'Customer', 'Sale', 'UpdateCarrier',     'button', 'Customer.Sale.List', 357, 'Sales-UpdateCarrier'),
(99,  'Customer.Sale.Delete',            'Delete Order',        'Customer', 'Sale', 'Delete',            'button', 'Customer.Sale.List', 358, 'Sales-Delete'),
(100, 'Customer.Sale.SeePdf',            'See Pdf Image',       'Customer', 'Sale', 'SeePdf',            'button', 'Customer.Sale.List', 359, 'Sales-SeePdf'),
(101, 'Customer.Sale.EmailPdf',          'Email Pdf Image',     'Customer', 'Sale', 'EmailPdf',          'button', 'Customer.Sale.List', 360, 'Sales-EmailPdf'),
(102, 'Customer.Sale.Create',            'Create Order',        'Customer', 'Sale', 'Create',            'button', 'Customer.Sale.List', 361, 'Sales-Checkout'),
(103, 'Customer.Sale.Update',            'Update Order',        'Customer', 'Sale', 'Update',            'button', 'Customer.Sale.List', 362, 'Sales-UpdatePartially'),
(104, 'Customer.Sale.ShippingCharge',    'Add Shipping Charge', 'Customer', 'Sale', 'ShippingCharge',    'button', 'Customer.Sale.List', 363, 'Sales-ShippingCharge'),
(105, 'Customer.Sale.MergeOrder',        'Merge Order',         'Customer', 'Sale', 'MergeOrder',        'button', 'Customer.Sale.List', 364, 'Sales-MergeOrder'),
(106, 'Customer.Sale.MergePdf',          'Merge Pdf',           'Customer', 'Sale', 'MergePdf',          'button', 'Customer.Sale.List', 365, 'Sales-MergePdf'),
(107, 'Customer.Sale.SeePayment',        'See Payment',         'Customer', 'Sale', 'SeePayment',        'button', 'Customer.Sale.List', 366, 'Sales-SeePayment');

-- BombSale (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(108, 'Customer.BombSale.List',   'List Bomb',    'Customer', 'BombSale', 'List',   'page',   'Customer', 371, 'TempBombSales-List'),
(109, 'Customer.BombSale.Update', 'Update Detail','Customer', 'BombSale', 'Update', 'button', 'Customer.BombSale.List', 372, 'TempBombSales-Update'),
(110, 'Customer.BombSale.Save',   'Save Bomb',    'Customer', 'BombSale', 'Save',   'button', 'Customer.BombSale.List', 373, 'TempBombSales-SaveBomb');

-- ============================================================
-- EMPLOYEE MODULE (17 records)
-- ============================================================

-- EmpAdvance (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(111, 'Employee.EmpAdvance.List',   'List Advance Payments',          'Employee', 'EmpAdvance', 'List',   'page',   'Employee', 401, 'EmpAdvances-List'),
(112, 'Employee.EmpAdvance.Save',   'Create/Update Advance Payment',  'Employee', 'EmpAdvance', 'Save',   'button', 'Employee.EmpAdvance.List', 402, 'EmpAdvances-Save'),
(113, 'Employee.EmpAdvance.Delete', 'Delete Advance Payment',         'Employee', 'EmpAdvance', 'Delete', 'button', 'Employee.EmpAdvance.List', 403, 'EmpAdvances-Delete');

-- Employee (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(114, 'Employee.Employee.List',   'List Employees',   'Employee', 'Employee', 'List',   'page',   'Employee', 411, 'Employees-List'),
(115, 'Employee.Employee.Create', 'Create Employee',  'Employee', 'Employee', 'Create', 'button', 'Employee.Employee.List', 412, 'Employees-Create'),
(116, 'Employee.Employee.Update', 'Update Employee',  'Employee', 'Employee', 'Update', 'button', 'Employee.Employee.List', 413, 'Employees-Update'),
(117, 'Employee.Employee.Delete', 'Delete Employee',  'Employee', 'Employee', 'Delete', 'button', 'Employee.Employee.List', 414, 'Employees-Delete');

-- PayrollService (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(118, 'Employee.PayrollService.List',   'List Payroll Service',          'Employee', 'PayrollService', 'List',   'page',   'Employee', 421, 'PayrollServices-List'),
(119, 'Employee.PayrollService.Save',   'Create/Update Payroll Service', 'Employee', 'PayrollService', 'Save',   'button', 'Employee.PayrollService.List', 422, 'PayrollServices-Save'),
(120, 'Employee.PayrollService.Delete', 'Delete Payroll Service',        'Employee', 'PayrollService', 'Delete', 'button', 'Employee.PayrollService.List', 423, 'PayrollServices-Delete');

-- Payroll (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(121, 'Employee.Payroll.List',   'List Payrolls',          'Employee', 'Payroll', 'List',   'page',   'Employee', 431, 'Payrolls-List'),
(122, 'Employee.Payroll.Save',   'Create/Update Payroll',  'Employee', 'Payroll', 'Save',   'button', 'Employee.Payroll.List', 432, 'Payrolls-Save'),
(123, 'Employee.Payroll.Delete', 'Delete Payroll',         'Employee', 'Payroll', 'Delete', 'button', 'Employee.Payroll.List', 433, 'Payrolls-Delete'),
(124, 'Employee.Payroll.Import', 'Import Payroll',         'Employee', 'Payroll', 'Import', 'button', 'Employee.Payroll.List', 434, 'Payrolls-Import');

-- Timesheet (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(125, 'Employee.Timesheet.List',   'List Timesheets',          'Employee', 'Timesheet', 'List',   'page',   'Employee', 441, 'Timesheets-List'),
(126, 'Employee.Timesheet.Save',   'Create/Update Timesheet',  'Employee', 'Timesheet', 'Save',   'button', 'Employee.Timesheet.List', 442, 'Timesheets-Save'),
(127, 'Employee.Timesheet.Delete', 'Delete Timesheet',         'Employee', 'Timesheet', 'Delete', 'button', 'Employee.Timesheet.List', 443, 'Timesheets-Delete');

-- ============================================================
-- PRODUCT MODULE (30 records)
-- ============================================================

-- InventoryAdj (5)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(128, 'Product.InventoryAdj.List',         'List Adjustments',          'Product', 'InventoryAdj', 'List',         'page',   'Product', 501, 'InventoryAdjs-List'),
(129, 'Product.InventoryAdj.Save',         'Create/Update Adjustment',  'Product', 'InventoryAdj', 'Save',         'button', 'Product.InventoryAdj.List', 502, 'InventoryAdjs-Save'),
(130, 'Product.InventoryAdj.Delete',       'Delete Adjustment',         'Product', 'InventoryAdj', 'Delete',       'button', 'Product.InventoryAdj.List', 503, 'InventoryAdjs-Delete'),
(131, 'Product.InventoryAdj.DeleteDetail', 'Delete Detail',             'Product', 'InventoryAdj', 'DeleteDetail', 'button', 'Product.InventoryAdj.List', 504, 'InventoryAdjs-DeleteDetail'),
(132, 'Product.InventoryAdj.QtyAdj',       'Qty Adjustment',            'Product', 'InventoryAdj', 'QtyAdj',       'button', 'Product.InventoryAdj.List', 505, 'InventoryAdjs-QtyAdj');

-- ItemCategory (5)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(133, 'Product.ItemCategory.List',    'List Categories',    'Product', 'ItemCategory', 'List',    'page',   'Product', 511, 'ItemCategories-List'),
(134, 'Product.ItemCategory.Create',  'Create Category',    'Product', 'ItemCategory', 'Create',  'button', 'Product.ItemCategory.List', 512, 'ItemCategories-Create'),
(135, 'Product.ItemCategory.Update',  'Update Category',    'Product', 'ItemCategory', 'Update',  'button', 'Product.ItemCategory.List', 513, 'ItemCategories-Update'),
(136, 'Product.ItemCategory.Delete',  'Delete Category',    'Product', 'ItemCategory', 'Delete',  'button', 'Product.ItemCategory.List', 514, 'ItemCategories-Delete'),
(137, 'Product.ItemCategory.Reorder', 'Reorder Category',   'Product', 'ItemCategory', 'Reorder', 'button', 'Product.ItemCategory.List', 515, 'ItemCategories-ReorderNode');

-- ItemHistory (5)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(138, 'Product.ItemHistory.Sales',      'View Order History',          'Product', 'ItemHistory', 'Sales',      'page',   'Product', 521, 'ItemHistories-Sales'),
(139, 'Product.ItemHistory.Purchase',   'View Cost History',           'Product', 'ItemHistory', 'Purchase',   'button', 'Product.ItemHistory.Sales', 522, 'ItemHistories-Purchase'),
(140, 'Product.ItemHistory.Inventory',  'View Inventory History',      'Product', 'ItemHistory', 'Inventory',  'button', 'Product.ItemHistory.Sales', 523, 'ItemHistories-Inventory'),
(141, 'Product.ItemHistory.SalesCost',  'View Cost + Order History',   'Product', 'ItemHistory', 'SalesCost',  'button', 'Product.ItemHistory.Sales', 524, 'ItemHistories-SalesCost'),
(142, 'Product.ItemHistory.Adjustment', 'View Adjustment History',     'Product', 'ItemHistory', 'Adjustment', 'button', 'Product.ItemHistory.Sales', 525, 'ItemHistories-Adjustment');

-- ItemImage (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(143, 'Product.ItemImage.List',   'List Images',   'Product', 'ItemImage', 'List',   'page',   'Product', 531, 'ItemImages-List'),
(144, 'Product.ItemImage.Upload', 'Upload Image',  'Product', 'ItemImage', 'Upload', 'button', 'Product.ItemImage.List', 532, 'ItemImages-Upload'),
(145, 'Product.ItemImage.Delete', 'Delete Image',  'Product', 'ItemImage', 'Delete', 'button', 'Product.ItemImage.List', 533, 'ItemImages-Delete');

-- ItemStorage (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(146, 'Product.ItemStorage.List',   'List Storages',   'Product', 'ItemStorage', 'List',   'page',   'Product', 541, 'ItemStorages-List'),
(147, 'Product.ItemStorage.Create', 'Create Storage',  'Product', 'ItemStorage', 'Create', 'button', 'Product.ItemStorage.List', 542, 'ItemStorages-Create'),
(148, 'Product.ItemStorage.Update', 'Update Storage',  'Product', 'ItemStorage', 'Update', 'button', 'Product.ItemStorage.List', 543, 'ItemStorages-Update'),
(149, 'Product.ItemStorage.Delete', 'Delete Storage',  'Product', 'ItemStorage', 'Delete', 'button', 'Product.ItemStorage.List', 544, 'ItemStorages-Delete');

-- Item (8)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(150, 'Product.Item.List',                    'List Products',           'Product', 'Item', 'List',                    'page',   'Product', 551, 'Items-List'),
(151, 'Product.Item.Delete',                  'Delete Product',          'Product', 'Item', 'Delete',                  'button', 'Product.Item.List', 552, 'Items-Delete'),
(152, 'Product.Item.Save',                    'Create/Update Product',   'Product', 'Item', 'Save',                    'button', 'Product.Item.List', 553, 'Items-Save'),
(153, 'Product.Item.UpdateBaseP1',            'Edit P1',                 'Product', 'Item', 'UpdateBaseP1',            'button', 'Product.Item.List', 554, 'Items-UpdateBaseP1'),
(154, 'Product.Item.UpdateInventorySettings', 'Edit Inventory Settings', 'Product', 'Item', 'UpdateInventorySettings', 'button', 'Product.Item.List', 555, 'Items-UpdateInventorySettings'),
(155, 'Product.Item.UpdateItemUnit',          'Edit Item Unit',          'Product', 'Item', 'UpdateItemUnit',          'button', 'Product.Item.List', 556, 'Items-UpdateItemUnit'),
(156, 'Product.Item.CreateItemUnit',          'Create Item Unit',        'Product', 'Item', 'CreateItemUnit',          'button', 'Product.Item.List', 557, 'Items-CreateItemUnit'),
(157, 'Product.Item.DeleteItemUnit',          'Delete Item Unit',        'Product', 'Item', 'DeleteItemUnit',          'button', 'Product.Item.List', 558, 'Items-DeleteItemUnit');

-- ============================================================
-- REPORT MODULE (41 records)
-- ============================================================

-- PL Reports (4)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(158, 'Report.PL.BalanceSheet',  'Balance Sheet',   'Report', 'PL', 'BalanceSheet',  'page', 'Report', 601, 'Reports-BalanceSheet'),
(159, 'Report.PL.ProfitLoss',   'Profit Loss',     'Report', 'PL', 'ProfitLoss',   'page', 'Report', 602, 'Reports-ProfitLoss'),
(160, 'Report.PL.Ledger',       'Ledger',          'Report', 'PL', 'Ledger',       'page', 'Report', 603, 'Reports-Ledger'),
(161, 'Report.PL.LedgerByPayee','Ledger By Payee', 'Report', 'PL', 'LedgerByPayee','page', 'Report', 604, 'Reports-LedgerByPayee');

-- Sales Reports (11)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(162, 'Report.Sales.SalesDaily',       'Sales Daily',       'Report', 'Sales', 'SalesDaily',       'page', 'Report', 611, 'Reports-SalesDaily'),
(163, 'Report.Sales.SalesTax',         'Sales Tax',         'Report', 'Sales', 'SalesTax',         'page', 'Report', 612, 'Reports-SalesTax'),
(164, 'Report.Sales.Responsible',      'Responsible',       'Report', 'Sales', 'Responsible',      'page', 'Report', 613, 'Reports-Responsible'),
(165, 'Report.Sales.DailySummary',     'Daily Summary',     'Report', 'Sales', 'DailySummary',     'page', 'Report', 614, 'Reports-DailySummary'),
(166, 'Report.Sales.CreditMemo',       'Credit Memo',       'Report', 'Sales', 'CreditMemo',       'page', 'Report', 615, 'Reports-CreditMemo'),
(167, 'Report.Sales.SalesByItem',      'Sales By Item',     'Report', 'Sales', 'SalesByItem',      'page', 'Report', 616, 'Reports-SalesByItem'),
(168, 'Report.Sales.SalesDetail',      'Sales Detail',      'Report', 'Sales', 'SalesDetail',      'page', 'Report', 617, 'Reports-SalesDetail'),
(169, 'Report.Sales.SalesDaily2',      'Sales Daily 2',     'Report', 'Sales', 'SalesDaily2',      'page', 'Report', 618, 'Reports-SalesDaily2'),
(254, 'Report.Sales.SalesByInvoice',   'Sales By Invoice',  'Report', 'Sales', 'SalesByInvoice',   'page', 'Report', 622, 'Reports-SalesByInvoice'),
(170, 'Report.Sales.SalesYearly',      'Sales Yearly',      'Report', 'Sales', 'SalesYearly',      'page', 'Report', 619, 'Reports-SalesYearly'),
(171, 'Report.Sales.SalesCommission',  'Sales Commission',  'Report', 'Sales', 'SalesCommission',  'page', 'Report', 620, 'Reports-SalesCommission'),
(172, 'Report.Sales.SalesCommission2', 'Sales Commission 2','Report', 'Sales', 'SalesCommission2', 'page', 'Report', 621, 'Reports-SalesCommission2');

-- Customer Reports (10)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(173, 'Report.Customer.DescDollar',      'Descending Dollar',    'Report', 'Customer', 'DescDollar',      'page', 'Report', 631, 'Reports-DescDollar'),
(174, 'Report.Customer.PaymentHistory',  'Payment History',      'Report', 'Customer', 'PaymentHistory',  'page', 'Report', 632, 'Reports-PaymentHistory'),
(175, 'Report.Customer.Statement',       'Statement',            'Report', 'Customer', 'Statement',       'page', 'Report', 633, 'Reports-CustStmt'),
(176, 'Report.Customer.AccountHistory',  'Account History',      'Report', 'Customer', 'AccountHistory',  'page', 'Report', 634, 'Reports-AccountHistory'),
(177, 'Report.Customer.Pricesheet',      'Pricesheet',           'Report', 'Customer', 'Pricesheet',      'page', 'Report', 635, 'Reports-Pricesheet'),
(178, 'Report.Customer.OrderGuide',      'Order Guide',          'Report', 'Customer', 'OrderGuide',      'page', 'Report', 636, 'Reports-OrderGuide'),
(179, 'Report.Customer.ItemVolume',      'Item Volume History',  'Report', 'Customer', 'ItemVolume',      'page', 'Report', 637, 'Reports-CustItemVolume'),
(180, 'Report.Customer.SalesByItem',     'Sales By Item',        'Report', 'Customer', 'SalesByItem',     'page', 'Report', 638, 'Reports-CustSalesByItem'),
(181, 'Report.Customer.SalesHistory',    'Sales History',        'Report', 'Customer', 'SalesHistory',    'page', 'Report', 639, 'Reports-SalesHistory'),
(182, 'Report.Customer.CustPayment',     'Customer Payment',     'Report', 'Customer', 'CustPayment',     'page', 'Report', 640, 'Reports-CustPayment');

-- Banking Reports (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(183, 'Report.Banking.BankRecon',   'Bank Reconciliation', 'Report', 'Banking', 'BankRecon',   'page', 'Report', 651, 'Reports-BankRecon'),
(184, 'Report.Banking.PmtReceipt',  'Payment Receipt',     'Report', 'Banking', 'PmtReceipt',  'page', 'Report', 652, 'Reports-PmtReceipt');

-- AP Reports (3)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(185, 'Report.AP.APCheck',          'AP Check',          'Report', 'AP', 'APCheck',          'page', 'Report', 661, 'Reports-APCheck'),
(186, 'Report.AP.CheckToBePrinted', 'Check To Be Printed','Report', 'AP', 'CheckToBePrinted', 'page', 'Report', 662, 'Reports-CheckToBePrinted'),
(187, 'Report.AP.APInvoice',        'AP From Invoice',   'Report', 'AP', 'APInvoice',        'page', 'Report', 663, 'Reports-APInvoice');

-- AR Reports (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(188, 'Report.AR.ARInvoice', 'AR From Invoice', 'Report', 'AR', 'ARInvoice', 'page', 'Report', 671, 'Reports-ARInvoice'),
(189, 'Report.AR.ARMonth',   'AR Month',        'Report', 'AR', 'ARMonth',   'page', 'Report', 672, 'Reports-ARMonth');

-- Timesheet Reports (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(190, 'Report.Timesheet.Timesheet',  'Timesheet',   'Report', 'Timesheet', 'Timesheet',  'page', 'Report', 681, 'Reports-Timesheet'),
(191, 'Report.Timesheet.JobSummary', 'Job Summary', 'Report', 'Timesheet', 'JobSummary', 'page', 'Report', 682, 'Reports-JobSummary');

-- Payroll Reports (2)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(192, 'Report.Payroll.Payroll',        'Payroll',              'Report', 'Payroll', 'Payroll',        'page', 'Report', 691, 'Reports-Payroll'),
(193, 'Report.Payroll.EmpLoanLedger',  'Employee Loan Ledger', 'Report', 'Payroll', 'EmpLoanLedger',  'page', 'Report', 692, 'Reports-EmpLoanLedger');

-- Inventory Reports (5)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(194, 'Report.Inventory.InventoryStatus',    'Inventory Status',    'Report', 'Inventory', 'InventoryStatus',    'page', 'Report', 701, 'Reports-InventoryStatus'),
(195, 'Report.Inventory.Reorder',            'Reorder',             'Report', 'Inventory', 'Reorder',            'page', 'Report', 702, 'Reports-Reorder'),
(196, 'Report.Inventory.InventoryValuation', 'Inventory Valuation', 'Report', 'Inventory', 'InventoryValuation', 'page', 'Report', 703, 'Reports-InventoryValuation'),
(197, 'Report.Inventory.InventoryMovement',  'Inventory Movement',  'Report', 'Inventory', 'InventoryMovement',  'page', 'Report', 704, 'Reports-InventoryMovement'),
(198, 'Report.Inventory.InventoryIncoming',  'Incoming Purchases',  'Report', 'Inventory', 'InventoryIncoming',  'page', 'Report', 705, 'Reports-InventoryIncoming');

-- ============================================================
-- VENDOR MODULE (55 records)
-- ============================================================

-- Liability (11)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(199, 'Vendor.Liability.LoanList',         'Loan Manager',        'Vendor', 'Liability', 'LoanList',         'page',   'Vendor', 701, 'Liabilities-LoanList'),
(200, 'Vendor.Liability.TaxList',          'Tax Manager',         'Vendor', 'Liability', 'TaxList',          'page',   'Vendor', 702, 'Liabilities-TaxList'),
(201, 'Vendor.Liability.CCList',           'CC Manager',          'Vendor', 'Liability', 'CCList',           'page',   'Vendor', 703, 'Liabilities-CCList'),
(202, 'Vendor.Liability.Create',           'Create Liability',    'Vendor', 'Liability', 'Create',           'button', 'Vendor.Liability.LoanList', 704, 'Liabilities-Create'),
(203, 'Vendor.Liability.Update',           'Update Liability',    'Vendor', 'Liability', 'Update',           'button', 'Vendor.Liability.LoanList', 705, 'Liabilities-Update'),
(204, 'Vendor.Liability.Delete',           'Delete Liability',    'Vendor', 'Liability', 'Delete',           'button', 'Vendor.Liability.LoanList', 706, 'Liabilities-Delete'),
(205, 'Vendor.Liability.DeletePayment',    'Delete Payment',      'Vendor', 'Liability', 'DeletePayment',    'button', 'Vendor.Liability.LoanList', 707, 'Liabilities-DeletePayment'),
(206, 'Vendor.Liability.TxList',           'Tx List',             'Vendor', 'Liability', 'TxList',           'button', 'Vendor.Liability.LoanList', 708, 'Liabilities-TxList'),
(207, 'Vendor.Liability.SaveLoanPayment',  'Save Loan Payment',   'Vendor', 'Liability', 'SaveLoanPayment',  'button', 'Vendor.Liability.LoanList', 709, 'Liabilities-SaveLoanPayment'),
(208, 'Vendor.Liability.SaveCCPayment',    'Save CC Payment',     'Vendor', 'Liability', 'SaveCCPayment',    'button', 'Vendor.Liability.CCList', 710, 'Liabilities-SaveCCPayment'),
(209, 'Vendor.Liability.ImportTaxPayment', 'Import Tax Payment',  'Vendor', 'Liability', 'ImportTaxPayment', 'button', 'Vendor.Liability.TaxList', 711, 'Liabilities-ImportTaxPayment');

-- PurchaseOrder (9)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(210, 'Vendor.PurchaseOrder.List',          'List PO',              'Vendor', 'PurchaseOrder', 'List',          'page',   'Vendor', 721, 'PurchaseOrders-List'),
(211, 'Vendor.PurchaseOrder.Create',        'Create/Update PO',    'Vendor', 'PurchaseOrder', 'Create',        'button', 'Vendor.PurchaseOrder.List', 722, 'PurchaseOrders-Checkout'),
(212, 'Vendor.PurchaseOrder.Delete',        'Delete PO',           'Vendor', 'PurchaseOrder', 'Delete',        'button', 'Vendor.PurchaseOrder.List', 723, 'PurchaseOrders-Delete'),
(213, 'Vendor.PurchaseOrder.CopyToBill',    'Receive Product',     'Vendor', 'PurchaseOrder', 'CopyToBill',    'button', 'Vendor.PurchaseOrder.List', 724, 'PurchaseOrders-CopyToBill'),
(214, 'Vendor.PurchaseOrder.Print',         'Print PO',            'Vendor', 'PurchaseOrder', 'Print',         'button', 'Vendor.PurchaseOrder.List', 725, 'PurchaseOrders-PrintPO'),
(215, 'Vendor.PurchaseOrder.ConvertToBill', 'Convert To Bill',     'Vendor', 'PurchaseOrder', 'ConvertToBill', 'button', 'Vendor.PurchaseOrder.List', 726, 'PurchaseOrders-UpdateToBillStage'),
(216, 'Vendor.PurchaseOrder.SaveAdvance',   'Save Advance Payment','Vendor', 'PurchaseOrder', 'SaveAdvance',   'button', 'Vendor.PurchaseOrder.List', 727, 'PurchaseOrders-SaveAdvance'),
(217, 'Vendor.PurchaseOrder.GetAdvances',   'Advance Payments',    'Vendor', 'PurchaseOrder', 'GetAdvances',   'button', 'Vendor.PurchaseOrder.List', 728, 'PurchaseOrders-GetAdvances'),
(218, 'Vendor.PurchaseOrder.DeleteAdvance', 'Delete Advance Payment','Vendor', 'PurchaseOrder', 'DeleteAdvance','button', 'Vendor.PurchaseOrder.List', 729, 'PurchaseOrders-DeleteAdvance');

-- Purchase (12)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(219, 'Vendor.Purchase.List',              'List Bills',           'Vendor', 'Purchase', 'List',              'page',   'Vendor', 741, 'Purchases-List'),
(220, 'Vendor.Purchase.UpdateDocNumber',   'Update Doc Number',    'Vendor', 'Purchase', 'UpdateDocNumber',   'button', 'Vendor.Purchase.List', 742, 'Purchases-UpdateDocNumber'),
(221, 'Vendor.Purchase.UpdateInvoiceDate', 'Update Invoice Date',  'Vendor', 'Purchase', 'UpdateInvoiceDate', 'button', 'Vendor.Purchase.List', 743, 'Purchases-UpdateInvoiceDate'),
(222, 'Vendor.Purchase.UpdateCommission',  'Update Commission',    'Vendor', 'Purchase', 'UpdateCommission',  'button', 'Vendor.Purchase.List', 744, 'Purchases-UpdateCommission'),
(223, 'Vendor.Purchase.UpdatePallet',      'Update Pallet',        'Vendor', 'Purchase', 'UpdatePallet',      'button', 'Vendor.Purchase.List', 745, 'Purchases-UpdatePallet'),
(224, 'Vendor.Purchase.UpdateContainer',   'Update Container',     'Vendor', 'Purchase', 'UpdateContainer',   'button', 'Vendor.Purchase.List', 746, 'Purchases-UpdateContainer'),
(225, 'Vendor.Purchase.Create',            'Create Bill',          'Vendor', 'Purchase', 'Create',            'button', 'Vendor.Purchase.List', 747, 'Purchases-Checkout'),
(226, 'Vendor.Purchase.Update',            'Update Bill',          'Vendor', 'Purchase', 'Update',            'button', 'Vendor.Purchase.List', 748, 'Purchases-UpdatePartially'),
(227, 'Vendor.Purchase.Delete',            'Delete Bill',          'Vendor', 'Purchase', 'Delete',            'button', 'Vendor.Purchase.List', 749, 'Purchases-Delete'),
(228, 'Vendor.Purchase.UploadBillPDF',     'Upload Bill Pdf',      'Vendor', 'Purchase', 'UploadBillPDF',     'button', 'Vendor.Purchase.List', 750, 'Purchases-UploadBillPDF'),
(229, 'Vendor.Purchase.SeePdf',            'See PDF Image',        'Vendor', 'Purchase', 'SeePdf',            'button', 'Vendor.Purchase.List', 751, 'Purchases-SeePdf'),
(230, 'Vendor.Purchase.AssignShipment',    'Assign Shipment',      'Vendor', 'Purchase', 'AssignShipment',    'button', 'Vendor.Purchase.List', 752, 'Purchases-AssignShipment');

-- Shipment (7)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(231, 'Vendor.Shipment.List',         'List Shipments',        'Vendor', 'Shipment', 'List',         'page',   'Vendor', 761, 'Shipments-List'),
(232, 'Vendor.Shipment.Create',       'Create Shipment',       'Vendor', 'Shipment', 'Create',       'button', 'Vendor.Shipment.List', 762, 'Shipments-Create'),
(233, 'Vendor.Shipment.Update',       'Update Shipment',       'Vendor', 'Shipment', 'Update',       'button', 'Vendor.Shipment.List', 763, 'Shipments-Update'),
(234, 'Vendor.Shipment.Delete',       'Delete Shipment',       'Vendor', 'Shipment', 'Delete',       'button', 'Vendor.Shipment.List', 764, 'Shipments-Delete'),
(235, 'Vendor.Shipment.Reopen',       'Reopen Shipment',       'Vendor', 'Shipment', 'Reopen',       'button', 'Vendor.Shipment.List', 765, 'Shipments-Reopen'),
(236, 'Vendor.Shipment.GenerateBill', 'Generate Bill',         'Vendor', 'Shipment', 'GenerateBill', 'button', 'Vendor.Shipment.List', 766, 'Shipments-GenerateBill'),
(237, 'Vendor.Shipment.UnAllocation', 'UnAllocation Shipment', 'Vendor', 'Shipment', 'UnAllocation', 'button', 'Vendor.Shipment.List', 767, 'Shipments-UnAllocation');

-- VendorPayment (11)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(238, 'Vendor.VendorPayment.List',           'List Vendor Payments',              'Vendor', 'VendorPayment', 'List',           'page',   'Vendor', 781, 'VendorPayments-List'),
(239, 'Vendor.VendorPayment.Save',           'Create/Update Vendor Payment',      'Vendor', 'VendorPayment', 'Save',           'button', 'Vendor.VendorPayment.List', 782, 'VendorPayments-Save'),
(240, 'Vendor.VendorPayment.Delete',         'Delete Vendor Payment',             'Vendor', 'VendorPayment', 'Delete',         'button', 'Vendor.VendorPayment.List', 783, 'VendorPayments-Delete'),
(241, 'Vendor.VendorPayment.VoidCheck',      'Void Check',                        'Vendor', 'VendorPayment', 'VoidCheck',      'button', 'Vendor.VendorPayment.List', 784, 'VendorPayments-VoidCheck'),
(242, 'Vendor.VendorPayment.UnVoidCheck',    'UnVoid Check',                      'Vendor', 'VendorPayment', 'UnVoidCheck',    'button', 'Vendor.VendorPayment.List', 785, 'VendorPayments-UnVoidCheck'),
(243, 'Vendor.VendorPayment.Return',         'Create Return Vendor Payment',      'Vendor', 'VendorPayment', 'Return',         'button', 'Vendor.VendorPayment.List', 786, 'VendorPayments-Return'),
(244, 'Vendor.VendorPayment.DeleteReturn',   'Delete Return Vendor Payment',      'Vendor', 'VendorPayment', 'DeleteReturn',   'button', 'Vendor.VendorPayment.List', 787, 'VendorPayments-DeleteReturn'),
(245, 'Vendor.VendorPayment.SavePayNow',     'Create/Update Pay NOW',             'Vendor', 'VendorPayment', 'SavePayNow',     'button', 'Vendor.VendorPayment.List', 788, 'VendorPayments-SavePayNow'),
(246, 'Vendor.VendorPayment.ImportPayNow',   'Import Pay NOW',                    'Vendor', 'VendorPayment', 'ImportPayNow',   'button', 'Vendor.VendorPayment.List', 789, 'VendorPayments-ImportPayNow'),
(247, 'Vendor.VendorPayment.ApplyAdvance',   'Apply Advance Payment',             'Vendor', 'VendorPayment', 'ApplyAdvance',   'button', 'Vendor.VendorPayment.List', 790, 'VendorPayments-ApplyAdvance'),
(248, 'Vendor.VendorPayment.UnapplyAdvance', 'Unapply Advance Payment',           'Vendor', 'VendorPayment', 'UnapplyAdvance', 'button', 'Vendor.VendorPayment.List', 791, 'VendorPayments-UnapplyAdvance');

-- Vendor (5)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentKey, SortOrder, OldKey)
VALUES
(249, 'Vendor.Vendor.List',      'List Vendors',      'Vendor', 'Vendor', 'List',      'page',   'Vendor', 801, 'Vendors-List'),
(250, 'Vendor.Vendor.Create',    'Create Vendor',     'Vendor', 'Vendor', 'Create',    'button', 'Vendor.Vendor.List', 802, 'Vendors-Create'),
(251, 'Vendor.Vendor.Update',    'Update Vendor',     'Vendor', 'Vendor', 'Update',    'button', 'Vendor.Vendor.List', 803, 'Vendors-Update'),
(252, 'Vendor.Vendor.Delete',    'Delete Vendor',     'Vendor', 'Vendor', 'Delete',    'button', 'Vendor.Vendor.List', 804, 'Vendors-Delete'),
(253, 'Vendor.Vendor.OpenClose', 'Open/Close Vendor', 'Vendor', 'Vendor', 'OpenClose', 'button', 'Vendor.Vendor.List', 805, 'Vendors-OpenClose');

SET IDENTITY_INSERT Permission OFF;

-- ============================================================
-- VERIFY
-- ============================================================
SELECT
    [Module],
    PermissionType,
    COUNT(*) AS Cnt
FROM Permission
GROUP BY [Module], PermissionType
ORDER BY [Module], PermissionType;

SELECT COUNT(*) AS TotalPermissions FROM Permission;
