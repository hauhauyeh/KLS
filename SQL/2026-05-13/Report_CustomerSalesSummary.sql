/*
    Report_CustomerSalesSummary
    ----------------------------
    2026-05-13 — Initial version (new SP, no prior live baseline).

    What it returns
        One row per customer (Payee.PayeeType = 'C') with rolled-up
        sales totals across recent time buckets. Designed to answer:
        "Who are our biggest customers and how does their volume
        compare month-over-month and year-over-year?"

    Time buckets (anchored on today's date inside the SP)
        M0       Current month-to-date (1st of month .. today)
        M1       Previous full calendar month
        M2       Two calendar months ago (full month)
        M3       Three calendar months ago (full month)
        YTD      Jan 1 of the current year through today
        LYTD     Jan 1 of last year through (today minus one year),
                 i.e. same year-to-date window one year earlier so
                 the YoY compare is apples-to-apples

    Date bucketed on Sales.SalesDate (when the sale was recorded).

    Customer attribution is on Sales.ShipId (the shipping party),
    explicitly NOT Sales.BillId. Even for corporate customers where
    BillId may aggregate multiple ship-to locations under one billing
    parent, this report attributes to whoever physically received the
    shipment. Drop-ship orders attribute to the ship-to customer.

    Credit memos (DocType='CM') are included as negative contributions
    because Sales.SalesTotal is already signed -- CMs reduce the
    bucket totals naturally so the report shows NET sales.

    Filters
        @IncludeClosed BIT = 0
            Default 0  -> only show open customers (Payee.IsClosed = 0)
            Set    1   -> include closed customers as well

        @SalesRepId INT = NULL
            NULL       -> no rep filter (admin scope)
            Non-NULL   -> filter to customers where
                          Customer.SalesRepId = @SalesRepId.
                          Customers with Customer.SalesRepId IS NULL
                          are naturally excluded by this equality.

        Sales-role enforcement is server-trusted: ReportService
        overrides @SalesRepId to UserContext.EmpId when the caller
        is a sales-role user, regardless of what the request asked
        for. This SP only sees the post-override value.

    Sort
        YTD DESC, MAX(SalesDate) DESC
        Biggest current-year customers first; ties broken by recency
        of last sale.

    Performance note
        The pre-filter SalesDate >= @LastYearStart restricts the scan
        to the last ~16-22 months of Sales data (since @LastYearStart
        is Jan 1 of last year). Rows older than that cannot contribute
        to any output bucket, so dropping them upfront keeps the
        GROUP BY cheap regardless of full table size.
*/

CREATE OR ALTER PROCEDURE [dbo].[Report_CustomerSalesSummary]
    @IncludeClosed BIT = 0,
    @SalesRepId    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Anchor everything on today's calendar date.
    DECLARE @Today         DATE = CAST(GETDATE() AS DATE);

    -- Year-to-date windows.
    DECLARE @YearStart     DATE = DATEFROMPARTS(YEAR(@Today), 1, 1);
    DECLARE @LastYearStart DATE = DATEFROMPARTS(YEAR(@Today) - 1, 1, 1);
    DECLARE @LYTDEnd       DATE = DATEADD(YEAR, -1, @Today);

    -- Monthly buckets. M0Start is the 1st of the current month;
    -- successive prior months step back one month each.
    DECLARE @M0Start       DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    DECLARE @M1Start       DATE = DATEADD(MONTH, -1, @M0Start);
    DECLARE @M2Start       DATE = DATEADD(MONTH, -2, @M0Start);
    DECLARE @M3Start       DATE = DATEADD(MONTH, -3, @M0Start);
    DECLARE @M1End         DATE = DATEADD(DAY, -1, @M0Start);
    DECLARE @M2End         DATE = DATEADD(DAY, -1, @M1Start);
    DECLARE @M3End         DATE = DATEADD(DAY, -1, @M2Start);

    -- Roll up sales totals per customer.
    -- Pre-filter Sales rows to those that could contribute to any
    -- visible bucket (anything older than @LastYearStart cannot).
    --
    -- INNER JOIN Customer is safe because pay.PayeeType = 'C'
    -- guarantees a matching Customer row exists in this schema.
    -- Verified during plan authoring on 2026-05-13.
    SELECT
        CustomerId    = pay.PayeeId,
        CustomerName  = pay.PayeeName,

        M0            = SUM(CASE WHEN sal.SalesDate >= @M0Start
                                  AND sal.SalesDate <= @Today
                                  THEN sal.SalesTotal ELSE 0 END),

        M1            = SUM(CASE WHEN sal.SalesDate BETWEEN @M1Start    AND @M1End
                                  THEN sal.SalesTotal ELSE 0 END),

        M2            = SUM(CASE WHEN sal.SalesDate BETWEEN @M2Start    AND @M2End
                                  THEN sal.SalesTotal ELSE 0 END),

        M3            = SUM(CASE WHEN sal.SalesDate BETWEEN @M3Start    AND @M3End
                                  THEN sal.SalesTotal ELSE 0 END),

        YTD           = SUM(CASE WHEN sal.SalesDate BETWEEN @YearStart  AND @Today
                                  THEN sal.SalesTotal ELSE 0 END),

        LYTD          = SUM(CASE WHEN sal.SalesDate BETWEEN @LastYearStart AND @LYTDEnd
                                  THEN sal.SalesTotal ELSE 0 END),

        TotalTx       = COUNT(sal.SalesId),

        LastSale      = MAX(sal.SalesDate)

    FROM dbo.Payee AS pay
    INNER JOIN dbo.Customer AS cust
        ON cust.PayeeId = pay.PayeeId
    INNER JOIN dbo.Sales AS sal
        ON sal.ShipId = pay.PayeeId            -- attribute revenue to the ship-to customer
       AND sal.SalesDate >= @LastYearStart    -- bound the scan window
    WHERE pay.PayeeType = 'C'
      AND (@IncludeClosed = 1 OR pay.IsClosed = 0)
      AND (@SalesRepId IS NULL OR cust.SalesRepId = @SalesRepId)
    GROUP BY
        pay.PayeeId,
        pay.PayeeName
    ORDER BY
        YTD          DESC,
        MAX(sal.SalesDate) DESC;

END
GO
