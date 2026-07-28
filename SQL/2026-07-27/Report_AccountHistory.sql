-- 2026-07-27 SalesDocNumber Slice 12A: expose SalesDocNumber for account history display.
CREATE OR ALTER PROCEDURE [dbo].[Report_AccountHistory]
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH PaymentCTE AS
    (
        SELECT
            cp.SalesId,
            STRING_AGG(
                CONVERT(VARCHAR(10), c.PaymentDate, 101) + ' ' +
                c.PaymentMethod + ' $' +
                CONVERT(VARCHAR(20), c.PaymentAmount),
            ', ') AS PmtApplied
        FROM dbo.CustomerPayment c
        INNER JOIN dbo.CustomerPaymentDetail cp
            ON c.CustomerPaymentId = cp.CustomerPaymentId
        GROUP BY cp.SalesId
    )
    SELECT
        s.SalesId,
        s.SalesNumber,
        s.SalesDocNumber,
        s.DocType,
        s.ShipDate,
        s.SalesTotal,
        ISNULL(p.PmtApplied, '') AS PmtApplied,
        ss.StageName AS PmtStage
    FROM dbo.Sales s
    LEFT JOIN PaymentCTE p
        ON s.SalesId = p.SalesId
    LEFT JOIN dbo.SalesStage ss
        ON ss.StageId =
            CASE
                WHEN s.AmountDue = 0 THEN 8
                WHEN s.AmountDue < 0 THEN 6
                WHEN s.AmountDue = s.SalesTotal THEN 5
                ELSE 7
            END
    WHERE s.ShipId = @PayeeId
    ORDER BY s.ShipDate DESC;
END
