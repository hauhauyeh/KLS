-- 2026-07-27 SalesDocNumber Slice 12A: expose SalesDocNumber for AR Aging display.
CREATE OR ALTER PROCEDURE [dbo].[Report_ARAging]
    @AsOfDate   DATE,
    @AgeBasis   NVARCHAR(20),
    @CustomerId INT          = NULL,
    @TermId     INT          = NULL,
    @SalesRepId INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOfDate IS NULL SET @AsOfDate = CAST(GETDATE() AS DATE);
    IF @AgeBasis IS NULL SET @AgeBasis = 'DueDate';

    IF @AgeBasis NOT IN ('DueDate','InvoiceDate')
        THROW 50001, 'AgeBasis must be DueDate or InvoiceDate', 1;

    ;WITH BillRows AS
    (
        SELECT
            s.SalesId,
            s.ShipId AS PayeeId,
            pe.PayeeName,
            pe.TermId,
            pe.LastPaymentDate,
            pe.LastPaymentAmount,
            s.SalesNumber,
            s.SalesDocNumber,
            s.CustPONumber AS PONumber,
            s.ShipDate,
            s.DueDate,
            s.SalesTotal,
            s.AmountDue,
            DATEDIFF(DAY,
                CASE @AgeBasis
                    WHEN 'DueDate' THEN ISNULL(s.DueDate, s.ShipDate)
                    WHEN 'InvoiceDate' THEN s.ShipDate
                END,
                @AsOfDate
            ) AS AgeDays
        FROM dbo.Sales s
        INNER JOIN dbo.Payee pe ON pe.PayeeId = s.ShipId
        WHERE pe.PayeeType = 'C'
          AND s.AmountDue <> 0
          AND (@CustomerId IS NULL OR pe.PayeeId = @CustomerId)
          AND (@TermId IS NULL OR pe.TermId = @TermId)
          AND (@SalesRepId IS NULL OR s.SalesRepId = @SalesRepId)
    )
    SELECT
        b.SalesId,
        b.PayeeId,
        b.PayeeName AS Customer,
        b.SalesNumber,
        b.SalesDocNumber,
        b.PONumber,
        b.ShipDate,
        b.DueDate,
        t.TermName AS Term,
        b.LastPaymentDate,
        b.LastPaymentAmount,
        b.SalesTotal AS OriginalAmount,
        b.AmountDue AS OpenBalance,
        b.AgeDays,
        CASE
            WHEN @AgeBasis = 'DueDate' AND b.AgeDays < 0 THEN 'Current'
            WHEN b.AgeDays <= 30 THEN CASE @AgeBasis WHEN 'DueDate' THEN '1-30' ELSE '0-30' END
            WHEN b.AgeDays <= 60 THEN '31-60'
            WHEN b.AgeDays <= 90 THEN '61-90'
            ELSE 'Over 90'
        END AS Bucket,
        CASE WHEN @AgeBasis = 'DueDate' AND b.AgeDays < 0 THEN b.AmountDue ELSE 0 END AS BucketCurrent,
        CASE WHEN ((@AgeBasis = 'DueDate' AND b.AgeDays BETWEEN 0 AND 30)
                OR (@AgeBasis = 'InvoiceDate' AND b.AgeDays BETWEEN 0 AND 30))
             THEN b.AmountDue ELSE 0 END AS Bucket30,
        CASE WHEN b.AgeDays BETWEEN 31 AND 60 THEN b.AmountDue ELSE 0 END AS Bucket60,
        CASE WHEN b.AgeDays BETWEEN 61 AND 90 THEN b.AmountDue ELSE 0 END AS Bucket90,
        CASE WHEN b.AgeDays > 90 THEN b.AmountDue ELSE 0 END AS BucketOver90,
        CASE WHEN b.AmountDue < 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCredit
    FROM BillRows b
    LEFT JOIN dbo.Term t ON t.TermId = b.TermId
    ORDER BY
        b.PayeeName,
        CASE @AgeBasis
            WHEN 'DueDate' THEN ISNULL(b.DueDate, b.ShipDate)
            WHEN 'InvoiceDate' THEN b.ShipDate
        END;
END
