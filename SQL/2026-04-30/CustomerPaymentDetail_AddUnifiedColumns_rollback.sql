SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_CustomerPaymentDetail_DetailRole'
      AND parent_object_id = OBJECT_ID('dbo.CustomerPaymentDetail')
)
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    DROP CONSTRAINT CK_CustomerPaymentDetail_DetailRole;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'SourceSalesId') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    DROP COLUMN SourceSalesId;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'SourceCustomerPaymentId') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    DROP COLUMN SourceCustomerPaymentId;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'DetailRole') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    DROP COLUMN DetailRole;
END
GO
