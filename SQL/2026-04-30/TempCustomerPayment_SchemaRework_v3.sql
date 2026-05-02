-- Phase A foundation only:
-- 1. Add new temp-cart columns needed by v3
-- 2. Keep legacy columns for compatibility with the current save path
-- 3. Do NOT drop AmountDue / IsApplied / IsCreditMemo / IsCCFee in this phase

ALTER TABLE dbo.TempCustomerPayment ADD
    SourceType            NVARCHAR(20) NULL,
    SourceId              INT NULL,
    IsSelected            BIT NOT NULL CONSTRAINT DF_TempCustomerPayment_IsSelected DEFAULT 0,
    DocNumber             NVARCHAR(30) NULL,
    DocDate               DATE NULL,
    Description           NVARCHAR(200) NULL,
    BillName              NVARCHAR(200) NULL,
    OriginalAmount        DECIMAL(18,2) NULL CONSTRAINT DF_TempCustomerPayment_OriginalAmount DEFAULT 0,
    OpenBalanceBefore     DECIMAL(18,2) NULL CONSTRAINT DF_TempCustomerPayment_OpenBalanceBefore DEFAULT 0,
    TermName              NVARCHAR(50) NULL,
    DiscountPercent       DECIMAL(18,4) NULL CONSTRAINT DF_TempCustomerPayment_DiscountPercent DEFAULT 0,
    DiscountAlreadyTaken  DECIMAL(18,2) NULL CONSTRAINT DF_TempCustomerPayment_DiscountAlreadyTaken DEFAULT 0,
    DiscountDate          DATE NULL,
    DueDays               INT NULL CONSTRAINT DF_TempCustomerPayment_DueDays DEFAULT 0;
GO

UPDATE dbo.TempCustomerPayment
SET
    SourceType = CASE
        WHEN IsCCFee = 1 THEN 'CCFee'
        WHEN IsCreditMemo = 1 THEN 'CreditMemo'
        ELSE 'Invoice'
    END,
    SourceId = SalesId,
    IsSelected = ISNULL(IsApplied, 0),
    DocNumber = CAST(SalesId AS NVARCHAR(30)),
    OriginalAmount = ISNULL(AmountDue, 0),
    OpenBalanceBefore = ISNULL(AmountDue, 0),
    DiscountPercent = ISNULL(DiscountPercent, 0),
    DiscountAlreadyTaken = ISNULL(DiscountAlreadyTaken, 0),
    DueDays = ISNULL(DueDays, 0)
WHERE SourceType IS NULL;
