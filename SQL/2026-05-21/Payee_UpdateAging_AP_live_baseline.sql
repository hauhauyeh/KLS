
CREATE PROCEDURE [dbo].[Payee_UpdateAging]
    @PayeeId INT,
    @IsSales BIT
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Cache writer for Payee.* AR/AP aggregate fields.

      AR branch (this round): rewritten to use inline DATEDIFF math matching
      View_Customer exactly. No more SUM over stored Sales.Aging / InvoiceAging.
      FirstDueDate writes MIN(DueDate) (Bug H fix). Adds Payee30Volume write
      (formerly unmaintained — Blocker 2 resolution).

      AP branch (@IsSales = 0): unchanged this round. AP plan owns the equivalent
      rewrite. See view-vendor-realtime-aging-plan.md.

      Rule 1: ShipId is the AR aggregation key (BillId belongs to corp payment module).
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
        /* Single pass over Sales — buckets use inline DATEDIFF, matching View_Customer.
           Stored Sales.Aging / Sales.InvoiceAging columns are NOT read here. */
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
            @FirstDueDate        = MIN(DueDate),  -- Rule 4 / Bug H: was MIN(ShipDate)
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

        /* 30-day rolling customer sales volume (Blocker 2 resolution — formerly unwritten). */
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
            p.Payee90             = @Payee90,          -- fixed missing assignment
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
            p.Payee30Volume       = @Payee30Volume     -- Blocker 2: now actively maintained
        FROM Payee p
        LEFT JOIN Customer c ON c.PayeeId = p.PayeeId
        WHERE p.PayeeId = @PayeeId;
    END
    ELSE
    BEGIN
        /* ----------------------------------------------------------------
           AP branch — UNCHANGED THIS ROUND.
           Preserved verbatim from baseline (KLS\SQL\2026-05-21\Payee_UpdateAging_live_baseline.sql).
           AP plan round rewrites this to match the same inline DATEDIFF pattern.
           ---------------------------------------------------------------- */

        /* Single pass over Purchase */
        SELECT
            @PayeeCurrent        = ISNULL(SUM(CASE WHEN Aging = 0 THEN AmountDue END), 0),
            @Payee30             = ISNULL(SUM(CASE WHEN Aging BETWEEN 1 AND 30 THEN AmountDue END), 0),
            @Payee60             = ISNULL(SUM(CASE WHEN Aging BETWEEN 31 AND 60 THEN AmountDue END), 0),
            @Payee90             = ISNULL(SUM(CASE WHEN Aging BETWEEN 61 AND 90 THEN AmountDue END), 0),
            @PayeeOver90         = ISNULL(SUM(CASE WHEN Aging >= 91 THEN AmountDue END), 0),

            @Invoice30           = ISNULL(SUM(CASE WHEN InvoiceAging BETWEEN 0 AND 30 THEN AmountDue END), 0),
            @Invoice60           = ISNULL(SUM(CASE WHEN InvoiceAging BETWEEN 31 AND 60 THEN AmountDue END), 0),
            @Invoice90           = ISNULL(SUM(CASE WHEN InvoiceAging BETWEEN 61 AND 90 THEN AmountDue END), 0),
            @InvoiceOver90       = ISNULL(SUM(CASE WHEN InvoiceAging >= 91 THEN AmountDue END), 0),

            @PayeeTotalDue       = ISNULL(SUM(AmountDue), 0),
            @PayeePastDue        = ISNULL(SUM(CASE WHEN DueDate < @TodayDate THEN AmountDue END), 0),
            @FirstDueDate        = MIN(CASE WHEN AmountDue > 0 THEN ArrivalDate END),
            @MaxInvoiceAgingDays = MAX(InvoiceAging)
        FROM Purchase
        WHERE PayeeId = @PayeeId
          AND AmountDue <> 0;

        SET @Balance = @PayeeTotalDue;

        /* Latest order */
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

