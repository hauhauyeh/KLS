SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH('dbo.TempExtraPayment', 'AsRefund') IS NULL
BEGIN
    ALTER TABLE dbo.TempExtraPayment
    ADD AsRefund BIT NOT NULL
        CONSTRAINT DF_TempExtraPayment_AsRefund DEFAULT (0);
END
GO
