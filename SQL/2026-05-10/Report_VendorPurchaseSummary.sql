/*
    Report_VendorPurchaseSummary
    -----------------------------
    2026-05-10 — Initial version (new SP, no prior live baseline).

    What it returns
        One row per vendor (Payee.PayeeType = 'V') with rolled-up
        purchase totals across recent time buckets. Designed to answer:
        "Who are our biggest suppliers and how does their spend
        compare month-over-month and year-over-year?"

    Time buckets (anchored on today's date inside the SP)
        M0       Current month-to-date (1st of month .. today)
        M1       Previous full calendar month
        M2       Two calendar months ago (full month)
        M3       Three calendar months ago (full month)
        Last3M   Sum of M1 + M2 + M3 (three prior full months,
                 excludes current partial month so it reads as a
                 stable "recent activity" reference)
        YTD      Jan 1 of the current year through today
        LYTD     Jan 1 of last year through (today minus one year),
                 i.e. same year-to-date window one year earlier so
                 the YoY compare is apples-to-apples

    Filter
        @IncludeClosed BIT = 0
            Default 0  → only show open vendors (Payee.IsClosed = 0)
            Set    1   → include closed vendors as well

    Sort
        YTD DESC, Last3M DESC, MAX(PurchaseDate) DESC
        Biggest current-year spenders first; ties broken by recent
        3-month activity, then by recency of last bill.

    Performance note
        The pre-filter PurchaseDate >= @LastYearStart restricts the
        scan to the last ~16-22 months of data (since @LastYearStart
        is Jan 1 of last year). Rows older than that cannot
        contribute to any output bucket, so dropping them upfront
        keeps the GROUP BY cheap regardless of full table size.
*/

CREATE PROCEDURE [dbo].[Report_VendorPurchaseSummary]
    @IncludeClosed BIT = 0
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

    -- Roll up purchase totals per vendor.
    -- Pre-filter Purchase rows to those that could contribute to
    -- any visible bucket (anything older than @LastYearStart cannot).
    SELECT
        VendorId      = pay.PayeeId,
        VendorName    = pay.PayeeName,

        Last3M        = SUM(CASE WHEN pur.PurchaseDate BETWEEN @M3Start    AND @M1End
                                  THEN pur.PurchaseTotal ELSE 0 END),

        M0            = SUM(CASE WHEN pur.PurchaseDate >= @M0Start
                                  AND pur.PurchaseDate <= @Today
                                  THEN pur.PurchaseTotal ELSE 0 END),

        M1            = SUM(CASE WHEN pur.PurchaseDate BETWEEN @M1Start    AND @M1End
                                  THEN pur.PurchaseTotal ELSE 0 END),

        M2            = SUM(CASE WHEN pur.PurchaseDate BETWEEN @M2Start    AND @M2End
                                  THEN pur.PurchaseTotal ELSE 0 END),

        M3            = SUM(CASE WHEN pur.PurchaseDate BETWEEN @M3Start    AND @M3End
                                  THEN pur.PurchaseTotal ELSE 0 END),

        YTD           = SUM(CASE WHEN pur.PurchaseDate BETWEEN @YearStart  AND @Today
                                  THEN pur.PurchaseTotal ELSE 0 END),

        LYTD          = SUM(CASE WHEN pur.PurchaseDate BETWEEN @LastYearStart AND @LYTDEnd
                                  THEN pur.PurchaseTotal ELSE 0 END),

        TotalBills    = COUNT(pur.PurchaseId),

        LastPurchase  = MAX(pur.PurchaseDate)

    FROM dbo.Payee AS pay
    INNER JOIN dbo.Purchase AS pur
        ON pur.PayeeId = pay.PayeeId
       AND pur.PurchaseDate >= @LastYearStart   -- bound the scan window
    WHERE pay.PayeeType = 'V'
      AND (@IncludeClosed = 1 OR pay.IsClosed = 0)
    GROUP BY
        pay.PayeeId,
        pay.PayeeName
    ORDER BY
        YTD          DESC,
        Last3M       DESC,
        MAX(pur.PurchaseDate) DESC;

END
GO
