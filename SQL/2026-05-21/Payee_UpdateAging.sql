SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Round 2 for this SP — _prev already exists from AR round, so DROP + CREATE only.
DROP PROCEDURE IF EXISTS [dbo].[Payee_UpdateAging];
GO

CREATE PROCEDURE [dbo].[Payee_UpdateAging]
    @PayeeId INT,
    @IsSales BIT
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Cache writer for Payee.* AR/AP aggregate fields.

      AR branch (from AR round): inline DATEDIFF math matching View_Customer.
      AP branch (this round): same treatment — inline DATEDIFF math matching
      View_Vendor. FirstDueDate writes MIN(DueDate) (was MIN(ArrivalDate)).
      MaxInvoiceAgingDays uses inline DATEDIFF over ISNULL(InvoiceDate,
      PurchaseDate), not the bugged stored Purchase.InvoiceAging column.

      Rule 1: per-customer (ShipId) for AR, per-vendor (PayeeId) for AP.
      Rule 5: every cached Payee.* field written here matches the matching view
              column row-for-row.
    */

    DECLARE @TodayDate DATE = CAST(GETDATE() AS DATE);

    DECLARE @PayeeTotalDue       DECIMAL(18,2) = 0,
            @Balance             DECIMAL(18,2) = 0,
            @Credit              DECIMAL(18,2) = 0,
            @FirstDueDate        DATE          = NULL,
            @LastOrderDate       DATE          = NULL,
            @LastOrderAmount     DECIMAL(18,2) = 0,
            @LastPaymentDate     DATE          = NULL,
            @LastPaymentAmount   DECIMAL(18,2) = 0,
            @AvgPaymentDays      INT           = NULL,
            @MaxInvoiceAgingDays INT           = NULL,
            @MaxAging            INT           = 0,
            @Payee30Volume       DECIMAL(18,2) = 0,

            @PayeeCurrent        DECIMAL(18,2) = 0,
            @Payee30             DECIMAL(18,2) = 0,
            @Payee60             DECIMAL(18,2) = 0,
            @Payee90             DECIMAL(18,2) = 0,
            @PayeeOver90         DECIMAL(18,2) = 0,
            @PayeePastDue        DECIMAL(18,2) = 0,
            @Invoice30           DECIMAL(18,2) = 0,
            @Invoice60           DECIMAL(18,2) = 0,
            @Invoice90           DECIMAL(18,2) = 0,
            @InvoiceOver90       DECIMAL(18,2) = 0,
            @WindowStart         DATE          = NULL;

    IF @IsSales = 1
    BEGIN
        /* ----------------------------------------------------------------
           AR branch — UNCHANGED FROM AR ROUND.
           Inline DATEDIFF matching View_Customer.
           ---------------------------------------------------------------- */
        SELECT
            @PayeeCurrent        = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate,  @TodayDate) <= 0              THEN AmountDue ELSE 0 END), 0),
            @Payee30             = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate,  @TodayDate) BETWEEN 1  AND 30 THEN AmountDue ELSE 0 END), 0),
            @Payee60             = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate,  @TodayDate) BETWEEN 31 AND 60 THEN AmountDue ELSE 0 END), 0),
            @Payee90             = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate,  @TodayDate) BETWEEN 61 AND 90 THEN AmountDue ELSE 0 END), 0),
            @PayeeOver90         = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate,  @TodayDate) > 90              THEN AmountDue ELSE 0 END), 0),

            @Invoice30           = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ShipDate, @TodayDate) BETWEEN 0  AND 30 THEN AmountDue ELSE 0 END), 0),
            @Invoice60           = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ShipDate, @TodayDate) BETWEEN 31 AND 60 THEN AmountDue ELSE 0 END), 0),
            @Invoice90           = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ShipDate, @TodayDate) BETWEEN 61 AND 90 THEN AmountDue ELSE 0 END), 0),
            @InvoiceOver90       = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ShipDate, @TodayDate) > 90              THEN AmountDue ELSE 0 END), 0),

            @PayeeTotalDue       = ISNULL(SUM(AmountDue), 0),
            @PayeePastDue        = ISNULL(SUM(CASE WHEN DueDate < @TodayDate THEN AmountDue END), 0),
            @FirstDueDate        = MIN(DueDate),
            @MaxInvoiceAgingDays = MAX(DATEDIFF(DAY, ShipDate, @TodayDate)),
            @MaxAging            = ISNULL(MAX(CASE WHEN DATEDIFF(DAY, DueDate, @TodayDate) > 0
                                                   THEN DATEDIFF(DAY, DueDate, @TodayDate)
                                                   ELSE 0 END), 0)
        FROM Sales
        WHERE ShipId = @PayeeId
          AND AmountDue <> 0;

        /* Latest order */
        SELECT TOP (1)
            @LastOrderDate   = ShipDate,
            @LastOrderAmount = SalesTotal
        FROM Sales
        WHERE ShipId = @PayeeId
          AND SalesTotal > 0
        ORDER BY ShipDate DESC, SalesId DESC;

        /* Credit */
        SELECT
            @Credit = ISNULL(SUM(UnappliedAmount), 0)
        FROM CustomerPayment
        WHERE PayeeId = @PayeeId
          AND UnappliedAmount <> 0
          AND IsReturned = 0;

        /* Latest payment */
        SELECT TOP (1)
            @LastPaymentDate   = PaymentDate,
            @LastPaymentAmount = PaymentAmount
        FROM CustomerPayment
        WHERE PayeeId = @PayeeId
        ORDER BY PaymentDate DESC, CustomerPaymentId DESC;

        SET @Balance = @PayeeTotalDue - @Credit;

        /* Avg payment days in last 180 days from latest payment */
        IF @LastPaymentDate IS NOT NULL
        BEGIN
            SET @WindowStart = DATEADD(DAY, -180, @LastPaymentDate);

            ;WITH Seq AS
            (
                SELECT
                    PaymentDate,
                    LEAD(PaymentDate) OVER (ORDER BY PaymentDate) AS NextPmtDate
                FROM CustomerPayment
                WHERE PayeeId = @PayeeId
                  AND PaymentDate > @WindowStart
            )
            SELECT
                @AvgPaymentDays = CAST(AVG(CAST(DATEDIFF(DAY, PaymentDate, NextPmtDate) AS DECIMAL(10,2))) AS INT)
            FROM Seq
            WHERE NextPmtDate IS NOT NULL;
        END

        /* 30-day rolling customer sales volume */
        SELECT
            @Payee30Volume = ISNULL(SUM(SalesTotal), 0)
        FROM Sales
        WHERE ShipId = @PayeeId
          AND ShipDate >= DATEADD(DAY, -30, @TodayDate)
          AND SalesTotal > 0;

        UPDATE p
        SET
            p.PayeeCurrent        = @PayeeCurrent,
            p.Payee30             = @Payee30,
            p.Payee60             = @Payee60,
            p.Payee90             = @Payee90,
            p.PayeeOver90         = @PayeeOver90,
            p.PayeeTotalDue       = @PayeeTotalDue,
            p.PayeePastDue        = @PayeePastDue,
            p.Invoice30           = @Invoice30,
            p.Invoice60           = @Invoice60,
            p.Invoice90           = @Invoice90,
            p.InvoiceOver90       = @InvoiceOver90,
            p.Balance             = @Balance,
            p.IsPastDue           = CASE WHEN @MaxAging > 0 AND @MaxAging < p.GracePeriod THEN 1 ELSE 0 END,
            p.IsCreditHold        = CASE
                                        WHEN p.IsDelinquent = 1
                                          OR (c.CreditLimit IS NOT NULL AND @PayeeTotalDue > c.CreditLimit)
                                          OR @MaxAging > p.GracePeriod
                                        THEN 1 ELSE 0
                                    END,
            p.FirstDueDate        = @FirstDueDate,
            p.LastOrderDate       = @LastOrderDate,
            p.LastOrderAmount     = @LastOrderAmount,
            p.LastPaymentDate     = @LastPaymentDate,
            p.LastPaymentAmount   = @LastPaymentAmount,
            p.AvgPaymentDays      = @AvgPaymentDays,
            p.MaxInvoiceAgingDays = @MaxInvoiceAgingDays,
            p.Payee30Volume       = @Payee30Volume
        FROM Payee p
        LEFT JOIN Customer c ON c.PayeeId = p.PayeeId
        WHERE p.PayeeId = @PayeeId;
    END
    ELSE
    BEGIN
        /* ----------------------------------------------------------------
           AP branch — rewritten this round.
           Inline DATEDIFF matching View_Vendor. Invoice-date basis is
           ISNULL(InvoiceDate, PurchaseDate). Stored Purchase.Aging /
           Purchase.InvoiceAging columns are NOT read here.
           FirstDueDate now writes MIN(DueDate) (was MIN(ArrivalDate)).
           ---------------------------------------------------------------- */
        SELECT
            @PayeeCurrent        = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate, @TodayDate) <= 0                                                  THEN AmountDue ELSE 0 END), 0),
            @Payee30             = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate, @TodayDate) BETWEEN 1  AND 30                                     THEN AmountDue ELSE 0 END), 0),
            @Payee60             = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate, @TodayDate) BETWEEN 31 AND 60                                     THEN AmountDue ELSE 0 END), 0),
            @Payee90             = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate, @TodayDate) BETWEEN 61 AND 90                                     THEN AmountDue ELSE 0 END), 0),
            @PayeeOver90         = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, DueDate, @TodayDate) > 90                                                  THEN AmountDue ELSE 0 END), 0),

            @Invoice30           = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ISNULL(InvoiceDate, PurchaseDate), @TodayDate) BETWEEN 0  AND 30           THEN AmountDue ELSE 0 END), 0),
            @Invoice60           = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ISNULL(InvoiceDate, PurchaseDate), @TodayDate) BETWEEN 31 AND 60           THEN AmountDue ELSE 0 END), 0),
            @Invoice90           = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ISNULL(InvoiceDate, PurchaseDate), @TodayDate) BETWEEN 61 AND 90           THEN AmountDue ELSE 0 END), 0),
            @InvoiceOver90       = ISNULL(SUM(CASE WHEN DATEDIFF(DAY, ISNULL(InvoiceDate, PurchaseDate), @TodayDate) > 90                        THEN AmountDue ELSE 0 END), 0),

            @PayeeTotalDue       = ISNULL(SUM(AmountDue), 0),
            @PayeePastDue        = ISNULL(SUM(CASE WHEN DueDate < @TodayDate THEN AmountDue END), 0),
            @FirstDueDate        = MIN(DueDate),  -- Rule 4 / Bug H: was MIN(ArrivalDate)
            @MaxInvoiceAgingDays = MAX(DATEDIFF(DAY, ISNULL(InvoiceDate, PurchaseDate), @TodayDate))
        FROM Purchase
        WHERE PayeeId = @PayeeId
          AND AmountDue <> 0;

        SET @Balance = @PayeeTotalDue;   -- AP has no UnappliedAmount on VendorPayment

        /* Latest order (delivery) */
        SELECT TOP (1)
            @LastOrderDate   = ArrivalDate,
            @LastOrderAmount = PurchaseTotal
        FROM Purchase
        WHERE PayeeId = @PayeeId
          AND PurchaseTotal > 0
        ORDER BY ArrivalDate DESC, PurchaseId DESC;

        /* Latest payment */
        SELECT TOP (1)
            @LastPaymentDate   = PaymentDate,
            @LastPaymentAmount = PaymentAmount
        FROM VendorPayment
        WHERE PayeeId = @PayeeId
        ORDER BY PaymentDate DESC, VendorPaymentId DESC;

        /* Avg payment days for vendor payments too */
        IF @LastPaymentDate IS NOT NULL
        BEGIN
            SET @WindowStart = DATEADD(DAY, -180, @LastPaymentDate);

            ;WITH Seq AS
            (
                SELECT
                    PaymentDate,
                    LEAD(PaymentDate) OVER (ORDER BY PaymentDate) AS NextPmtDate
                FROM VendorPayment
                WHERE PayeeId = @PayeeId
                  AND PaymentDate > @WindowStart
            )
            SELECT
                @AvgPaymentDays = CAST(AVG(CAST(DATEDIFF(DAY, PaymentDate, NextPmtDate) AS DECIMAL(10,2))) AS INT)
            FROM Seq
            WHERE NextPmtDate IS NOT NULL;
        END

        UPDATE p
        SET
            p.PayeeCurrent        = @PayeeCurrent,
            p.Payee30             = @Payee30,
            p.Payee60             = @Payee60,
            p.Payee90             = @Payee90,
            p.PayeeOver90         = @PayeeOver90,
            p.PayeeTotalDue       = @PayeeTotalDue,
            p.PayeePastDue        = @PayeePastDue,
            p.Invoice30           = @Invoice30,
            p.Invoice60           = @Invoice60,
            p.Invoice90           = @Invoice90,
            p.InvoiceOver90       = @InvoiceOver90,
            p.Balance             = @Balance,
            p.FirstDueDate        = @FirstDueDate,
            p.LastOrderDate       = @LastOrderDate,
            p.LastOrderAmount     = @LastOrderAmount,
            p.LastPaymentDate     = @LastPaymentDate,
            p.LastPaymentAmount   = @LastPaymentAmount,
            p.AvgPaymentDays      = @AvgPaymentDays,
            p.MaxInvoiceAgingDays = @MaxInvoiceAgingDays
        FROM Payee p
        WHERE p.PayeeId = @PayeeId;
    END
END
GO
