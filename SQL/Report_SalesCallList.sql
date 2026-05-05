CREATE OR ALTER PROCEDURE [dbo].[Report_SalesCallList]
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       This report returns one row per customer for the Sales Call List.

       The legacy report grouped the final result in application code:
       - CustCallSchedule = '123456'  => call every day
       - everything else              => not every day

       The procedure therefore returns a flat customer list with the
       fields that legacy used for display and grouping.
       ============================================================ */

    SELECT
        c.PayeeId,
        p.PayeeName,
        p.PhoneDesc1,
        p.Phone1,
        p.PhoneDesc2,
        p.Phone2,
        ls.CustLastOrderDate,
        CASE
            WHEN ls.CustLastOrderDate IS NULL THEN NULL
            ELSE DATEDIFF(DAY, ls.CustLastOrderDate, CAST(GETDATE() AS DATE))
        END AS DaysAgo,
        CAST(NULL AS NVARCHAR(100)) AS CustLastCallingStatus,
        LTRIM(RTRIM(ISNULL(c.CallSchedule, ''))) AS CustCallSchedule,
        ISNULL(ls.SalesTotal, 0) AS SalesTotal,
        c.Region AS CustRegion,
        rep.PayeeName AS SalesRepName
    FROM dbo.Customer AS c
    INNER JOIN dbo.Payee AS p
        ON p.PayeeId = c.PayeeId
    LEFT JOIN dbo.Payee AS rep
        ON rep.PayeeId = c.SalesRepId
    OUTER APPLY
    (
        SELECT TOP 1
            s.ShipDate AS CustLastOrderDate,
            s.SalesTotal
        FROM dbo.Sales AS s
        WHERE s.ShipId = c.PayeeId
          AND ISNULL(s.DocType, '') <> 'CM'
          AND ISNULL(s.SalesTotal, 0) <> 0
        ORDER BY s.ShipDate DESC, s.SalesId DESC
    ) AS ls
    WHERE ls.CustLastOrderDate BETWEEN DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
                                  AND DATEADD(DAY, -2, CAST(GETDATE() AS DATE))
    ORDER BY
        CASE WHEN LTRIM(RTRIM(ISNULL(c.CallSchedule, ''))) = '123456' THEN 1 ELSE 0 END,
        c.Region,
        p.PayeeName;
END
