SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_ARRollforward] -- EXEC [dbo].[Report_ARRollforward] @StartDate = '2026-08-01', @EndDate = '2026-08-31', @PayeeId = NULL
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @PayeeId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @EndDate IS NULL SET @EndDate = CAST(GETDATE() AS DATE);
    IF @StartDate IS NULL SET @StartDate = DATEFROMPARTS(YEAR(@EndDate), MONTH(@EndDate), 1);

    IF @StartDate > @EndDate
        THROW 50001, 'StartDate must be on or before EndDate.', 1;

    DECLARE @ARAccountId INT;

    SELECT @ARAccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@AR';

    IF @ARAccountId IS NULL
        THROW 50002, 'Accounts Receivable account @AR was not found.', 1;

    ;WITH ARRows AS
    (
        SELECT
            tjd.PayeeId,
            tj.TxDate,
            tj.SourceDocType,
            tjd.Amount
        FROM dbo.TransactionJournal tj
        INNER JOIN dbo.TransactionJournalDetail tjd ON tjd.TxId = tj.TxId
        WHERE tjd.AccountId = @ARAccountId
          AND tjd.PayeeId IS NOT NULL
          AND ISNULL(tjd.Amount, 0) <> 0
          AND tj.TxDate <= @EndDate
          AND (@PayeeId IS NULL OR tjd.PayeeId = @PayeeId)
    ),
    Rollforward AS
    (
        SELECT
            ar.PayeeId,
            ISNULL(SUM(CASE
                WHEN ar.TxDate < @StartDate THEN ar.Amount
                ELSE 0
            END), 0) AS BeginningAR,
            ISNULL(SUM(CASE
                WHEN ar.TxDate BETWEEN @StartDate AND @EndDate
                 AND ar.SourceDocType = 'Sales'
                 AND ar.Amount > 0
                THEN ar.Amount
                ELSE 0
            END), 0) AS Invoices,
            ISNULL(SUM(CASE
                WHEN ar.TxDate BETWEEN @StartDate AND @EndDate
                 AND ar.SourceDocType = 'Customer Payment'
                 AND ar.Amount < 0
                THEN ar.Amount * -1
                ELSE 0
            END), 0) AS Payments,
            ISNULL(SUM(CASE
                WHEN ar.TxDate BETWEEN @StartDate AND @EndDate
                 AND NOT (ar.SourceDocType = 'Sales' AND ar.Amount > 0)
                 AND NOT (ar.SourceDocType = 'Customer Payment' AND ar.Amount < 0)
                THEN ar.Amount
                ELSE 0
            END), 0) AS CreditsAdjustments,
            ISNULL(SUM(CASE
                WHEN ar.TxDate <= @EndDate THEN ar.Amount
                ELSE 0
            END), 0) AS EndingAR
        FROM ARRows ar
        GROUP BY ar.PayeeId
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY p.PayeeName, r.PayeeId) AS Id,
        r.PayeeId,
        p.PayeeName AS Customer,
        r.BeginningAR,
        r.Invoices,
        r.Payments,
        r.CreditsAdjustments,
        r.EndingAR
    FROM Rollforward r
    INNER JOIN dbo.Payee p ON p.PayeeId = r.PayeeId
    WHERE r.BeginningAR <> 0
       OR r.Invoices <> 0
       OR r.Payments <> 0
       OR r.CreditsAdjustments <> 0
       OR r.EndingAR <> 0
    ORDER BY p.PayeeName, r.PayeeId;
END
GO
