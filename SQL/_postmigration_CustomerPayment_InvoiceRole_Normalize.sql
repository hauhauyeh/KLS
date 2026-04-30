SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[_postmigration_CustomerPayment_InvoiceRole_Normalize]
AS
BEGIN
    SET NOCOUNT ON;

    -- One-time post-migration legacy normalization.
    --
    -- Purpose:
    --   Legacy applied customer-payment rows can exist with:
    --     - SalesId populated
    --     - DetailRole = NULL
    --   Modern header recalculation only counts typed invoice/debit-memo rows,
    --   so those legacy rows can make fully applied payments look like available credit.
    --
    -- Scope:
    --   Only normalize clear legacy invoice-application rows.
    --   Keep the filter narrow so we do not guess on credit-memo, refund, source-use,
    --   or fee rows.

    DECLARE @LegacyRowCount INT;

    SELECT @LegacyRowCount = COUNT(*)
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.SalesId IS NOT NULL
      AND pd.DetailRole IS NULL
      AND ISNULL(pd.IsCreditMemo, 0) = 0
      AND ISNULL(pd.IsCCFee, 0) = 0
      AND pd.SourceCustomerPaymentId IS NULL
      AND pd.SourceSalesId IS NULL
      AND pd.RefundPaymentId IS NULL;

    PRINT CONCAT('Legacy invoice-detail rows to normalize: ', @LegacyRowCount);

    UPDATE dbo.CustomerPaymentDetail
    SET DetailRole = 'Invoice'
    WHERE SalesId IS NOT NULL
      AND DetailRole IS NULL
      AND ISNULL(IsCreditMemo, 0) = 0
      AND ISNULL(IsCCFee, 0) = 0
      AND SourceCustomerPaymentId IS NULL
      AND SourceSalesId IS NULL
      AND RefundPaymentId IS NULL;

    PRINT CONCAT('Legacy invoice-detail rows normalized: ', @@ROWCOUNT);

    SELECT RemainingLegacyRows = COUNT(*)
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.SalesId IS NOT NULL
      AND pd.DetailRole IS NULL
      AND ISNULL(pd.IsCreditMemo, 0) = 0
      AND ISNULL(pd.IsCCFee, 0) = 0
      AND pd.SourceCustomerPaymentId IS NULL
      AND pd.SourceSalesId IS NULL
      AND pd.RefundPaymentId IS NULL;
END;
GO
