SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[VendorPayment_ApplyAdvance]
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        DECLARE
            @PayeeId INT,
            @PurchaseNumber INT,
            @BillAmount DECIMAL(18,2),
            @CurrentApplied DECIMAL(18,2),
            @CurrentAmountDue DECIMAL(18,2),
            @RemainingBillBalance DECIMAL(18,2),

            @VendorPaymentId INT,
            @VendorPaymentDetailId INT,
            @UnappliedAmount DECIMAL(18,2),
            @ApplyAmount DECIMAL(18,2),

            @PaymentNumber INT,
            @SourceDocType NVARCHAR(100),
            @SourceDocOrder INT,

            @AccountId INT,
            @Amount DECIMAL(18,2),
            @CrDeAmount DECIMAL(18,2),
            @TxId BIGINT;

        -------------------------------------------------------------------
        -- Load purchase / bill info
        -------------------------------------------------------------------
        SELECT
            @PayeeId = p.PayeeId,
            @PurchaseNumber = p.PurchaseNumber,
            @BillAmount = ISNULL(p.PurchaseTotal, 0),
            @CurrentApplied = ISNULL(p.PaymentApplied, 0),
            @CurrentAmountDue = ISNULL(p.AmountDue, ISNULL(p.PurchaseTotal, 0) - ISNULL(p.PaymentApplied, 0))
        FROM Purchase p
        WHERE p.PurchaseId = @PurchaseId;

        IF @PayeeId IS NULL
        BEGIN
            RAISERROR('Purchase not found.', 16, 1);
            RETURN;
        END

        SET @RemainingBillBalance = @BillAmount - @CurrentApplied;

        IF @RemainingBillBalance <= 0
        BEGIN
            RETURN;
        END

        -------------------------------------------------------------------
        -- Build available vendor advances
        -- Rule:
        --   1. Current PO-linked advance first
        --   2. Free vendor credits after (not reserved by other unpaid bills)
        -------------------------------------------------------------------
        DECLARE @AdvanceToApply TABLE
        (
            RowNo INT IDENTITY(1,1),
            VendorPaymentDetailId INT NULL,
            VendorPaymentId INT NOT NULL,
            PaymentNumber INT NOT NULL,
            PaymentDate DATE NULL,
            UnappliedAmount DECIMAL(18,2) NOT NULL,
            IsCurrentPOAdvance BIT NOT NULL
        );

        INSERT INTO @AdvanceToApply
        (
            VendorPaymentDetailId,
            VendorPaymentId,
            PaymentNumber,
            PaymentDate,
            UnappliedAmount,
            IsCurrentPOAdvance
        )
        SELECT
            CurPO.PaymentDetailId,
            vp.VendorPaymentId,
            vp.PaymentNumber,
            vp.PaymentDate,
            ISNULL(vp.UnappliedAmount, ISNULL(vp.PaymentAmount, 0) - ISNULL(UsedAmt.TotalApplied, 0)) AS UnappliedAmount,
            CASE WHEN CurPO.PaymentDetailId IS NULL THEN 0 ELSE 1 END AS IsCurrentPOAdvance
        FROM VendorPayment vp
        OUTER APPLY
        (
            SELECT SUM(ISNULL(vpd2.PaymentApplied, 0)) AS TotalApplied
            FROM VendorPaymentDetail vpd2
            WHERE vpd2.VendorPaymentId = vp.VendorPaymentId
        ) UsedAmt
        OUTER APPLY
        (
            SELECT MIN(vpd.PaymentDetailId) AS PaymentDetailId
            FROM VendorPaymentDetail vpd
            WHERE vpd.VendorPaymentId = vp.VendorPaymentId
              AND vpd.PurchaseId = @PurchaseId
        ) CurPO
        WHERE vp.PayeeId = @PayeeId
          AND vp.PaymentType = 'Advance Bill Payment'
          AND ISNULL(vp.UnappliedAmount, ISNULL(vp.PaymentAmount, 0) - ISNULL(UsedAmt.TotalApplied, 0)) > 0
          AND (
              -- This PO's own advance
              CurPO.PaymentDetailId IS NOT NULL
              OR
              -- Free credit: not reserved by any other bill that still has balance due
              NOT EXISTS (
                  SELECT 1
                  FROM VendorPaymentDetail vpd3
                  INNER JOIN Purchase p2 ON p2.PurchaseId = vpd3.PurchaseId
                  WHERE vpd3.VendorPaymentId = vp.VendorPaymentId
                    AND vpd3.PurchaseId <> @PurchaseId
                    AND ISNULL(p2.AmountDue, ISNULL(p2.PurchaseTotal, 0) - ISNULL(p2.PaymentApplied, 0)) > 0
              )
          )
        ORDER BY
            CASE WHEN CurPO.PaymentDetailId IS NOT NULL THEN 0 ELSE 1 END,   -- current PO advance first
            vp.PaymentDate,
            vp.VendorPaymentId;

        -------------------------------------------------------------------
        -- Nothing to apply
        -------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM @AdvanceToApply)
        BEGIN
            RETURN;
        END

        -------------------------------------------------------------------
        -- Track actual per-payment application for journals
        -------------------------------------------------------------------
        DECLARE @AppliedSummary TABLE
        (
            VendorPaymentId INT PRIMARY KEY,
            PaymentNumber INT NOT NULL,
            AppliedAmount DECIMAL(18,2) NOT NULL
        );

        -------------------------------------------------------------------
        -- Loop through advances and apply
        -------------------------------------------------------------------
        DECLARE @i INT = 1, @cnt INT;
        SELECT @cnt = COUNT(*) FROM @AdvanceToApply;

        WHILE @i <= @cnt AND @RemainingBillBalance > 0
        BEGIN
            SELECT
                @VendorPaymentDetailId = VendorPaymentDetailId,
                @VendorPaymentId = VendorPaymentId,
                @PaymentNumber = PaymentNumber,
                @UnappliedAmount = UnappliedAmount
            FROM @AdvanceToApply
            WHERE RowNo = @i;

            SET @ApplyAmount =
                CASE
                    WHEN @UnappliedAmount >= @RemainingBillBalance THEN @RemainingBillBalance
                    ELSE @UnappliedAmount
                END;

            IF @ApplyAmount > 0
            BEGIN
                -----------------------------------------------------------
                -- Update existing detail row OR create new row
                -----------------------------------------------------------
                IF @VendorPaymentDetailId IS NOT NULL
                BEGIN
                    UPDATE VendorPaymentDetail
                    SET PaymentApplied = ISNULL(PaymentApplied, 0) + @ApplyAmount
                    WHERE PaymentDetailId = @VendorPaymentDetailId;
                END
                ELSE
                BEGIN
                    INSERT INTO VendorPaymentDetail
                    (
                        VendorPaymentId,
                        PurchaseId,
                        PaymentApplied
                    )
                    VALUES
                    (
                        @VendorPaymentId,
                        @PurchaseId,
                        @ApplyAmount
                    );
                END

                -----------------------------------------------------------
                -- Update payment unapplied amount
                -----------------------------------------------------------
                UPDATE VendorPayment
                SET UnappliedAmount = ISNULL(UnappliedAmount, ISNULL(PaymentAmount, 0)) - @ApplyAmount
                WHERE VendorPaymentId = @VendorPaymentId;

                -----------------------------------------------------------
                -- Track applied amount per payment
                -----------------------------------------------------------
                IF EXISTS (SELECT 1 FROM @AppliedSummary WHERE VendorPaymentId = @VendorPaymentId)
                BEGIN
                    UPDATE @AppliedSummary
                    SET AppliedAmount = AppliedAmount + @ApplyAmount
                    WHERE VendorPaymentId = @VendorPaymentId;
                END
                ELSE
                BEGIN
                    INSERT INTO @AppliedSummary
                    (
                        VendorPaymentId,
                        PaymentNumber,
                        AppliedAmount
                    )
                    VALUES
                    (
                        @VendorPaymentId,
                        @PaymentNumber,
                        @ApplyAmount
                    );
                END

                -----------------------------------------------------------
                -- Reduce bill balance
                -----------------------------------------------------------
                SET @RemainingBillBalance = @RemainingBillBalance - @ApplyAmount;
            END

            SET @i = @i + 1;
        END

        -------------------------------------------------------------------
        -- Refresh purchase totals for each applied VendorPayment
        -------------------------------------------------------------------
        DECLARE @U_VendorPaymentId INT;

        DECLARE curUpdate CURSOR LOCAL FAST_FORWARD FOR
        SELECT VendorPaymentId
        FROM @AppliedSummary
        WHERE AppliedAmount > 0;

        OPEN curUpdate;
        FETCH NEXT FROM curUpdate INTO @U_VendorPaymentId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.VendorPayment_UpdatePurchase @U_VendorPaymentId, 0;
            FETCH NEXT FROM curUpdate INTO @U_VendorPaymentId;
        END

        CLOSE curUpdate;
        DEALLOCATE curUpdate;

        -------------------------------------------------------------------
        -- Create one journal per VendorPayment applied
        -------------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM @AppliedSummary)
        BEGIN
            SET @SourceDocType = 'Vendor Advance Applied';
            EXEC [Get_SourceDocOrder] @SourceDocType, @SourceDocOrder OUTPUT;

            DECLARE @JVendorPaymentId INT, @JPaymentNumber INT, @JAppliedAmount DECIMAL(18,2);

            DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT VendorPaymentId, PaymentNumber, AppliedAmount
            FROM @AppliedSummary
            WHERE AppliedAmount > 0;

            OPEN cur;
            FETCH NEXT FROM cur INTO @JVendorPaymentId, @JPaymentNumber, @JAppliedAmount;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO [dbo].[TransactionJournal]
                (
                    [TxDate],
                    [TxTime],
                    [SourceDocOrder],
                    [SourceDocType],
                    [SourceDocNumber]
                )
                VALUES
                (
                    CAST(GETDATE() AS DATE),
                    GETUTCDATE(),
                    @SourceDocOrder,
                    @SourceDocType,
                    @JPaymentNumber
                );

                SET @TxId = SCOPE_IDENTITY();

                -- Accounts Payable
                SELECT @AccountId = AccountId
                FROM Account
                WHERE AccountCode = '@AP';

                SET @Amount = @JAppliedAmount * -1;
                EXEC Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

                INSERT INTO [dbo].[TransactionJournalDetail]
                (
                    [TxId],
                    [AccountId],
                    [PayeeId],
                    [Amount],
                    [CrDeAmount]
                )
                VALUES
                (
                    @TxId,
                    @AccountId,
                    @PayeeId,
                    @Amount,
                    @CrDeAmount
                );

                -- Prepaid To Vendor
                SELECT @AccountId = AccountId
                FROM Account
                WHERE AccountCode = '@APV';

                SET @Amount = @JAppliedAmount * -1;
                EXEC Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

                INSERT INTO [dbo].[TransactionJournalDetail]
                (
                    [TxId],
                    [AccountId],
                    [PayeeId],
                    [Amount],
                    [CrDeAmount]
                )
                VALUES
                (
                    @TxId,
                    @AccountId,
                    @PayeeId,
                    @Amount,
                    @CrDeAmount
                );

                FETCH NEXT FROM cur INTO @JVendorPaymentId, @JPaymentNumber, @JAppliedAmount;
            END

            CLOSE cur;
            DEALLOCATE cur;
        END

    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrState INT = ERROR_STATE();

        RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH
END
