-- ============================================================================
-- Report_PurchaseHistory  (2026-05-19)
-- Vendor analog of Report_SalesHistory. Returns one row per Purchase (Bill)
-- for the given vendor over an optional date range, ordered most recent first.
-- Frontend groups by year then month from PurchaseDate.
--
-- First-time create -- no _prev rename guard needed.
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO

DROP PROCEDURE IF EXISTS dbo.Report_PurchaseHistory;
GO

CREATE PROCEDURE [dbo].[Report_PurchaseHistory]
    @PayeeId   INT,
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PurchaseId,
        p.PurchaseNumber,
        p.PurchaseDate,
        p.ContainerNumber,
        CAST(p.PurchaseTotal AS DECIMAL(18,2)) AS PurchaseTotal
    FROM dbo.Purchase p
    WHERE p.PayeeId = @PayeeId
      AND (@StartDate IS NULL OR p.PurchaseDate >= @StartDate)
      AND (@EndDate   IS NULL OR p.PurchaseDate <= @EndDate)
    ORDER BY p.PurchaseDate DESC, p.PurchaseNumber DESC;
END
GO
