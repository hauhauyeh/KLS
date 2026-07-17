CREATE PROCEDURE [dbo].[Report_SalesDaily] --[Report_SalesDaily] '02/01/2026','02/28/2026',null
    @StartDate DATE,
    @EndDate DATE,
    @SalesRepId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalSales DECIMAL(18,2);
    DECLARE @COGSAccountId INT
	DECLARE @ISALEAccountId INT
	DECLARE @IDGAccountId INT

    SELECT @COGSAccountId = AccountId FROM Account WHERE AccountCode = '@COGS'
	SELECT @ISALEAccountId = AccountId FROM Account WHERE AccountCode = '@ISALE'
	SELECT @ISALEAccountId = AccountId FROM Account WHERE AccountCode = '@IDG'

    ;WITH IncomeAccounts AS
    (
        SELECT AccountId 
        FROM Account a INNER JOIN AccountCategory c ON a.AccountCategoryId = c.AccountCategoryId
        WHERE c.ClassCode = 'I' 
        UNION ALL 
        SELECT @COGSAccountId
    ),

    JournalData AS
    (
        SELECT 
            t.TxDate,
            t.SourceDocNumber,
            CASE WHEN td.AccountId = @COGSAccountId THEN @ISALEAccountId
                 ELSE td.AccountId END AS AccountId,

            SUM(CASE WHEN td.AccountId != @COGSAccountId 
                     THEN td.Amount ELSE 0 END) AS SalesTotal,

            SUM(CASE WHEN td.AccountId = @COGSAccountId 
                     THEN td.Amount ELSE 0 END) AS Cost
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td 
            ON t.TxId = td.TxId
        INNER JOIN IncomeAccounts ia 
            ON ia.AccountId = td.AccountId
        WHERE t.SourceDocType = 'Sales'
          AND t.TxDate BETWEEN @StartDate AND @EndDate
        GROUP BY t.TxDate, t.SourceDocNumber, td.AccountId
    ),

    DiscountData AS
    (
        SELECT 
            t.TxDate,
            pd.SalesId AS SourceDocNumber,
            td.AccountId AS AccountId,
            pd.DiscountApplied * -1 AS SalesTotal,
            0 AS Cost
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td ON t.TxId = td.TxId
        INNER JOIN CustomerPayment c ON c.PaymentNumber = t.SourceDocNumber
        INNER JOIN CustomerPaymentDetail pd 
            ON pd.CustomerPaymentId = c.CustomerPaymentId
        WHERE t.SourceDocType = 'Customer Payment'
          AND td.AccountId = @IDGAccountId
          AND pd.DiscountApplied != 0
          AND t.TxDate BETWEEN @StartDate AND @EndDate
    ),

    FinalData AS
    (
        SELECT * FROM JournalData
        UNION ALL
        SELECT * FROM DiscountData
    )

    SELECT 
        f.TxDate AS ShipDate,
        s.ShipRoute,
        p.PayeeName,
        f.SourceDocNumber AS SalesNumber,
        s.SalesRepId,
        f.SalesTotal,
        CAST(0 AS decimal) AS SalesPercent, -- calculated later
        f.Cost,
        CAST(0 AS decimal) AS MarginPercent, -- calculated later
        f.AccountId,
        c.AccountName
    INTO #DailySales
    FROM FinalData f
    INNER JOIN Sales s 
        ON s.SalesNumber = f.SourceDocNumber
    INNER JOIN Payee p 
        ON p.PayeeId = s.ShipId
    INNER JOIN Account c 
        ON c.AccountId = f.AccountId
    WHERE (@SalesRepId IS NULL OR s.SalesRepId = @SalesRepId);

    SELECT @TotalSales = SUM(ISNULL(SalesTotal,0))
    FROM #DailySales;

    UPDATE #DailySales
    SET 
        SalesPercent = CASE WHEN @TotalSales != 0 
                         THEN SalesTotal / @TotalSales 
                         ELSE 0 END,
        MarginPercent = CASE WHEN SalesTotal != 0 
                      THEN (SalesTotal - Cost) / SalesTotal 
                      ELSE 0 END;

    SELECT 
    ROW_NUMBER() OVER(ORDER BY ShipRoute, PayeeName, SalesNumber) AS Id,
    *
    FROM #DailySales
    ORDER BY ShipRoute, PayeeName, SalesNumber;
END

