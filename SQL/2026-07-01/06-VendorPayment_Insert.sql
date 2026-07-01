SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Fix: Handle orphaned PurchaseIds when editing a payment
-- Bug 3 (defensive): When editing a payment, old PurchaseIds removed from the new payment
--         need recalculation via Purchase_CalcTotalAndPercent

CREATE OR ALTER PROCEDURE [dbo].[VendorPayment_Insert]
    @VendorPaymentId INT,
    @PayeeId INT,
    @PaymentDate DATE,
    @PaymentType NVARCHAR(100),
    @PaymentMethod NVARCHAR(50),
    @ReferenceId NVARCHAR(100),
    @FromAccountId INT,
    @PaymentAmount DECIMAL(18,2),
    @Notes NVARCHAR(255),
    @EmpId INT,
    @NewPaymentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VendorPaymentNumber INT = 0;
    DECLARE @TxId BIGINT;
    DECLARE @CrDeAmount DECIMAL(18,2) = 0;
    DECLARE @AccountId INT;
    DECLARE @Amount DECIMAL(18,2);
    DECLARE @SourceDocType NVARCHAR(100);
    DECLARE @SourceDocOrder INT;
    DECLARE @TotalPaymentApplied DECIMAL(18,2);
    DECLARE @IsRedeposit BIT = 0;
    DECLARE @MailDate DATE;
    DECLARE @IsReturn1 BIT = 0;
    DECLARE @IsReturn2 BIT = 0;
    DECLARE @PrintDate DATE;
    DECLARE @BankDate DATE;
    DECLARE @IsLocked BIT = 0;
    DECLARE @CreatedAt DATETIME = GETUTCDATE();
    DECLARE @UpdatedAt DATETIME;
    DECLARE @DiscountApplied DECIMAL(18,2);
    DECLARE @IsAccountDebit BIT;
    DECLARE @X DECIMAL(18,2);

    -- FIX: Capture old PurchaseIds before any deletion (for orphan recalc)
    DECLARE @OldPurchaseIds TABLE (PurchaseId INT);

    IF @VendorPaymentId > 0
    BEGIN
        SET @UpdatedAt = GETUTCDATE();

        -- FIX: Capture old PurchaseIds before delete
        INSERT INTO @OldPurchaseIds SELECT DISTINCT PurchaseId FROM VendorPaymentDetail WHERE VendorPaymentId = @VendorPaymentId;

        SELECT
            @VendorPaymentNumber = PaymentNumber,
            @IsReturn1 = IsReturn1,
            @IsRedeposit = IsRedeposit,
            @IsReturn2 = IsReturn2,
            @PrintDate = PrintDate,
            @MailDate = MailDate,
            @BankDate = BankDate,
            @IsLocked = IsLocked,
            @CreatedAt = CreatedAt
        FROM dbo.VendorPayment
        WHERE VendorPaymentId = @VendorPaymentId;

        IF @IsRedeposit = 0
            DELETE FROM dbo.VendorPayment
            WHERE VendorPaymentId = @VendorPaymentId;
    END
    ELSE
    BEGIN
        SET @VendorPaymentNumber = NEXT VALUE FOR dbo.Seq_VendorPaymentNumber;
    END;

    -- Keep explicit refund companion payment types intact.
    -- Only coerce normal vendor disbursements into Bill Payment / Bill CCard.
    IF @PaymentType NOT IN ('Vendor Refund', 'Customer Refund')
    BEGIN
        IF @PaymentMethod = 'CREDIT CARD'
            SET @PaymentType = 'Bill CCard';
        ELSE
            SET @PaymentType = 'Bill Payment';
    END;

    IF @PaymentMethod = 'HANDWRITE CHECK'
        SET @MailDate = @PaymentDate;

    SET @SourceDocType = @PaymentType;

    EXEC dbo.Get_SourceDocOrder
        @SourceDocType,
        @SourceDocOrder OUTPUT;

    DECLARE @BillCount INT;

    SELECT @BillCount = COUNT(p.PurchaseId)
    FROM dbo.Purchase AS p
    WHERE p.PurchaseId IN
    (
        SELECT tvp.PurchaseId
        FROM dbo.TempVendorPayment AS tvp
        WHERE tvp.EmpId = @EmpId
          AND tvp.PayeeId = @PayeeId
          AND tvp.IsApplied = 1
          AND ABS(tvp.PaymentApplied + tvp.DiscountApplied) > ABS(p.AmountDue)
    );

    IF @BillCount > 0
    BEGIN
        RAISERROR('Some bill is already paid which you applied for this payment.', 16, 1);
        RETURN;
    END;

    IF @VendorPaymentId = 0
       AND @PaymentMethod = 'CHECK'
    BEGIN
        EXEC dbo.Get_CheckNumber
            @FromAccountId,
            @ReferenceId OUTPUT;
    END;

    IF @IsRedeposit = 1
    BEGIN
        DELETE FROM dbo.VendorPaymentDetail
        WHERE VendorPaymentId = @VendorPaymentId;

        GOTO ifRedeposited;
    END;

    INSERT INTO dbo.VendorPayment
    (
        PaymentNumber,
        PaymentType,
        PayeeId,
        PaymentDate,
        PaymentMethod,
        ReferenceId,
        FromAccountId,
        PaymentAmount,
        Notes,
        MailDate,
        BankDate,
        IsReturn1,
        IsRedeposit,
        IsReturn2,
        PrintDate,
        IsLocked,
        CreatedAt,
        UpdatedAt
    )
    VALUES
    (
        @VendorPaymentNumber,
        @PaymentType,
        @PayeeId,
        @PaymentDate,
        @PaymentMethod,
        @ReferenceId,
        @FromAccountId,
        @PaymentAmount,
        @Notes,
        @MailDate,
        @BankDate,
        @IsReturn1,
        @IsRedeposit,
        @IsReturn2,
        @PrintDate,
        @IsLocked,
        @CreatedAt,
        @UpdatedAt
    );

    SELECT @VendorPaymentId = SCOPE_IDENTITY();

