-- 2026-08-13 DROP-SHIP-OPEN-INVOICE-GUARD: require posted Sales journal for positive open invoices.
CREATE   PROCEDURE [dbo].[CustomerPayment_Inject] -- EXEC dbo.CustomerPayment_Inject @EmpId=1,@PayeeId=1,@CustomerPaymentId=0,@PaymentType=N'Customer Payment',@AllowFutureInvoices=0

    @EmpId INT,
    @PayeeId INT,
    @CustomerPaymentId INT,
    @PaymentType NVARCHAR(100),
    @AllowFutureInvoices BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BillId INT;
    DECLARE @IsCorporatePayment BIT = CASE WHEN @PaymentType = 'Corporate Payment' THEN 1 ELSE 0 END;

    SELECT TOP (1)
        @BillId = c.BillId
    FROM dbo.Customer c
    WHERE c.PayeeId = @PayeeId
      AND c.BillId IS NOT NULL;

    DELETE FROM dbo.TempCustomerPayment
    WHERE EmpId = @EmpId
      AND CustomerPaymentId = @CustomerPaymentId;

    IF @CustomerPaymentId > 0
    BEGIN
        DECLARE @PaymentDate DATE;
        DECLARE @PaymentNumber INT;

        SELECT @PaymentDate = cp.PaymentDate, @PaymentNumber = cp.PaymentNumber
        FROM dbo.CustomerPayment cp
        WHERE cp.CustomerPaymentId = @CustomerPaymentId;

        ;WITH PriorApplied AS
        (
            SELECT
                pd.SalesId,
                SUM(ISNULL(pd.PaymentApplied, 0) + ISNULL(pd.DiscountApplied, 0)) AS TotalPriorApplied
            FROM dbo.CustomerPaymentDetail pd
            INNER JOIN dbo.CustomerPayment p
                ON p.CustomerPaymentId = pd.CustomerPaymentId
            WHERE (
                    p.PaymentDate < @PaymentDate
                 OR (p.PaymentDate = @PaymentDate AND p.PaymentNumber < @PaymentNumber)
                  )
              AND pd.SalesId > 0
              AND ISNULL(pd.DetailRole, 'Invoice') IN ('Invoice', 'DebitMemo', 'CreditMemo', 'CCFee')
            GROUP BY pd.SalesId
        ),
        PriorDiscount AS
        (
            SELECT
                pd.SalesId,
                SUM(ISNULL(pd.PaymentDiscount, 0)) AS DiscountTaken
            FROM dbo.CustomerPaymentDetail pd
            INNER JOIN dbo.CustomerPayment p
                ON p.CustomerPaymentId = pd.CustomerPaymentId
            WHERE (
                    p.PaymentDate < @PaymentDate
                 OR (p.PaymentDate = @PaymentDate AND p.PaymentNumber < @PaymentNumber)
                  )
              AND pd.SalesId > 0
              AND ISNULL(pd.DetailRole, 'Invoice') IN ('Invoice', 'DebitMemo', 'CreditMemo', 'CCFee')
            GROUP BY pd.SalesId
        )
        INSERT INTO dbo.TempCustomerPayment
        (
            EmpId,
            PayeeId,
            CustomerPaymentId,
            SalesId,
            AmountDue,
            PaymentApplied,
            PaymentDiscount,
            ShortDiscount,
            OtherDiscount,
            IsCreditMemo,
            IsCCFee,
            IsApplied,
            SourceType,
            SourceId,
            IsSelected,
            DocNumber,
            DocDate,
            Description,
            BillName,
            OriginalAmount,
            OpenBalanceBefore,
            TermName,
            DiscountPercent,
            DiscountAlreadyTaken,
            DiscountDate,
            DueDays
        )
        SELECT
            @EmpId,
            @PayeeId,
            @CustomerPaymentId,
            pd.SalesId,
            ISNULL(s.SalesTotal, 0) - ISNULL(pa.TotalPriorApplied, 0) AS AmountDue,
            SUM(pd.PaymentApplied),
            SUM(pd.PaymentDiscount),
            SUM(pd.ShortDiscount),
            SUM(pd.OtherDiscount),
            MAX(CASE WHEN ISNULL(pd.DetailRole, '') = 'CreditMemo' OR pd.IsCreditMemo = 1 THEN 1 ELSE 0 END),
            MAX(CASE WHEN ISNULL(pd.DetailRole, '') = 'CCFee' OR pd.IsCCFee = 1 THEN 1 ELSE 0 END),
            1 AS IsApplied,
            CASE
                WHEN MAX(CASE WHEN ISNULL(pd.DetailRole, '') = 'CCFee' OR pd.IsCCFee = 1 THEN 1 ELSE 0 END) = 1 THEN 'CCFee'
                WHEN MAX(CASE WHEN ISNULL(pd.DetailRole, '') = 'CreditMemo' OR pd.IsCreditMemo = 1 THEN 1 ELSE 0 END) = 1 THEN 'CreditMemo'
                WHEN MAX(CASE WHEN ISNULL(pd.DetailRole, '') = 'DebitMemo' THEN 1 ELSE 0 END) = 1 THEN 'DebitMemo'
                ELSE 'Invoice'
            END,
            pd.SalesId,
            1,
            CAST(s.SalesNumber AS NVARCHAR(30)),
            s.ShipDate,
            ps.PayeeName,
            pb.PayeeName,
            s.SalesTotal,
            ISNULL(s.SalesTotal, 0) - ISNULL(pa.TotalPriorApplied, 0),
            tm.TermName,
            ISNULL(s.DiscountPercent, ISNULL(tm.Discount, 0)),
            ISNULL(prd.DiscountTaken, 0),
            s.DiscountDate,
            ISNULL(tm.DueDays, 0)
        FROM dbo.CustomerPayment p
        INNER JOIN dbo.CustomerPaymentDetail pd ON p.CustomerPaymentId = pd.CustomerPaymentId
        INNER JOIN dbo.Sales s ON s.SalesId = pd.SalesId
        INNER JOIN dbo.Payee ps ON ps.PayeeId = s.ShipId
        INNER JOIN dbo.Payee pb ON pb.PayeeId = s.BillId
        LEFT JOIN PriorApplied pa ON pa.SalesId = pd.SalesId
        LEFT JOIN PriorDiscount prd ON prd.SalesId = pd.SalesId
        LEFT JOIN dbo.Term tm ON tm.TermId = s.TermId
        WHERE p.CustomerPaymentId = @CustomerPaymentId
          AND pd.SalesId > 0
          AND ISNULL(pd.DetailRole, 'Invoice') IN ('Invoice', 'DebitMemo', 'CreditMemo', 'CCFee')
        GROUP BY
            pd.SalesId,
            s.SalesNumber,
            s.ShipDate,
            ps.PayeeName,
            pb.PayeeName,
            s.SalesTotal,
            pa.TotalPriorApplied,
            tm.TermName,
            s.DiscountPercent,
            tm.Discount,
            prd.DiscountTaken,
            s.DiscountDate,
            tm.DueDays;

        INSERT INTO dbo.TempCustomerPayment
        (
            EmpId,
            PayeeId,
            CustomerPaymentId,
            SalesId,
            AmountDue,
            PaymentApplied,
            PaymentDiscount,
            ShortDiscount,
            OtherDiscount,
            IsCreditMemo,
            IsCCFee,
            IsApplied,
            SourceType,
            SourceId,
            IsSelected,
            DocNumber,
            DocDate,
            Description,
            BillName,
            OriginalAmount,
            OpenBalanceBefore,
            TermName,
            DiscountPercent,
            DiscountAlreadyTaken,
            DiscountDate,
            DueDays
        )
        SELECT
            @EmpId,
            @PayeeId,
            @CustomerPaymentId,
            0,
            (ISNULL(cp.UnappliedAmount, 0) + SUM(src.TotalConsumed)) * -1,
            SUM(src.TotalConsumed) * -1,
            0,
            0,
            0,
            0,
            0,
            1,
            'UnappliedPayment',
            cp.CustomerPaymentId,
            1,
            CAST(cp.PaymentNumber AS NVARCHAR(30)),
            cp.PaymentDate,
            ISNULL(p.PayeeName, CONCAT('Payment #', cp.PaymentNumber, ' unapplied')),
            NULL,
            cp.PaymentAmount,
            (ISNULL(cp.UnappliedAmount, 0) + SUM(src.TotalConsumed)) * -1,
            NULL,
            0,
            0,
            NULL,
            0
        FROM
        (
            SELECT
                pd.SourceCustomerPaymentId,
                SUM(ISNULL(pd.PaymentApplied, 0)) AS TotalConsumed
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.CustomerPaymentId = @CustomerPaymentId
              AND pd.SourceCustomerPaymentId IS NOT NULL
              AND pd.SourceCustomerPaymentId <> @CustomerPaymentId
            GROUP BY pd.SourceCustomerPaymentId
        ) src
        INNER JOIN dbo.CustomerPayment cp ON cp.CustomerPaymentId = src.SourceCustomerPaymentId
        LEFT JOIN dbo.Payee p ON p.PayeeId = cp.PayeeId
        GROUP BY
            cp.CustomerPaymentId,
            cp.UnappliedAmount,
            cp.PaymentNumber,
            cp.PaymentDate,
            cp.PaymentAmount,
            p.PayeeName;

        -- ConsumedCredit: inject one merged row per consuming payment that used this payment's extra
        INSERT INTO dbo.TempCustomerPayment
        (
            EmpId, PayeeId, CustomerPaymentId, SalesId,
            AmountDue, PaymentApplied, PaymentDiscount, ShortDiscount, OtherDiscount,
            IsCreditMemo, IsCCFee, IsApplied,
            SourceType, SourceId, IsSelected,
            DocNumber, DocDate, Description, BillName,
            OriginalAmount, OpenBalanceBefore,
            TermName, DiscountPercent, DiscountAlreadyTaken, DiscountDate, DueDays
        )
        SELECT
            @EmpId, @PayeeId, @CustomerPaymentId, 0,
            0, SUM(cs.TotalConsumed) * -1, 0, 0, 0,
            0, 0, 1,
            'ConsumedCredit', cp2.PaymentNumber, 1,
            CAST(cp2.PaymentNumber AS NVARCHAR(30)),
            cp2.PaymentDate,
            'Used by Pmt #' + CAST(cp2.PaymentNumber AS NVARCHAR(20)),
            NULL,
            0, SUM(cs.TotalConsumed) * -1,
            NULL, 0, 0, NULL, 0
        FROM
        (
            SELECT pd.CustomerPaymentId, SUM(pd.PaymentApplied) AS TotalConsumed
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.SourceCustomerPaymentId = @CustomerPaymentId
              AND pd.CustomerPaymentId != @CustomerPaymentId
            GROUP BY pd.CustomerPaymentId
        ) cs
        INNER JOIN dbo.CustomerPayment cp2 ON cp2.CustomerPaymentId = cs.CustomerPaymentId
        GROUP BY cs.CustomerPaymentId, cp2.PaymentNumber, cp2.PaymentDate;
    END;

    ;WITH AllDiscount AS
    (
        SELECT
            pd.SalesId,
            SUM(ISNULL(pd.PaymentDiscount, 0)) AS AllDiscountTaken
        FROM dbo.CustomerPaymentDetail pd
        GROUP BY pd.SalesId
    )
    INSERT INTO dbo.TempCustomerPayment
    (
        EmpId,
        PayeeId,
        CustomerPaymentId,
        SalesId,
        AmountDue,
        PaymentApplied,
        PaymentDiscount,
        ShortDiscount,
        OtherDiscount,
        IsApplied,
        IsCreditMemo,
        IsCCFee,
        SourceType,
        SourceId,
        IsSelected,
        DocNumber,
        DocDate,
        Description,
        BillName,
        OriginalAmount,
        OpenBalanceBefore,
        TermName,
        DiscountPercent,
        DiscountAlreadyTaken,
        DiscountDate,
        DueDays
    )
    SELECT
        @EmpId,
        @PayeeId,
        @CustomerPaymentId,
        s.SalesId,
        s.AmountDue,
        0,
        0,
        0,
        0,
        0,
        CASE WHEN s.SalesTotal < 0 THEN 1 ELSE 0 END,
        0,
        CASE WHEN s.SalesTotal < 0 THEN 'CreditMemo' ELSE 'Invoice' END,
        s.SalesId,
        0,
        CAST(s.SalesNumber AS NVARCHAR(30)),
        s.ShipDate,
        ps.PayeeName,
        pb.PayeeName,
        s.SalesTotal,
        s.AmountDue,
        tm.TermName,
        ISNULL(s.DiscountPercent, ISNULL(tm.Discount, 0)),
        ISNULL(ad.AllDiscountTaken, 0),
        s.DiscountDate,
        ISNULL(tm.DueDays, 0)
    FROM dbo.Sales s
    INNER JOIN dbo.Payee ps ON ps.PayeeId = s.ShipId
    INNER JOIN dbo.Payee pb ON pb.PayeeId = s.BillId
    LEFT JOIN dbo.Term tm ON tm.TermId = s.TermId
    LEFT JOIN AllDiscount ad ON ad.SalesId = s.SalesId
    WHERE (
            (@PaymentType = 'Customer Refund' AND s.AmountDue < 0)
         OR (@PaymentType <> 'Customer Refund' AND s.AmountDue <> 0)
          )
      AND (
            ISNULL(s.SalesTotal, 0) <= 0
         OR EXISTS (
                SELECT 1
                FROM dbo.TransactionJournal AS tj
                WHERE tj.SourceDocType = 'Sales'
                  AND tj.SourceDocNumber = s.SalesNumber
            )
          )
      AND (
            (@IsCorporatePayment = 1 AND s.BillId = @PayeeId)
         OR (
                @IsCorporatePayment = 0
            AND (
                    (@BillId IS NOT NULL AND s.BillId = @BillId)
                 OR (@BillId IS NULL AND s.ShipId = @PayeeId)
                )
            )
          )
      AND (
            @AllowFutureInvoices = 1
         OR
            @CustomerPaymentId = 0
         OR s.ShipDate IS NULL
         OR s.ShipDate <= @PaymentDate
          )
      AND s.SalesId NOT IN
      (
          SELECT pd.SalesId
          FROM dbo.CustomerPayment p
          INNER JOIN dbo.CustomerPaymentDetail pd ON p.CustomerPaymentId = pd.CustomerPaymentId
          WHERE p.CustomerPaymentId = @CustomerPaymentId
      );

    INSERT INTO dbo.TempCustomerPayment
    (
        EmpId,
        PayeeId,
        CustomerPaymentId,
        SalesId,
        AmountDue,
        PaymentApplied,
        PaymentDiscount,
        ShortDiscount,
        OtherDiscount,
        IsApplied,
        IsCreditMemo,
        IsCCFee,
        SourceType,
        SourceId,
        IsSelected,
        DocNumber,
        DocDate,
        Description,
        BillName,
        OriginalAmount,
        OpenBalanceBefore,
        TermName,
        DiscountPercent,
        DiscountAlreadyTaken,
        DiscountDate,
        DueDays
    )
    SELECT
        @EmpId,
        @PayeeId,
        @CustomerPaymentId,
        0,
        cp.UnappliedAmount * -1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        'UnappliedPayment',
        cp.CustomerPaymentId,
        0,
        CAST(cp.PaymentNumber AS NVARCHAR(30)),
        cp.PaymentDate,
        ISNULL(p.PayeeName, CONCAT('Payment #', cp.PaymentNumber, ' unapplied')),
        NULL,
        cp.PaymentAmount,
        cp.UnappliedAmount * -1,
        NULL,
        0,
        0,
        NULL,
        0
    FROM dbo.CustomerPayment cp
    LEFT JOIN dbo.Payee p ON p.PayeeId = cp.PayeeId
    WHERE cp.PayeeId = @PayeeId
      AND ISNULL(cp.UnappliedAmount, 0) > 0
      AND ISNULL(cp.PaymentType, '') <> 'Customer Refund'
      AND cp.CustomerPaymentId != @CustomerPaymentId
      AND (
            @CustomerPaymentId = 0
         OR cp.PaymentDate IS NULL
         OR cp.PaymentDate < @PaymentDate
         OR (cp.PaymentDate = @PaymentDate AND cp.PaymentNumber < @PaymentNumber)
          )
      AND cp.CustomerPaymentId NOT IN
      (
          SELECT DISTINCT pd.SourceCustomerPaymentId
          FROM dbo.CustomerPaymentDetail pd
          WHERE pd.CustomerPaymentId = @CustomerPaymentId
            AND pd.SourceCustomerPaymentId IS NOT NULL
            AND pd.SourceCustomerPaymentId <> @CustomerPaymentId
      )
      AND ISNULL(cp.IsReturned, 0) = 0;
END



