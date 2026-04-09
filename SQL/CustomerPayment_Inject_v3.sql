-- v3 foundation:
-- Rewrite inject to populate both legacy columns and new v3 snapshot columns,
-- including prior unapplied-payment funding rows.

IF OBJECT_ID('dbo.CustomerPayment_Inject_prev', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CustomerPayment_Inject_prev;

EXEC sp_rename 'dbo.CustomerPayment_Inject', 'CustomerPayment_Inject_prev';
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE PROCEDURE [dbo].[CustomerPayment_Inject]

    @EmpId INT,
    @PayeeId INT,
    @CustomerPaymentId INT,
    @PaymentType NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BillId INT;

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
            WHERE p.PaymentDate < @PaymentDate
               OR (p.PaymentDate = @PaymentDate AND p.CustomerPaymentId < @CustomerPaymentId)
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
            WHERE p.PaymentDate < @PaymentDate
               OR (p.PaymentDate = @PaymentDate AND p.CustomerPaymentId < @CustomerPaymentId)
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
            MAX(CASE WHEN pd.IsCreditMemo = 1 THEN 1 ELSE 0 END),
            MAX(CASE WHEN pd.IsCCFee = 1 THEN 1 ELSE 0 END),
            1 AS IsApplied,
            CASE
                WHEN MAX(CASE WHEN pd.IsCCFee = 1 THEN 1 ELSE 0 END) = 1 THEN 'CCFee'
                WHEN s.SalesTotal < 0 THEN 'CreditMemo'
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
            (ISNULL(cp.UnappliedAmount, 0) + SUM(pd.PaymentApplied)) * -1,
            SUM(pd.PaymentApplied) * -1,
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
            (ISNULL(cp.UnappliedAmount, 0) + SUM(pd.PaymentApplied)) * -1,
            NULL,
            0,
            0,
            NULL,
            0
        FROM dbo.CustomerPaymentDetail pd
        INNER JOIN dbo.CustomerPayment cp ON cp.PaymentNumber = pd.SourcePaymentNumber
        LEFT JOIN dbo.Payee p ON p.PayeeId = cp.PayeeId
        WHERE pd.CustomerPaymentId = @CustomerPaymentId
          AND pd.SourcePaymentNumber IS NOT NULL
        GROUP BY
            cp.CustomerPaymentId,
            cp.UnappliedAmount,
            cp.PaymentNumber,
            cp.PaymentDate,
            cp.PaymentAmount,
            p.PayeeName;

        -- ConsumedCredit: inject one row per consuming payment that used this payment's extra
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
            0, SUM(pd.PaymentApplied) * -1, 0, 0, 0,
            0, 0, 1,
            'ConsumedCredit', cp2.PaymentNumber, 1,
            CAST(cp2.PaymentNumber AS NVARCHAR(30)),
            cp2.PaymentDate,
            'Used by Pmt #' + CAST(cp2.PaymentNumber AS NVARCHAR(20)),
            NULL,
            0, SUM(pd.PaymentApplied) * -1,
            NULL, 0, 0, NULL, 0
        FROM dbo.CustomerPaymentDetail pd
        INNER JOIN dbo.CustomerPayment cp2 ON cp2.CustomerPaymentId = pd.CustomerPaymentId
        WHERE pd.SourcePaymentNumber = @PaymentNumber
          AND pd.CustomerPaymentId != @CustomerPaymentId
        GROUP BY pd.CustomerPaymentId, cp2.PaymentNumber, cp2.PaymentDate;
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
            (@BillId IS NOT NULL AND s.BillId = @BillId)
         OR (@BillId IS NULL AND s.ShipId = @PayeeId)
          )
      AND (
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
      AND cp.CustomerPaymentId != @CustomerPaymentId
      AND (
            @CustomerPaymentId = 0
         OR cp.PaymentDate IS NULL
         OR cp.PaymentDate <= @PaymentDate
          )
      AND cp.PaymentNumber NOT IN
      (
          SELECT DISTINCT pd.SourcePaymentNumber
          FROM dbo.CustomerPaymentDetail pd
          WHERE pd.CustomerPaymentId = @CustomerPaymentId
            AND pd.SourcePaymentNumber IS NOT NULL
      )
      AND ISNULL(cp.IsReturned, 0) = 0;
END
GO