ifRedeposited:

    INSERT INTO dbo.VendorPaymentDetail
    (
        VendorPaymentId,
        PurchaseId,
        PaymentApplied,
        DiscountApplied
    )
    SELECT
        @VendorPaymentId,
        PurchaseId,
        PaymentApplied,
        DiscountApplied
    FROM dbo.TempVendorPayment
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND IsApplied = 1;

    EXEC dbo.VendorPayment_UpdatePurchase
        @VendorPaymentId,
        0;

    -- FIX: Recalc orphaned PurchaseIds (old bills no longer in the new payment)
    IF EXISTS (SELECT 1 FROM @OldPurchaseIds)
    BEGIN
        DECLARE @OrphanId INT, @OrphanTotal DECIMAL(18,2);
        DECLARE curOrphan CURSOR LOCAL FAST_FORWARD FOR
            SELECT PurchaseId FROM @OldPurchaseIds
            WHERE PurchaseId NOT IN (SELECT PurchaseId FROM VendorPaymentDetail WHERE VendorPaymentId = @VendorPaymentId);
        OPEN curOrphan;
        FETCH NEXT FROM curOrphan INTO @OrphanId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC [Purchase_CalcTotalAndPercent] @OrphanId, @OrphanTotal OUTPUT;
            FETCH NEXT FROM curOrphan INTO @OrphanId;
        END
        CLOSE curOrphan;
        DEALLOCATE curOrphan;
    END

    DECLARE @AcctTable TABLE
    (
        Id INT IDENTITY(1,1),
        AccountCode NVARCHAR(50),
        AccountId INT
    );

    INSERT INTO @AcctTable (AccountCode) VALUES ('@AP');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@CRP');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@UF');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@IDR');

    UPDATE t
    SET t.AccountId = a.AccountId
    FROM @AcctTable AS t
    INNER JOIN dbo.Account AS a
        ON t.AccountCode = a.AccountCode;

    INSERT INTO dbo.TransactionJournal
    (
        TxDate,
        TxTime,
        SourceDocOrder,
        SourceDocType,
        SourceDocNumber,
        Notes,
        BankDate,
        IsLocked
    )
    VALUES
    (
        @PaymentDate,
        GETUTCDATE(),
        @SourceDocOrder,
        @SourceDocType,
        @VendorPaymentNumber,
        @Notes,
        @BankDate,
        @IsLocked
    );

    SELECT @TxId = SCOPE_IDENTITY();

    -- Refund payout path:
    -- this is the issued-refund companion vendor payment created from customer refund reserve.
    --
    -- Business rule for this path:
    -- - do not use AP detail logic
    -- - do not use VendorPaymentDetail at all
    -- - payout accounting should be:
    --     CRP debit
    --     BANK credit
    --
    -- Why:
    -- the customer-payment side already created the refund reserve liability.
    -- This vendor-payment side is only the actual cash-out step.
    IF @PaymentType = 'Customer Refund'
    BEGIN
        -- Refund line 1:
        -- debit Customer Refund Payable to release the reserve when cash goes out.
        SELECT @AccountId = AccountId
        FROM @AcctTable
        WHERE AccountCode = '@CRP';

        SET @Amount = ABS(ISNULL(@PaymentAmount, 0)) * -1;

        EXEC dbo.Fn_Adjust_CrDeAmount
            @AccountId,
            @Amount,
            @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail
        (
            TxId,
            AccountId,
            PayeeId,
            Amount,
            CrDeAmount
        )
        VALUES
        (
            @TxId,
            @AccountId,
            @PayeeId,
            @Amount,
            @CrDeAmount
        );
    END
    ELSE
    BEGIN
        -- Normal vendor-payment path:
        -- AP debit still comes from the applied vendor detail rows.
        SELECT @TotalPaymentApplied = ISNULL(SUM(PaymentApplied) + SUM(DiscountApplied), 0)
        FROM dbo.VendorPaymentDetail
        WHERE VendorPaymentId = @VendorPaymentId;

        SELECT @AccountId = AccountId
        FROM @AcctTable
        WHERE AccountCode = '@AP';

        SET @Amount = @TotalPaymentApplied * -1;

        EXEC dbo.Fn_Adjust_CrDeAmount
            @AccountId,
            @Amount,
            @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail
        (
            TxId,
            AccountId,
            PayeeId,
            Amount,
            CrDeAmount
        )
        VALUES
        (
            @TxId,
            @AccountId,
            @PayeeId,
            @Amount,
            @CrDeAmount
        );
    END;

    --Insert into TxJournalDetail 'ANY BANK ACCOUNT USER SELECT'
    SET @AccountId = @FromAccountId;

    SELECT @IsAccountDebit = IsAccountDebit
    FROM dbo.Account
    WHERE AccountId = @AccountId;

    IF @IsAccountDebit = 1
        SET @X = @PaymentAmount * -1;
    ELSE
        SET @X = @PaymentAmount;

    -- Bank/cash side:
    -- - Customer Refund uses the selected bank/cash account directly
    -- - Vendor Refund keeps its older UF exception behavior
    IF @PaymentType = 'Vendor Refund'
       AND @PaymentMethod != 'CREDIT CARD'
    BEGIN
        SELECT @AccountId = AccountId
        FROM @AcctTable
        WHERE AccountCode = '@UF';
    END;

    EXEC dbo.Fn_Adjust_CrDeAmount
        @AccountId,
        @X,
        @CrDeAmount OUTPUT;

    INSERT INTO dbo.TransactionJournalDetail
    (
        TxId,
        AccountId,
        PayeeId,
        Amount,
        CrDeAmount
    )
    VALUES
    (
        @TxId,
        @AccountId,
        @PayeeId,
        @X,
        @CrDeAmount
    );

    SELECT @DiscountApplied = ISNULL(SUM(DiscountApplied), 0)
    FROM dbo.VendorPaymentDetail
    WHERE VendorPaymentId = @VendorPaymentId;

    IF @DiscountApplied != 0
    BEGIN
        SELECT @AccountId = AccountId
        FROM @AcctTable
        WHERE AccountCode = '@IDR';

        SET @Amount = ABS(@DiscountApplied);

        SELECT @IsAccountDebit = IsAccountDebit
        FROM dbo.Account
        WHERE AccountId = @AccountId;

        IF @IsAccountDebit = 1
            SET @Amount = @Amount * -1;

        EXEC dbo.Fn_Adjust_CrDeAmount
            @AccountId,
            @Amount,
            @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail
        (
            TxId,
            AccountId,
            PayeeId,
            Amount,
            CrDeAmount
        )
        VALUES
        (
            @TxId,
            @AccountId,
            @PayeeId,
            @Amount,
            @CrDeAmount
        );
    END;

    IF @PaymentType = 'Vendor Refund' AND @PaymentMethod != 'CREDIT CARD'
    BEGIN
        DECLARE @CustomerPaymentNumber INT;

        SET @CustomerPaymentNumber = NEXT VALUE FOR dbo.Seq_CustomerPaymentNumber;

        INSERT INTO dbo.CustomerPayment
        (
            PaymentNumber,
            PaymentType,
            PayeeId,
            PaymentDate,
            PaymentMethod,
            FromAccountId,
            ReferenceId,
            PaymentAmount,
            Notes,
            VendorPaymentId,
            CreatedAt
        )
        VALUES
        (
            @CustomerPaymentNumber,
            @PaymentType,
            @PayeeId,
            @PaymentDate,
            @PaymentMethod,
            NULL,
            @ReferenceId,
            ABS(@PaymentAmount),
            @Notes,
            @VendorPaymentId,
            @CreatedAt
        );
    END;

    DELETE dbo.TempVendorPayment WHERE EmpId = @EmpId AND PayeeId = @PayeeId;

    EXEC dbo.Recalc_AfterInsert @TxId,@PaymentDate;

    SET @NewPaymentId = @VendorPaymentId;
END
GO
