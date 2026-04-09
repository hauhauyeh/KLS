-- Rollback Phase A temp-cart additions only.
-- Legacy columns remain untouched.

ALTER TABLE dbo.TempCustomerPayment DROP CONSTRAINT DF_TempCustomerPayment_IsSelected;
ALTER TABLE dbo.TempCustomerPayment DROP CONSTRAINT DF_TempCustomerPayment_OriginalAmount;
ALTER TABLE dbo.TempCustomerPayment DROP CONSTRAINT DF_TempCustomerPayment_OpenBalanceBefore;
ALTER TABLE dbo.TempCustomerPayment DROP CONSTRAINT DF_TempCustomerPayment_DiscountPercent;
ALTER TABLE dbo.TempCustomerPayment DROP CONSTRAINT DF_TempCustomerPayment_DiscountAlreadyTaken;
ALTER TABLE dbo.TempCustomerPayment DROP CONSTRAINT DF_TempCustomerPayment_DueDays;

ALTER TABLE dbo.TempCustomerPayment DROP COLUMN
    SourceType,
    SourceId,
    IsSelected,
    DocNumber,
    DocDate,
    Description,
    BillName,
    OriginalAmount,
    OpenBalanceBefore,
    TermName,
    DiscountPercent,
    DiscountAlreadyTaken,
    DiscountDate,
    DueDays;
