
-- Sales_PartialUpdate codex candidate
-- Date: 2026-04-15
-- Baseline: live dbo.Sales_PartialUpdate from KLS_Latest
--
-- Summary:
--   Goal: preserve baseline partial-update journal behavior, while making
--   temp-cart-owned LineId the source of truth for final SalesDetail order.
--
-- Improvements:
--   1. CREATE OR ALTER instead of ALTER-only/live shape
--   2. XACT_ABORT + TRY/CATCH transaction wrapper
--   3. Fail-fast guards for missing Sales / TransactionJournal rows
--   4. Loop variable hygiene for stale-value protection
--   5. Per-sale applock to reject concurrent/double-submit updates
--   6. Base qty calculation guarded against zero/NULL FactorToBase
--   7. Load all TempSales rows so unchanged surviving lines can also write
--      current LineId back to SalesDetail
--   8. I/U/D journal behavior stays in the same baseline branches
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Sales_PartialUpdate]
	@SalesId INT,
	@EmpId INT
AS
BEGIN
	-- Section 1: initialize procedure state and working variables.
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @TxId BIGINT
	DECLARE @SalesNumber INT
	DECLARE @DocType CHAR(2)
	DECLARE @JournalDocType NVARCHAR(100)
	DECLARE @ShipDate DATE
	DECLARE @IsLocked BIT
	DECLARE @PayeeId INT
	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
	DECLARE @LockResult INT
	DECLARE @LockResource NVARCHAR(100)
	DECLARE @TaxPercent DECIMAL(18,4)
    DECLARE @CrDeAmount DECIMAL(18, 2)
    DECLARE @AccountCode NVARCHAR(50)
	DECLARE @OldItemId INT
	DECLARE @OldAccountId INT
	DECLARE @SubTotal DECIMAL(18,2)
	DECLARE @TaxableTotal DECIMAL(18,2)

	-- Section 2: load header and journal context for this sales document.
	SELECT @SalesNumber=SalesNumber,@DocType=DocType,@ShipDate=ShipDate,@IsLocked=IsLocked,@PayeeId=ShipId,@TaxPercent=TaxPercent
	FROM Sales WHERE SalesId=@SalesId

	IF @SalesNumber IS NULL
	BEGIN
		RAISERROR('Sales record not found for SalesId %d.', 16, 1, @SalesId)
		RETURN;
	END

	SET @JournalDocType = CASE
		WHEN @DocType='CM' THEN 'Sales Credit Memo'
		WHEN @DocType='DM' THEN 'Sales Debit Memo'
		ELSE 'Sales'
	END

	SELECT @TxId=TxId FROM TransactionJournal
	WHERE SourceDocNumber=@SalesNumber AND SourceDocType=@JournalDocType

	IF @TxId IS NULL
	BEGIN
		RAISERROR('TransactionJournal not found for SalesNumber %d.', 16, 1, @SalesNumber)
		RETURN;
	END

	-- Section 3: declare per-row working variables for the update loop.
	DECLARE
        @LineId INT,
        @LineType NVARCHAR(1),
        @ItemId INT,
        @AccountId INT,
		@ItemUnitId INT,
        @Unit NVARCHAR(50),
		@BaseShipQty DECIMAL(18, 6),
		@BaseBillQty DECIMAL(18, 6),
        @OrdQty DECIMAL(18, 2),
        @ShipQty DECIMAL(18, 2),
        @BillQty DECIMAL(18, 2),
        @UnitPrice DECIMAL(18, 2),
        @ExtTotal DECIMAL(18, 2),
        @Notes NVARCHAR(300),
        @IsTaxable BIT,
        @OrgPrice DECIMAL(18, 2),
        @DiscountPercent DECIMAL(18, 4),
        @FactorToBase DECIMAL(18, 6),
        @ChangeStatus NVARCHAR(1),
        @SalesDetailId INT,
        @ItemType NVARCHAR(100),
        @CartLineType NVARCHAR(30),
        @IsSystemManaged BIT,
        @DisplaySort INT,
        @TempSalesId_Current INT;

	DECLARE @IdMap TABLE (
		TempSalesId INT,
		SalesDetailId INT
	);

	-- Section 4: resolve the standard posting accounts used by the existing
	-- partial-update journal logic.
	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)

	INSERT INTO @AcctTable(AccountCode) VALUES('@AR')
    INSERT INTO @AcctTable(AccountCode) VALUES('@FSTP')
	INSERT INTO @AcctTable(AccountCode) VALUES('@ICREDIT')
    INSERT INTO @AcctTable(AccountCode) VALUES('@ISALE')
    INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')

	UPDATE t SET t.AccountId=a.AccountId
	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode

	-- Section 5: snapshot the full temp cart into a working table.
	-- Unlike the baseline, this intentionally loads all rows, not only
	-- ChangeStatus I/U/D rows, because unchanged surviving rows may still need
	-- their LineId written back after temp-cart resequencing.
	DECLARE @TempSaleTable TABLE (
		[AutoId] [int] IDENTITY(1,1) NOT NULL,
		[LineId] [int] NULL,
		[LineType] [nvarchar](1) NOT NULL,
		[ItemId] [int] NULL,
		[AccountId] [int] NULL,
		[ItemUnitId] [int] NULL,
		[Unit] [nvarchar](50) NULL,
		[OrdQty] [decimal](18, 2) NULL,
		[ShipQty] [decimal](18, 2) NULL,
		[BillQty] [decimal](18, 2) NULL,
		[UnitPrice] [decimal](18, 2) NULL,
		[ExtTotal] [decimal](18, 2) NULL,
		[Notes] [nvarchar](300) NULL,
		[IsTaxable] [bit] NOT NULL,
		[OrgPrice] [decimal](18, 2) NULL,
		[DiscountPercent] [decimal](18, 4) NULL,
		[FactorToBase] [decimal](18, 6) NULL,
		[ChangeStatus] [nvarchar](1) null,
		[SalesDetailId] [int] null,
		[ItemType] [nvarchar](100) NULL,
		[CartLineType] [nvarchar](30) NOT NULL,
		[IsSystemManaged] [bit] NOT NULL,
		[DisplaySort] [int] NULL,
		[TempSalesId] [int] NULL,
		[ParentTempSalesId] [int] NULL,
		[RootTempSalesId] [int] NULL
	)

	INSERT INTO @TempSaleTable
		([LineId],[LineType],[ItemId],[AccountId],[ItemUnitId],[Unit],
		 [OrdQty],[ShipQty],[BillQty],[UnitPrice],[ExtTotal],[Notes],
		 [IsTaxable],[OrgPrice],[DiscountPercent],[FactorToBase],
		 [ChangeStatus],[SalesDetailId],[ItemType],
		 [CartLineType],[IsSystemManaged],[DisplaySort],
		 [TempSalesId],[ParentTempSalesId],[RootTempSalesId])
	SELECT [LineId]
      ,[LineType]
      ,t.[ItemId]
      ,[AccountId]
	  ,[ItemUnitId]
      ,[Unit]
      ,[OrdQty]
      ,[ShipQty]
      ,[BillQty]
      ,[UnitPrice]
      ,[ExtTotal]
      ,[Notes]
      ,CASE
		WHEN LineType='A' THEN 0
		ELSE
		(Select IsTaxable FROM dbo.Fn_IsItemTaxable(t.ItemId,@ShipDate,@PayeeId))
	   END
      ,[OrgPrice]
      ,[DiscountPercent]
      ,[FactorToBase]
      ,[ChangeStatus]
      ,[SalesDetailId]
      ,i.ItemType
      ,[CartLineType]
      ,[IsSystemManaged]
      ,[DisplaySort]
      ,t.[TempSalesId]
      ,t.[ParentTempSalesId]
      ,t.[RootTempSalesId]
	FROM TempSales AS t LEFT JOIN Item AS i ON t.ItemId=i.ItemId
	WHERE EmpId=@EmpId AND PayeeId=@PayeeId AND SalesId=@SalesId

	SET @LockResource = 'Sales_PartialUpdate_' + CONVERT(NVARCHAR(20), @SalesId)

	BEGIN TRY
	-- Section 6: start the protected partial-update transaction.
	BEGIN TRANSACTION

	EXEC @LockResult = sp_getapplock
		@Resource = @LockResource,
		@LockMode = 'Exclusive',
		@LockOwner = 'Transaction',
		@LockTimeout = 0

	IF @LockResult < 0
	BEGIN
		RAISERROR('This sales order is already being updated.', 16, 1)
	END

	-- Section 7: trust temp-cart-owned LineId.
	-- TempSales.LineId is already kept correct by the TempSales resequence trigger.
	-- Do not renumber again here. Sales_PartialUpdate should write that final cart
	-- order back into SalesDetail, including unchanged surviving rows.

	SELECT @MaxRow=COUNT(AutoId) FROM @TempSaleTable

	-- Section 8: process the working cart one row at a time.
	-- Important behavioral rule:
	--   NULL status -> only persist the current LineId to SalesDetail
	--   I/U/D       -> keep the same baseline journal/detail branches
	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT
			@OldItemId = NULL,
			@OldAccountId = NULL,
			@AccountCode = NULL;

		SELECT
            @LineId          = LineId,
            @LineType        = LineType,
            @ItemId          = ItemId,
            @AccountId       = AccountId,
			@ItemUnitId      = ItemUnitId,
            @Unit            = Unit,
			@BaseShipQty     = ROUND(ShipQty / NULLIF(FactorToBase, 0), 6),
			@BaseBillQty     = ROUND(BillQty / NULLIF(FactorToBase, 0), 6),
            @OrdQty          = OrdQty,
            @ShipQty         = ShipQty,
            @BillQty         = BillQty,
            @UnitPrice       = UnitPrice,
            @ExtTotal        = ExtTotal,
            @Notes           = Notes,
            @IsTaxable       = IsTaxable,
            @OrgPrice        = OrgPrice,
            @DiscountPercent = DiscountPercent,
            @FactorToBase    = FactorToBase,
            @ChangeStatus    = ChangeStatus,
            @SalesDetailId   = SalesDetailId,
            @ItemType        = ItemType,
            @CartLineType    = CartLineType,
            @IsSystemManaged = IsSystemManaged,
            @DisplaySort     = DisplaySort,
            @TempSalesId_Current = TempSalesId
        FROM @TempSaleTable
        WHERE AutoId = @RowNum;

        IF ISNULL(@ChangeStatus, '') = ''
        BEGIN
			-- Section 8a: unchanged surviving row.
			-- Baseline would ignore this row entirely. We now still persist
			-- LineId so SalesDetail stays aligned with the current temp-cart order.
			UPDATE SalesDetail
			SET LineId = @LineId
			WHERE SalesDetailId = @SalesDetailId
        END
        ELSE IF @ChangeStatus = 'I'
        BEGIN
			-- Section 8b: inserted row.
			-- Journal/detail behavior stays baseline: insert SalesDetail, then
			-- create the corresponding TransactionJournalDetail rows.
			SET @ExtTotal= ROUND(@BillQty*@UnitPrice,2)

            INSERT INTO [dbo].[SalesDetail]
               ([SalesId]
               ,[LineId]
               ,[LineType]
               ,[ItemId]
               ,[AccountId]
			   ,[ItemUnitId]
               ,[Unit]
               ,[OrdQty]
               ,[ShipQty]
               ,[BillQty]
               ,[UnitPrice]
               ,[ExtTotal]
               ,[Notes]
               ,[IsTaxable]
               ,[OrgPrice]
               ,[DiscountPercent]
               ,[FactorToBase]
               ,[ParentSalesDetailId]
               ,[RootSalesDetailId]
               ,[CartLineType]
               ,[IsSystemManaged]
               ,[DisplaySort])
            VALUES
               (@SalesId,
                @LineId,
                @LineType,
                @ItemId,
                @AccountId,
				@ItemUnitId,
                @Unit,
                @OrdQty,
                @ShipQty,
                @BillQty,
                @UnitPrice,
                @ExtTotal,
                @Notes,
                @IsTaxable,
                @OrgPrice,
                @DiscountPercent,
                @FactorToBase,
                NULL,  -- ParentSalesDetailId (ID translation deferred)
                NULL,  -- RootSalesDetailId (ID translation deferred)
                @CartLineType,
                @IsSystemManaged,
                @DisplaySort)

            SET @SalesDetailId=SCOPE_IDENTITY();

            INSERT INTO @IdMap (TempSalesId, SalesDetailId) VALUES (@TempSalesId_Current, @SalesDetailId);

            -- If It's Account Code
            IF @LineType='A'
		    BEGIN
                EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

                INSERT INTO TransactionJournalDetail
					    ([TxId]
					    ,[AccountId]
					    ,[PayeeId]
					    ,[Qty]
					    ,[Price]
					    ,[BillQty]
					    ,[Amount]
					    ,[CrDeAmount]
					    ,[SourceDetailId])
				    VALUES
					    (@TxId
					    ,@AccountId
					    ,@PayeeId
					    ,@BillQty
					    ,@UnitPrice
					    ,@ExtTotal
					    ,@ExtTotal -- amount
					    ,@CrDeAmount
					    ,@SalesDetailId)
            END
            ELSE
            BEGIN
                --For NonInventory Logic
                IF @ExtTotal<0
				    SET @AccountCode = '@ICREDIT'
			    ELSE
				    SET @AccountCode = '@ISALE'

                SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AccountCode
                EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

                IF @ItemType = 'NonInventory'
                BEGIN
                    INSERT INTO TransactionJournalDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
                        ,[Qty]
						,[Price]
						,[BillQty]
						,[Amount]
						,[CrDeAmount]
						,[SourceDetailId]
						,[InventoryQty])
				    VALUES
						(@TxId
						,@AccountId
						,@PayeeId
						,@ItemId
                        ,@BillQty
					    ,@UnitPrice
					    ,@ExtTotal
						,@ExtTotal -- amount
						,@CrDeAmount
						,@SalesDetailId
						,@BillQty*-1)
                END
                ELSE
                BEGIN
                    --If it's Inventory (ISALES, COGS, INV Account)
					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[Qty]
							,[Price]
							,[BillQty]
							,[Amount]
							,[CrDeAmount]
							,[SourceDetailId]
							,[FactorToBase]
							,[InventoryQty])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@BillQty
							,@UnitPrice
							,@ExtTotal
							,@ExtTotal -- amount
							,@CrDeAmount
							,@SalesDetailId
							,@FactorToBase
							,@BillQty*-1)

					--For COST OF GOOD SOLD account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[FactorToBase]
							,[SourceDetailId])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@FactorToBase
							,@SalesDetailId)

					--For Inventory account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[Qty]
							,[Price]
							,[BillQty]
							,[SourceDetailId]
							,[FactorToBase]
							,[InventoryQty])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@BaseShipQty
							,@UnitPrice
							,@BaseBillQty
							,@SalesDetailId
							,@FactorToBase
							,@BaseBillQty*-1)
                END
            END
        END
        ELSE IF @ChangeStatus = 'U'
        BEGIN
			-- Section 8c: updated row.
			-- Journal/detail behavior stays baseline: update SalesDetail, then
			-- update the existing journal rows for that source detail.
			INSERT INTO @IdMap (TempSalesId, SalesDetailId) VALUES (@TempSalesId_Current, @SalesDetailId);

			SET @ExtTotal= ROUND(@BillQty*@UnitPrice,2)

			UPDATE SalesDetail
			SET
				LineId            = @LineId,
				LineType          = @LineType,
				ItemId            = @ItemId,
				AccountId         = @AccountId,
				ItemUnitId        = @ItemUnitId,
				Unit              = @Unit,
				OrdQty            = @OrdQty,
				ShipQty           = @ShipQty,
				BillQty           = @BillQty,
				UnitPrice         = @UnitPrice,
				ExtTotal          = @ExtTotal,
				Notes             = @Notes,
				IsTaxable         = @IsTaxable,
				OrgPrice          = @OrgPrice,
				DiscountPercent   = @DiscountPercent,
				FactorToBase      = @FactorToBase,
				CartLineType      = @CartLineType,
				IsSystemManaged   = @IsSystemManaged,
				DisplaySort       = @DisplaySort
			FROM SalesDetail
			WHERE SalesDetailId = @SalesDetailId

			--if itemcode is changed then calculate old itemcode too
			SELECT TOP 1 @OldItemId=ItemId
			FROM TransactionJournalDetail
			WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId
			AND AccountId=(SELECT AccountId FROM @AcctTable WHERE AccountCode='@INV')

			IF @OldItemId!=@ItemId
				INSERT INTO RecalculationLog(ItemId,TxId,TxDate) VALUES(@OldItemId,@TxId,@ShipDate)

			-- If It's Account Code
			IF @LineType='A'
			BEGIN
				EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

				UPDATE TransactionJournalDetail SET
				Qty=@BillQty,
				Price=@UnitPrice,
				BillQty=@ExtTotal,
				Amount=@ExtTotal,
				CrDeAmount=@CrDeAmount,
				ItemId=@ItemId
				WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId
			END
			ELSE
			BEGIN
				 --For NonInventory Logic
				IF @ExtTotal<0
					SET @AccountCode = '@ICREDIT'
				ELSE
					SET @AccountCode = '@ISALE'

				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AccountCode
				EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

				-- Get the OLD account id from the existing row (must be either @ISALE or @ICREDIT)
				SELECT TOP (1) @OldAccountId = tjd.AccountId
				FROM TransactionJournalDetail tjd
				WHERE tjd.TxId = @TxId
				  AND tjd.SourceDetailId = @SalesDetailId
				  AND tjd.AccountId IN (
						(SELECT AccountId FROM @AcctTable WHERE AccountCode='@ISALE'),
						(SELECT AccountId FROM @AcctTable WHERE AccountCode='@ICREDIT')
				  );

				UPDATE TransactionJournalDetail SET
				Qty=@BillQty,
				Price=@UnitPrice,
				BillQty=@ExtTotal,
				Amount=@ExtTotal,
				CrDeAmount=@CrDeAmount,
				ItemId=@ItemId,
				AccountId=@AccountId,  --new accountid
				InventoryQty=@BillQty*-1,
				FactorToBase=@FactorToBase
				WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId AND AccountId=@OldAccountId

				IF @ItemType = 'Inventory'
				BEGIN
					---COGS
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					UPDATE TransactionJournalDetail SET ItemId=@ItemId,FactorToBase=@FactorToBase
					WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId AND AccountId=@AccountId

					---INV
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

					UPDATE TransactionJournalDetail SET
					Qty=@BaseShipQty,
					Price=@UnitPrice,
					BillQty=@BaseBillQty,
					ItemId=@ItemId,
					InventoryQty=@BaseBillQty*-1,
					FactorToBase=@FactorToBase
					WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId AND AccountId=@AccountId
				END
			END
        END
        ELSE IF @ChangeStatus = 'D'
        BEGIN
			-- Section 8d: deleted row.
			-- Delete the source detail row and its related journal rows.
            DELETE FROM SalesDetail WHERE SalesDetailId=@SalesDetailId

			DELETE FROM TransactionJournalDetail WHERE SourceDetailId=@SalesDetailId AND TxId=@TxId
        END

		SET @RowNum+=1
	END

	-- Section 9: translate parent/root temp ids for newly inserted rows only.
	-- Translate ParentTempSalesId/RootTempSalesId -> ParentSalesDetailId/RootSalesDetailId.
	UPDATE sd
	SET sd.ParentSalesDetailId = pmap.SalesDetailId,
		sd.RootSalesDetailId = ISNULL(rmap.SalesDetailId, pmap.SalesDetailId)
	FROM SalesDetail sd
	INNER JOIN @IdMap m ON m.SalesDetailId = sd.SalesDetailId
	INNER JOIN @TempSaleTable t ON t.TempSalesId = m.TempSalesId
	LEFT JOIN @IdMap pmap ON pmap.TempSalesId = t.ParentTempSalesId
	LEFT JOIN @IdMap rmap ON rmap.TempSalesId = t.RootTempSalesId
	WHERE t.ChangeStatus = 'I'
	  AND (t.ParentTempSalesId IS NOT NULL OR t.RootTempSalesId IS NOT NULL);

	INSERT INTO RecalculationLog(ItemId,TxId,TxDate)
	SELECT ItemId,@TxId,@ShipDate FROM @TempSaleTable WHERE ChangeStatus IS NOT NULL AND LineType='I'

	DECLARE @SalesTotal DECIMAL(18,2);
	DECLARE @TaxTotal DECIMAL(18,2);

	-- Section 10: keep only the 4 core header totals inline.
	-- Original flow called Sales_CalcTotal inside the transaction. We now keep
	-- only the journal-driving totals here so SalesTotal is correct at commit
	-- time while heavier/non-core recalculation runs after commit.
	SELECT @SubTotal = ISNULL(SUM(ROUND(BillQty*UnitPrice,2)),0)
	FROM SalesDetail WHERE SalesId=@SalesId

	SELECT @TaxableTotal = ISNULL(SUM(ROUND(BillQty*UnitPrice,2)),0)
	FROM SalesDetail WHERE SalesId=@SalesId AND IsTaxable=1

	SET @TaxTotal = ROUND(@TaxableTotal * @TaxPercent,2)
	SET @SalesTotal = @SubTotal + @TaxTotal

	UPDATE Sales SET
		SubTotal=@SubTotal,
		TaxTotal=@TaxTotal,
		TaxableTotal=@TaxableTotal,
		SalesTotal=@SalesTotal
	WHERE SalesId=@SalesId

	UPDATE Sales SET Updateby=@EmpId,UpdatedAt=GETUTCDATE() WHERE SalesId=@SalesId

	-- Section 11: refresh journal header rows such as @AR and optional tax.
	--update @AR account
	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AR'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@SalesTotal,@CrDeAmount OUTPUT

	UPDATE TransactionJournalDetail
	SET Amount=@SalesTotal,CrDeAmount=@CrDeAmount
	WHERE TxId=@TxId AND AccountId=@AccountId

	--insert and update sales tax account
	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@FSTP'

	IF @TaxTotal<>0
	BEGIN
		EXEC Fn_Adjust_CrDeAmount @AccountId,@TaxTotal,@CrDeAmount OUTPUT

		--check if sales tax account exist or not
		DECLARE @SalesTaxExist INT
		SELECT @SalesTaxExist=COUNT(*) FROM TransactionJournalDetail WHERE TxId=@TxId AND AccountId=@AccountId

		IF @SalesTaxExist=0
		BEGIN
			INSERT INTO [TransactionJournalDetail]
				([TxId]
				,[AccountId]
				,[Amount]
				,[CrDeAmount])
			VALUES
			   (@TxId
			   ,@AccountId
			   ,@TaxTotal
			   ,@CrDeAmount)
		END
		ELSE
			UPDATE TransactionJournalDetail SET Amount=@TaxTotal,CrDeAmount=@CrDeAmount
			WHERE TxId=@TxId AND AccountId=@AccountId
	END
	ELSE
		DELETE FROM TransactionJournalDetail WHERE TxId=@TxId AND AccountId=@AccountId

	-- Clean up TempSalesPromo links before deleting TempSales (FK constraint)
	DELETE tsp
	FROM TempSalesPromo tsp
	WHERE EXISTS (
		SELECT 1
		FROM TempSales ts
		WHERE ts.PayeeId = @PayeeId
		  AND ts.EmpId = @EmpId
		  AND ts.SalesId = @SalesId
		  AND (
				ts.TempSalesId = tsp.OwnerTempSalesId
			 OR ts.TempSalesId = tsp.PromoTempSalesId
		  )
	);

	DELETE TempSales WHERE PayeeId=@PayeeId AND EmpId=@EmpId AND SalesId=@SalesId

	COMMIT TRANSACTION

	-- Original flow did all recalculation work before commit.
	-- We intentionally move Sales_CalcTotal outside the transaction now
	-- because the core totals are already persisted above. This keeps
	-- AmountDue/due-date/aging/base-qty/FIFO/margin follow-up work out of
	-- the lock-heavy posting section.
	EXEC [Sales_CalcTotal] @SalesId,@SalesTotal OUTPUT
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION
		THROW
	END CATCH

END

