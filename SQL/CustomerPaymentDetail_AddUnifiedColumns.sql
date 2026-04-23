SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'DetailRole') IS NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    ADD DetailRole NVARCHAR(30) NULL;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'SourceCustomerPaymentId') IS NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    ADD SourceCustomerPaymentId INT NULL;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'SourceSalesId') IS NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    ADD SourceSalesId INT NULL;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_CustomerPaymentDetail_DetailRole'
      AND parent_object_id = OBJECT_ID('dbo.CustomerPaymentDetail')
)
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    ADD CONSTRAINT CK_CustomerPaymentDetail_DetailRole
    CHECK (
        DetailRole IS NULL OR DetailRole IN (
            'Invoice',
            'DebitMemo',
            'CreditMemo',
            'UnappliedSource',
            'AsIncome',
            'AsRefund',
            'CCFee'
        )
    );
END
GO
