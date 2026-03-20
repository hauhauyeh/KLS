-- Report_CustomerPayment — Customer payment listing with optional filters
CREATE PROCEDURE [dbo].[Report_CustomerPayment]
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @PayeeId INT = NULL,
    @PmtMethod NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NULL
    BEGIN
        SET @StartDate = CAST(GETDATE() AS DATE);
        SET @EndDate = CAST(GETDATE() AS DATE);
    END

    SELECT
        cp.CustomerPaymentId,
        cp.PaymentDate,
        ISNULL(cp.PaymentMethod, 'CREDIT APPLY') AS PaymentMethod,
        cp.ReferenceId,
        CAST(cp.PaymentAmount AS DECIMAL(18,2)) AS PaymentAmount,
        p.PayeeName,
        cp.Notes
    FROM dbo.CustomerPayment cp
    INNER JOIN dbo.Payee p ON cp.PayeeId = p.PayeeId
    WHERE cp.PaymentDate >= @StartDate AND cp.PaymentDate <= @EndDate
      AND (@PayeeId IS NULL OR cp.PayeeId = @PayeeId)
      AND (@PmtMethod IS NULL OR cp.PaymentMethod = @PmtMethod)
    ORDER BY cp.PaymentDate DESC, cp.PaymentMethod, p.PayeeName;
END
