IF OBJECT_ID('dbo.CustomerPaymentSourceUse', 'U') IS NOT NULL
    DROP TABLE dbo.CustomerPaymentSourceUse;
GO

CREATE TABLE dbo.CustomerPaymentSourceUse
(
    CustomerPaymentSourceUseId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerPaymentId INT NOT NULL,
    SourcePaymentNumber INT NOT NULL,
    UseType NVARCHAR(20) NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    CreatedAt DATETIME NOT NULL CONSTRAINT DF_CustomerPaymentSourceUse_CreatedAt DEFAULT GETUTCDATE(),
    CONSTRAINT CK_SourceUse_UseType CHECK (UseType IN ('AsIncome', 'Refund', 'WriteOff', 'Adjustment'))
);
GO
