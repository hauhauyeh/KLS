SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- KLS-4DP-B3-Purchase_PartialUpdate: 4-decimal pricing Section B Phase-1 (storage/type widen, inert).
--   Widen entered purchase-price carriers 2dp -> 4dp: params @BillPrice/@FinalPrice/@OrgPrice/@DefaultCost
--   and the local staging temp-table cols BillPrice/FinalPrice/OrgPrice (must widen together or the temp
--   re-truncates the param). Inert today: sources still <=2dp; money ROUND(qty*price,2) outputs unchanged.
--   @Discount stays DECIMAL(18,2) (discount amount = money, not a unit price).
CREATE OR ALTER PROCEDURE [dbo].[Purchase_PartialUpdate] -- EXEC [dbo].[Purchase_PartialUpdate] @PurchaseId=12983, @EmpId=1, @IsBill=1

	@PurchaseId INT,
	@EmpId INT,
	@IsBill BIT = 1
AS
BEGIN
	-- Section 1: initialize procedure state and working variables.
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @TxId BIGINT
	DECLARE @TxDate DATE
	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
	DECLARE @PurchaseNumber INT
	DECLARE @ArrivalDate DATE
	DECLARE @IsLocked BIT
	DECLARE @PayeeId int
	DECLARE @StageId INT
	DECLARE @LockResult INT
	DECLARE @LockResource NVARCHAR(200)
	DECLARE @BillTotal DECIMAL(18,2)
	DECLARE @FinalTotal DECIMAL(18,2);
	DECLARE @IsDropShip BIT = 0;
	DECLARE @DropShipSalesId INT;

	-- Section 2: load header and journal context for this purchase document.
	SELECT @PurchaseNumber=PurchaseNumber,
	@ArrivalDate=ArrivalDate,
	@IsLocked=IsLocked,
	@PayeeId=PayeeId,
	@StageId=StageId,
	@IsDropShip=ISNULL(IsDropShip, 0),
	@DropShipSalesId=DropShipSalesId
	FROM Purchase WHERE PurchaseId=@PurchaseId

	IF @PurchaseNumber IS NULL
	BEGIN
		RAISERROR('Purchase not found for Purchase_PartialUpdate.', 16, 1);
		RETURN;
	END

	--IF @IsLocked=1
	--BEGIN
	--	RAISERROR('This bill is already paid and locked.', 16, 1);
	--	RETURN;
	--END
	
	-- Section 3: declare per-row working variables for the update loop.
	DECLARE 
    @AutoId             INT,
    @LineId             INT,
    @LineType           NVARCHAR(1),
    @ItemId             INT,
    @AccountId          INT,
    @ItemUnitId         INT,
    @Unit               NVARCHAR(50),
    @Notes              NVARCHAR(255),
    @IsFree             BIT,
    @IsOut              BIT,
    @IsCRCG             BIT,
    @OrdQty0            DECIMAL(18, 2),
    @ShipQty            DECIMAL(18, 2),
    @BillQty            DECIMAL(18, 2),
    @OrdQty1            DECIMAL(18, 2),
    @ReceiveQty         DECIMAL(18, 2),
    @FinalQty           DECIMAL(18, 2),
    -- 4dp widen (entered bill price): was DECIMAL(18, 2)
    @BillPrice          DECIMAL(18, 4),
    @BillExtTotal       DECIMAL(18, 2),
    -- 4dp widen (entered final price): was DECIMAL(18, 2)
    @FinalPrice         DECIMAL(18, 4),
	@ImportCommission   DECIMAL(18, 2),
    @FinalExtTotal      DECIMAL(18, 2),
	@FactorToBase       DECIMAL(18, 6),
    @ExpiryDate         DATE, 
    @DiscountPercent    DECIMAL(18, 4),
    @Discount           DECIMAL(18, 2),
    -- 4dp widen (entered original price): was DECIMAL(18, 2)
    @OrgPrice           DECIMAL(18, 4),
    @CustomDutyRate     DECIMAL(18, 6),
	@TariffPercent     DECIMAL(9, 4),
    --@DutySharePercent   DECIMAL(18, 6),
    @ItemVolume         DECIMAL(18, 4),
    --@VolumeSharePercent DECIMAL(18, 6),
    @ChangeStatus       NVARCHAR(1),
    @PurchaseDetailId   INT;

    DECLARE @ExtTotal DECIMAL(18, 2)
	DECLARE @IsAccountDebit BIT
	DECLARE @X DECIMAL(18, 2)
	DECLARE @CrDeAmount DECIMAL(18, 2)
	DECLARE @ItemType NVARCHAR(100)
	-- 4dp widen (entered default cost; usages currently dead/commented - matches scope): was DECIMAL(18, 2)
	DECLARE @DefaultCost DECIMAL(18, 4)
	DECLARE @OldItemId INT
	DECLARE @AccountCode NVARCHAR(50)
	DECLARE @ConvertedPrice DECIMAL(18,6)
	DECLARE @BaseReceiveQty DECIMAL(18,6)
	DECLARE @BaseFinalQty DECIMAL(18,6)
	DECLARE @BaseMult INT               -- 2026-07-05 (Phase B): MultipleToBase from ItemUnit (base-qty source of truth)
	DECLARE @BaseFactor DECIMAL(18,6)   -- 2026-07-05 (Phase B): FactorToBase from ItemUnit, NOT the cart snapshot @FactorToBase

	-- Section 4: resolve the standard posting accounts used by the existing
	-- partial-update journal logic.
	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)

	INSERT INTO @AcctTable(AccountCode) VALUES('@AP')
	INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')
	INSERT INTO @AcctTable(AccountCode) VALUES('@DSCC')

	UPDATE t SET t.AccountId=a.AccountId
	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode

	-- Section 5: snapshot the full temp cart into a working table.
	-- Unlike the baseline, this intentionally loads all rows, not only
	-- ChangeStatus I/U/D rows, because unchanged surviving rows may still need
	-- their LineId written back after temp-cart resequencing.
	DECLARE @TempTable TABLE (
		[AutoId] [int] IDENTITY(1,1) NOT NULL,
		[LineId] [int] NULL,
		[LineType] [nvarchar](1) NOT NULL,
		[ItemId] [int] NULL,
		[AccountId] [int] NULL,
		[ItemUnitId] [int] NULL,
		[Unit] [nvarchar](50) NULL,
		[Notes] [nvarchar](255) NULL,
		[IsFree] [bit] NOT NULL,
		[IsOut] [bit] NOT NULL,
		[IsCRCG] [bit] NOT NULL,
		[OrdQty0] [decimal](18, 2) NULL,
		[ShipQty] [decimal](18, 2) NULL,
		[BillQty] [decimal](18, 2) NULL,
		[OrdQty1] [decimal](18, 2) NULL,
		[ReceiveQty] [decimal](18, 2) NULL,
		[FinalQty] [decimal](18, 2) NULL,
		-- 4dp widen (entered bill price; must match @BillPrice or re-truncates on read): was [decimal](18, 2)
		[BillPrice] [decimal](18, 4) NULL,
		[BillExtTotal] [decimal](18, 2) NULL,
		-- 4dp widen (entered final price; must match @FinalPrice): was [decimal](18, 2)
		[FinalPrice] [decimal](18, 4) NULL,
		[ImportCommission] [decimal](18, 2) NULL,
		[FinalExtTotal] [decimal](18, 2) NULL,
		[FactorToBase] [decimal](18, 6) NULL,
		[ExpiryDate] [date] NULL,
		[DiscountPercent] [decimal](18, 4) NULL,
		[Discount] [decimal](18, 2) NULL,
		-- 4dp widen (entered original price; must match @OrgPrice): was [decimal](18, 2)
		[OrgPrice] [decimal](18, 4) NULL,
		[CustomDutyRate] [decimal](18, 6) NULL,
		[TariffPercent] [decimal](9, 4) NULL,
		--[DutySharePercent] [decimal](18, 6) NULL,
		[ItemVolume] [decimal](18, 4) NULL,
		--[VolumeSharePercent] [decimal](18, 6) NULL,
		[ChangeStatus] [nvarchar](1) NULL,
		[PurchaseDetailId] [int] NULL,
		[ItemType] NVARCHAR(100) NULL
		--[DefaultCost] decimal(18, 2) NULL
	)

	INSERT INTO @TempTable
	SELECT [LineId]
      ,[LineType]
      ,t.[ItemId]
      ,[AccountId]
      ,[ItemUnitId]
      ,[Unit]
      ,t.[Notes]
      ,[IsFree]
      ,[IsOut]
      ,[IsCRCG]
      ,[OrdQty0]
      ,[ShipQty]
      ,[BillQty]
      ,[OrdQty1]
      ,[ReceiveQty]
      ,[FinalQty]
      ,[BillPrice]
      ,[BillExtTotal]
      ,[FinalPrice]
	  ,[ImportCommission]
      ,[FinalExtTotal]
	  ,[FactorToBase]
      ,t.[ExpiryDate]
      ,[DiscountPercent]
      ,[Discount]
      ,[OrgPrice]
      ,[CustomDutyRate]
	  ,[TariffPercent]
      --,[DutySharePercent]
      ,[ItemVolume]
      --,[VolumeSharePercent]
      ,[ChangeStatus]
      ,[PurchaseDetailId]
	  ,i.ItemType
	  --,i.DefaultCost
	FROM TempPurchase AS t LEFT JOIN Item as i on t.ItemId=i.ItemId
	WHERE EmpId=@EmpId AND PayeeId=@PayeeId AND PurchaseId=@PurchaseId

	SELECT @TxId=TxId,@TxDate=TxDate 
	FROM TransactionJournal WHERE SourceDocNumber=@PurchaseNumber AND SourceDocType='Purchase'

	IF @TxId IS NULL
	BEGIN
		RAISERROR('TransactionJournal not found for Purchase %d.', 16, 1, @PurchaseNumber);
		RETURN;
	END

	SELECT @MaxRow=COUNT(AutoId) FROM @TempTable

	BEGIN TRY
		-- Section 6: start the protected partial-update transaction.
		BEGIN TRANSACTION;

		SET @LockResource = 'Purchase_PartialUpdate_' + CAST(@PurchaseId AS NVARCHAR(50));

		EXEC @LockResult = sp_getapplock
			@Resource = @LockResource,
			@LockMode = 'Exclusive',
			@LockOwner = 'Transaction',
			@LockTimeout = 0;

		IF @LockResult < 0
		BEGIN
			RAISERROR('This purchase is already being updated.', 16, 1);
			RETURN;
		END

		-- 2026-08-01 DROPSHIP-BILL-BRANCH: converted drop-ship bills post product cost
		-- direct to @COGS/@AP and intentionally have no product @INV/@DSCC rows.
		-- Keep this branch price-only for V1; all normal inventory bill logic remains below.
		IF @IsDropShip = 1 AND @DropShipSalesId IS NOT NULL AND @StageId = 6
		BEGIN
			IF @IsBill <> 1
			BEGIN
				RAISERROR('Converted drop-ship bill updates must use bill update mode.', 16, 1);
				RETURN;
			END

			IF EXISTS (SELECT 1 FROM @TempTable WHERE ISNULL(ChangeStatus, '') IN ('I', 'D'))
			BEGIN
				RAISERROR('Converted drop-ship bill edit cannot add or delete lines.', 16, 1);
				RETURN;
			END

			IF EXISTS (SELECT 1 FROM @TempTable WHERE LineType <> 'I')
			BEGIN
				RAISERROR('Converted drop-ship bill edit does not support account lines in V1.', 16, 1);
				RETURN;
			END

			IF EXISTS
			(
				SELECT 1
				FROM @TempTable t
				LEFT JOIN PurchaseDetail pd ON pd.PurchaseDetailId = t.PurchaseDetailId
					AND pd.PurchaseId = @PurchaseId
				WHERE t.LineType = 'I'
				  AND pd.PurchaseDetailId IS NULL
			)
			BEGIN
				RAISERROR('Converted drop-ship bill edit has an invalid item line.', 16, 1);
				RETURN;
			END

			IF EXISTS
			(
				SELECT 1
				FROM @TempTable t
				INNER JOIN PurchaseDetail pd ON pd.PurchaseDetailId = t.PurchaseDetailId
				WHERE t.LineType = 'I'
				  AND pd.PurchaseId = @PurchaseId
				  AND ISNULL(t.LineId, -1) <> ISNULL(pd.LineId, -1)
			)
			BEGIN
				RAISERROR('Converted drop-ship bill edit cannot reorder item lines.', 16, 1);
				RETURN;
			END

			IF EXISTS
			(
				SELECT 1
				FROM @TempTable t
				INNER JOIN PurchaseDetail pd ON pd.PurchaseDetailId = t.PurchaseDetailId
				WHERE t.LineType = 'I'
				  AND pd.PurchaseId = @PurchaseId
				  AND ISNULL(t.ChangeStatus, '') = 'U'
				  AND
				  (
					  ISNULL(t.ItemId, -1) <> ISNULL(pd.ItemId, -1)
					  OR ISNULL(t.ItemUnitId, -1) <> ISNULL(pd.ItemUnitId, -1)
					  OR ISNULL(t.Unit, '') <> ISNULL(pd.Unit, '')
					  OR ISNULL(t.OrdQty0, 0) <> ISNULL(pd.OrdQty0, 0)
					  OR ISNULL(t.ShipQty, 0) <> ISNULL(pd.ShipQty, 0)
					  OR ISNULL(t.BillQty, 0) <> ISNULL(pd.BillQty, 0)
					  OR ISNULL(t.OrdQty1, 0) <> ISNULL(pd.OrdQty1, 0)
					  OR ISNULL(t.ReceiveQty, 0) <> ISNULL(pd.ReceiveQty, 0)
					  OR ISNULL(t.FinalQty, 0) <> ISNULL(pd.FinalQty, 0)
				  )
			)
			BEGIN
				RAISERROR('Converted drop-ship bill edit is price-only for item lines.', 16, 1);
				RETURN;
			END

			IF EXISTS
			(
				SELECT 1
				FROM TransactionJournalDetail tjd
				INNER JOIN Account a ON a.AccountId = tjd.AccountId
				INNER JOIN PurchaseDetail pd ON pd.PurchaseDetailId = tjd.SourceDetailId
				WHERE tjd.TxId = @TxId
				  AND pd.PurchaseId = @PurchaseId
				  AND a.AccountCode IN ('@INV', '@DSCC')
			)
			BEGIN
				RAISERROR('Converted drop-ship bill journal has unexpected product @INV or @DSCC rows.', 16, 1);
				RETURN;
			END

			UPDATE pd
			SET
				BillPrice = t.BillPrice,
				BillExtTotal = ROUND(ISNULL(pd.BillQty, 0) * ISNULL(t.BillPrice, 0), 2),
				FinalPrice = t.FinalPrice,
				FinalExtTotal = ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(t.FinalPrice, 0), 2)
			FROM PurchaseDetail pd
			INNER JOIN @TempTable t ON t.PurchaseDetailId = pd.PurchaseDetailId
			WHERE pd.PurchaseId = @PurchaseId
			  AND t.LineType = 'I'
			  AND ISNULL(t.ChangeStatus, '') = 'U';

			SELECT
				@BillTotal = ISNULL(SUM(ROUND(BillQty * BillPrice, 2)), 0),
				@FinalTotal = ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
			FROM PurchaseDetail
			WHERE PurchaseId = @PurchaseId;

			UPDATE Purchase
			SET
				VendorTotal = @BillTotal,
				PurchaseTotal = @FinalTotal,
				UpdatedAt = GETUTCDATE()
			WHERE PurchaseId = @PurchaseId;

			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AP'
			EXEC Fn_Adjust_CrDeAmount @AccountId,@FinalTotal,@CrDeAmount OUTPUT

			UPDATE TransactionJournalDetail
			SET Amount=@FinalTotal,CrDeAmount=@CrDeAmount
			WHERE TxId=@TxId AND AccountId=@AccountId

			IF @@ROWCOUNT <> 1
			BEGIN
				RAISERROR('Converted drop-ship bill journal must have exactly one @AP row.', 16, 1);
				RETURN;
			END

			DECLARE @ExpectedCogsRows INT;
			DECLARE @UpdatedCogsRows INT;

			SELECT @ExpectedCogsRows = COUNT(1)
			FROM PurchaseDetail
			WHERE PurchaseId = @PurchaseId
			  AND LineType <> 'A'
			  AND ItemId IS NOT NULL;

			;WITH CogsRows AS
			(
				SELECT
					pd.PurchaseDetailId,
					pd.ItemId,
					pd.FinalQty,
					pd.FinalPrice,
					pd.FactorToBase,
					cogs.AccountId,
					ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2) AS Amount,
					crde.CrDeAmount
				FROM PurchaseDetail pd
				CROSS APPLY (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@COGS') cogs
				CROSS APPLY dbo.Fn_CrDeAmount
				(
					CONVERT(NVARCHAR(20), cogs.AccountId),
					ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
				) crde
				WHERE pd.PurchaseId = @PurchaseId
				  AND pd.LineType <> 'A'
				  AND pd.ItemId IS NOT NULL
			)
			UPDATE tjd
			SET
				tjd.ItemId = c.ItemId,
				tjd.Qty = c.FinalQty,
				tjd.Price = c.FinalPrice,
				tjd.BillQty = c.FinalQty,
				tjd.FactorToBase = c.FactorToBase,
				tjd.Amount = c.Amount,
				tjd.CrDeAmount = c.CrDeAmount
			FROM TransactionJournalDetail tjd
			INNER JOIN CogsRows c ON c.PurchaseDetailId = tjd.SourceDetailId
				AND c.AccountId = tjd.AccountId
			WHERE tjd.TxId = @TxId;

			SET @UpdatedCogsRows = @@ROWCOUNT;

			IF @UpdatedCogsRows <> @ExpectedCogsRows
			BEGIN
				RAISERROR('Converted drop-ship bill journal @COGS rows do not match item lines.', 16, 1);
				RETURN;
			END

			IF ABS((SELECT ISNULL(SUM(CrDeAmount), 0) FROM TransactionJournalDetail WHERE TxId = @TxId)) >= 0.01
			BEGIN
				RAISERROR('Converted drop-ship bill purchase journal is not balanced after update.', 16, 1);
				RETURN;
			END

			DELETE TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId AND PurchaseId=@PurchaseId

			COMMIT TRANSACTION;

			EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT
			EXEC [Shipment_Allocation] @PurchaseId,null
			EXEC [Shipment_AllocationInventoryClear] @PurchaseId

			RETURN;
		END

		-- Section 7: trust temp-cart-owned LineId.
		-- TempPurchase.LineId is already kept correct by the TempPurchase triggers.
		-- Do not renumber again here. Purchase_PartialUpdate should write that
		-- final cart order back into PurchaseDetail, including unchanged
		-- surviving rows.
		

		-- Section 8: process the working cart one row at a time.
		-- Important behavioral rule:
		--   NULL status -> only persist the current LineId to PurchaseDetail
		--   I/U/D       -> keep the same baseline journal/detail branches
		WHILE @RowNum <= @MaxRow
		BEGIN
        SELECT
            @LineId             = LineId,
            @LineType           = LineType,
            @ItemId             = ItemId,
            @AccountId          = AccountId,
            @ItemUnitId         = ItemUnitId,
            @Unit               = Unit,
            @Notes              = Notes,
            @IsFree             = IsFree,
            @IsOut              = IsOut,
            @IsCRCG             = IsCRCG,
            @OrdQty0            = OrdQty0,
            @ShipQty            = ShipQty,
            @BillQty            = BillQty,
            @OrdQty1            = OrdQty1,
            @ReceiveQty         = ReceiveQty,
            @FinalQty           = FinalQty,
            @BillPrice          = BillPrice,
            @BillExtTotal       = BillExtTotal,
            @FinalPrice         = FinalPrice,
			@ImportCommission   = ImportCommission,
            @FinalExtTotal      = FinalExtTotal,
			-- 2026-04-20: Base qty must be recomputed here because the narrowed
			-- calc follow-up no longer repairs PurchaseDetail after partial update.
			-- 2026-07-05 (Phase B): base qty now derives from ItemUnitId -> ItemUnit via the scalar
			-- SUBQUERY block right after this SELECT (below WHERE AutoId), NOT the FactorToBase snapshot.
			-- Prior inline compute retired:
			-- @BaseReceiveQty     = CASE
			--                         WHEN ReceiveQty IS NULL OR NULLIF(FactorToBase, 0) IS NULL THEN NULL
			--                         ELSE ROUND(ReceiveQty / FactorToBase, 6)
			--                      END,
			-- @BaseFinalQty       = CASE
			--                         WHEN FinalQty IS NULL OR NULLIF(FactorToBase, 0) IS NULL THEN NULL
			--                         ELSE ROUND(FinalQty / FactorToBase, 6)
			--                      END,
			@FactorToBase       = FactorToBase,
            @ExpiryDate         = ExpiryDate,
            @DiscountPercent    = DiscountPercent,
            @Discount           = Discount,
            @OrgPrice           = OrgPrice,
            @CustomDutyRate     = CustomDutyRate,
			@TariffPercent      = TariffPercent,
            --@DutySharePercent   = DutySharePercent,
            @ItemVolume         = ItemVolume,
            --@VolumeSharePercent = VolumeSharePercent,
            @ChangeStatus       = ChangeStatus,
            @PurchaseDetailId   = PurchaseDetailId,
			@ItemType			= ItemType
			--@DefaultCost		=DefaultCost
        FROM @TempTable
        WHERE AutoId = @RowNum;

        -- 2026-07-05 (Phase B): base qty from ItemUnitId -> ItemUnit (Fn_QtyToBase), qty-only.
        -- Scalar SUBQUERY form: NULL if @ItemUnitId doesn't resolve (account line / orphan) ->
        -- Fn_QtyToBase carries it to NULL. Do NOT use 'SELECT @x = col FROM ItemUnit WHERE...'
        -- (keeps the PREVIOUS row on no-match). @FactorToBase (snapshot, above) is unchanged --
        -- it still feeds the @COGS journal FactorToBase column.
        -- 2026-07-07 (Effort-B) SUPERSEDES the old note here ("it still feeds the @INV price + journal
        -- FactorToBase column (price threading deferred)"): the @INV rows now DROP the @FactorToBase price
        -- conversion (entered @FinalPrice), BillQty -> @FinalQty, and the @INV FactorToBase slot -> @ReceiveQty.
        SET @BaseMult       = (SELECT MultipleToBase FROM ItemUnit WHERE ItemUnitId = @ItemUnitId);
        SET @BaseFactor     = (SELECT FactorToBase   FROM ItemUnit WHERE ItemUnitId = @ItemUnitId);
        SET @BaseReceiveQty = dbo.Fn_QtyToBase(@ReceiveQty, @BaseMult, @BaseFactor);
        SET @BaseFinalQty   = dbo.Fn_QtyToBase(@FinalQty,   @BaseMult, @BaseFactor);

        SET @ExtTotal= ROUND(@FinalQty*@FinalPrice,2)

        IF ISNULL(@ChangeStatus, '') = ''
        BEGIN
			-- Section 8a: unchanged surviving row.
			-- Baseline would ignore this row entirely. We now still persist
			-- LineId so PurchaseDetail stays aligned with the current temp-cart order.
			UPDATE PurchaseDetail
			SET LineId = @LineId
			WHERE PurchaseDetailId = @PurchaseDetailId;
        END
        ELSE IF @ChangeStatus='I'
        BEGIN
			-- Section 8b: inserted row.
			-- When @IsBill = 1, insert a new PurchaseDetail row. When @IsBill = 0
			-- (PO-to-bill path), reuse the existing PurchaseDetail row, persist
			-- temp-cart order back to the PO detail LineId, and only create the
			-- corresponding journal rows.
			IF @IsBill = 1 --If bill then insert to source otherwise for PO the source detail is already there 
			BEGIN
				-- 2026-04-20: Keep PurchaseDetail base qty columns in sync at insert time.
				INSERT INTO [dbo].[PurchaseDetail]
				   ([PurchaseId]
				   ,[LineId]
				   ,[LineType]
				   ,[ItemId]
				   ,[AccountId]
				   ,[ItemUnitId]
				   ,[Unit]
				   ,[Notes]
				   ,[IsFree]
				   ,[IsOut]
				   ,[IsCRCG]
				   ,[OrdQty0]
				   ,[ShipQty]
				   ,[BillQty]
				   ,[OrdQty1]
				   ,[ReceiveQty]
				   ,[FinalQty]
				   ,[BaseReceiveQty]
				   ,[BaseFinalQty]
				   ,[BillPrice]
				   ,[BillExtTotal]
				   ,[FinalPrice]
				   ,[ImportCommission]
				   ,[FinalExtTotal]
				   ,[FactorToBase]
				   ,[ExpiryDate]
				   ,[DiscountPercent]
				   ,[Discount]
				   ,[OrgPrice]
				   ,[CustomDutyRate]
				   ,[TariffPercent]
				   ,[ItemVolume])
				VALUES
				   (@PurchaseId
				   ,@LineId
				   ,@LineType
				   ,@ItemId
				   ,@AccountId
				   ,@ItemUnitId
				   ,@Unit
				   ,@Notes
				   ,@IsFree
				   ,@IsOut
				   ,@IsCRCG
				   ,@OrdQty0
				   ,@ShipQty
				   ,@BillQty
				   ,@OrdQty1
				   ,@ReceiveQty
				   ,@FinalQty
				   ,@BaseReceiveQty
				   ,@BaseFinalQty
				   ,@BillPrice
				   ,@BillExtTotal
				   ,@FinalPrice
				   ,@ImportCommission
				   ,@FinalExtTotal
				   ,@FactorToBase
				   ,@ExpiryDate
				   ,@DiscountPercent
				   ,@Discount
				   ,@OrgPrice
				   ,@CustomDutyRate
				   ,@TariffPercent
				   ,@ItemVolume);

				SET @PurchaseDetailId=SCOPE_IDENTITY();
			END
			ELSE
			BEGIN
				-- 2026-04-20: PO-to-bill can reuse an existing detail row while changing
				-- receive/final qty, so persist base qty and factor here too.
				UPDATE PurchaseDetail
				SET LineId         = @LineId,
					ReceiveQty     = @ReceiveQty,
					FinalQty       = @FinalQty,
					BillQty        = @BillQty,
					BaseReceiveQty = @BaseReceiveQty,
					BaseFinalQty   = @BaseFinalQty,
					FactorToBase   = @FactorToBase
				WHERE PurchaseDetailId = @PurchaseDetailId
			END

            -- If It's Account Code
			IF @LineType='A'
			BEGIN
				-- SELECT @IsAccountDebit=IsAccountDebit FROM Account AS C WHERE AccountId=@AccountId
				--
				-- IF @IsAccountDebit=1
				-- 	SET @X = @ExtTotal
				-- ELSE
				-- 	SET @X = -@ExtTotal
				-- 2026-07-15: Amount is the business amount; CrDeAmount derives posting sign.
				SET @X = @ExtTotal

				EXEC Fn_Adjust_CrDeAmount @AccountId,@X,@CrDeAmount OUTPUT

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
						,@FinalQty
						,@FinalPrice
						,ABS(@X)
						,@X -- amount
						,@CrDeAmount
						,@PurchaseDetailId)
			END
			ELSE
			BEGIN
				--For NonInventory Logic
				IF @ItemType = 'NonInventory'
				BEGIN
					--For COGS account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
					EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[Amount]
							,[CrDeAmount]
							,[SourceDetailId])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@ExtTotal -- amount
							,@CrDeAmount
							,@PurchaseDetailId)
				END
				ELSE
				BEGIN
					--Convert Inventory Qty

					--We already convert BaseQty now convert Price
					SET @ConvertedPrice = @FinalPrice  -- 2026-07-07 Effort-B: entered goods price; was ROUND(@FinalPrice * @FactorToBase,6) (x @FactorToBase dropped; landed added at billing by InventoryClear)

					--Account = '@COGS'
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]	
							,[Amount]
							,[CrDeAmount]
							,[SourceDetailId]
							,[FactorToBase])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,0 -- amount
							,0 --@CrDeAmt
							,@PurchaseDetailId
							,@FactorToBase)

					--Account = '@INV'
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
							,[FactorToBase])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@BaseReceiveQty
							,@ConvertedPrice
							-- 2026-07-07 Effort-B: BillQty base->entered.  OLD: ,@BaseFinalQty
							,@FinalQty
							,@PurchaseDetailId
							-- 2026-07-07 Effort-B: FactorToBase slot ratio->EntQty.  OLD: ,@FactorToBase)
							,@ReceiveQty)
				END
			END
        END
        ELSE IF @ChangeStatus='U'
        BEGIN
			-- Section 8c: updated row.
			-- When @IsBill = 1, update the source detail row. When @IsBill = 0,
			-- the source detail is already updated by the PO-to-bill path, so this
			-- branch must still persist LineId back to PurchaseDetail before
			-- updating the journal rows.
			IF @IsBill = 1 --If bill then update to source otherwise for PO the source already updated 
			BEGIN
				UPDATE PurchaseDetail
				SET  ItemUnitId        = @ItemUnitId
					,LineId            = @LineId
					,[Unit]            = @Unit
					,Notes             = @Notes
					,IsFree            = @IsFree
					,IsOut             = @IsOut
					,IsCRCG            = @IsCRCG
					,OrdQty0           = @OrdQty0
					,ShipQty           = @ShipQty
					,BillQty           = @BillQty
					,OrdQty1           = @OrdQty1
					,ReceiveQty        = @ReceiveQty
					,FinalQty          = @FinalQty
					,BaseReceiveQty    = @BaseReceiveQty
					,BaseFinalQty      = @BaseFinalQty
					,BillPrice         = @BillPrice
					,BillExtTotal      = @BillExtTotal
					,FinalPrice        = @FinalPrice
					,ImportCommission  = @ImportCommission
					,FinalExtTotal     = @FinalExtTotal
					,FactorToBase	   = @FactorToBase
					,ExpiryDate        = @ExpiryDate
					,DiscountPercent   = @DiscountPercent
					,Discount          = @Discount
					,OrgPrice          = @OrgPrice
					,CustomDutyRate    = @CustomDutyRate
					,TariffPercent     = @TariffPercent
					,ItemVolume        = @ItemVolume
				WHERE PurchaseDetailId   = @PurchaseDetailId;
			END
			ELSE
			BEGIN
				-- 2026-04-20: When qty or factor changes on update, base qty must change
				-- in the same write so PurchaseDetail does not drift from journal detail.
				UPDATE PurchaseDetail
				SET LineId         = @LineId,
					ReceiveQty     = @ReceiveQty,
					FinalQty       = @FinalQty,
					BillQty        = @BillQty,
					BaseReceiveQty = @BaseReceiveQty,
					BaseFinalQty   = @BaseFinalQty,
					FactorToBase   = @FactorToBase
				WHERE PurchaseDetailId = @PurchaseDetailId
			END

			--if itemcode is changed then calculate old itemcode too
			SELECT TOP 1 @OldItemId=ItemId 
			FROM TransactionJournalDetail 
			WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId 
			AND AccountId=(SELECT AccountId FROM @AcctTable WHERE AccountCode='@INV')

			IF @OldItemId!=@ItemId
				INSERT INTO RecalculationLog(ItemId,TxId,TxDate) VALUES(@OldItemId,@TxId,@TxDate)

			-- If It's Account Code
			IF @LineType='A'
			BEGIN
				-- SELECT @IsAccountDebit=IsAccountDebit FROM Account AS C WHERE AccountId=@AccountId
				--
				-- IF @IsAccountDebit=1
				-- 	SET @X = @ExtTotal
				-- ELSE
				-- 	SET @X = -@ExtTotal
				-- 2026-07-15: Amount is the business amount; CrDeAmount derives posting sign.
				SET @X = @ExtTotal

				EXEC Fn_Adjust_CrDeAmount @AccountId,@X,@CrDeAmount OUTPUT

				UPDATE TransactionJournalDetail SET 
				Qty=@FinalQty,
				Price=@FinalPrice,
				BillQty=ABS(@X),
				Amount=@X,
				CrDeAmount=@CrDeAmount,
				ItemId=@ItemId
				WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId
			END
			ELSE
			BEGIN
				--For NonInventory Logic
				IF @ItemType = 'NonInventory'
				BEGIN
					--For COGS account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
					EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

					UPDATE TransactionJournalDetail 
					SET Amount=@ExtTotal,
					CrDeAmount=@CrDeAmount 
					WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId
				END
				ELSE
				BEGIN
					--Convert Inventory Qty
					
					--We already convert BaseQty now convert Price
					SET @ConvertedPrice = @FinalPrice  -- 2026-07-07 Effort-B: entered goods price; was ROUND(@FinalPrice * @FactorToBase,6) (x @FactorToBase dropped; landed added at billing by InventoryClear)

					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					UPDATE TransactionJournalDetail 
					SET ItemId=@ItemId,
					FactorToBase=@FactorToBase 
					WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId AND AccountId=@AccountId

					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

					UPDATE TransactionJournalDetail 
					SET Qty=@BaseReceiveQty,
					Price=@ConvertedPrice,
					-- 2026-07-07 Effort-B: BillQty base->entered.  OLD: BillQty=@BaseFinalQty,
					BillQty=@FinalQty,
					ItemId=@ItemId,
					-- 2026-07-07 Effort-B: FactorToBase slot ratio->EntQty.  OLD: FactorToBase=@FactorToBase
					FactorToBase=@ReceiveQty
					WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId AND AccountId=@AccountId

				END
			END
        END
        ELSE IF @ChangeStatus='D'
        BEGIN
			-- Section 8d: deleted row.
			-- When @IsBill = 1, delete the source detail row and its journal rows.
			-- When @IsBill = 0, the source detail stays in the PO, but the bill
			-- journal rows for that source detail are removed. Persist LineId
			-- back to the PO row as well so reordered receive edits do not leave
			-- stale or duplicate PurchaseDetail line numbers.
			IF @IsBill = 1 --If bill then delete otherwise for PO the source detail remains
			BEGIN
				DELETE FROM ShipmentAllocation WHERE PurchaseDetailId = @PurchaseDetailId
				DELETE FROM PurchaseDetail WHERE PurchaseDetailId = @PurchaseDetailId
			END
			ELSE
			BEGIN
				-- 2026-04-20: Even in @IsBill = 0 reuse mode, keep qty/base-qty columns
				-- aligned on the source detail row instead of only updating LineId.
				UPDATE PurchaseDetail
				SET LineId = @LineId
				WHERE PurchaseDetailId = @PurchaseDetailId
			END

			DELETE FROM TransactionJournalDetail WHERE SourceDetailId=@PurchaseDetailId AND TxId=@TxId
        END

			SET @RowNum += 1 
		END

	--INSERT INTO RecalculationLog(ItemId,TxId,TxDate)
	--SELECT ItemId,@TxId,@TxDate FROM @TempTable WHERE ChangeStatus IS NOT NULL AND LineType='I'

	-- Section 8e (2026-07-05, Phase B): ItemUnit-consistent base qty for ALL rows of this purchase,
	-- including unchanged survivors the loop only re-LineId'd. Set-based (no loop stale-var concern);
	-- INNER JOIN = item lines only; account lines (no ItemUnitId) keep their base qty (feed no @INV).
	-- Parity with Sales_PartialUpdate; no-op today (all Mult=1), forward-correct for combine-up.
	UPDATE pd
	SET pd.BaseReceiveQty = dbo.Fn_QtyToBase(pd.ReceiveQty, iu.MultipleToBase, iu.FactorToBase),
	    pd.BaseFinalQty   = dbo.Fn_QtyToBase(pd.FinalQty,   iu.MultipleToBase, iu.FactorToBase)
	FROM PurchaseDetail pd
	INNER JOIN ItemUnit iu ON iu.ItemUnitId = pd.ItemUnitId
	WHERE pd.PurchaseId = @PurchaseId;

	-- Section 9: refresh only the journal-driving header totals inline.
	-- update source table
	SELECT
		@BillTotal = ISNULL(SUM(ROUND(BillQty * BillPrice, 2)), 0),
		@FinalTotal = ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
	FROM PurchaseDetail
	WHERE PurchaseId = @PurchaseId;

	UPDATE Purchase
	SET
		VendorTotal = @BillTotal,
		PurchaseTotal = @FinalTotal,
		UpdatedAt = GETUTCDATE()
	WHERE PurchaseId = @PurchaseId;

	--update @AP account
	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AP'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@FinalTotal,@CrDeAmount OUTPUT

	UPDATE TransactionJournalDetail 
	SET Amount=@FinalTotal,CrDeAmount=@CrDeAmount 
	WHERE TxId=@TxId AND AccountId=@AccountId

	DELETE TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId AND PurchaseId=@PurchaseId

	COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH

	-- Section 10: run post-commit follow-up in the final intended order.
	-- Reordered from the original flow:
	-- Recalc enqueue now happens immediately after commit, before helper and
	-- shipment-allocation follow-up. Reason:
	-- 1. queue reliability should not depend on later post-commit success
	-- 2. this avoids using stale pre-helper StageId for the enqueue decision
	-- 3. inventory recalculation should not be skipped just because later
	--    shipment/allocation work fails
	--EXEC Recalc_AfterInsert @TxId,@ArrivalDate

	INSERT INTO RecalculationLog(ItemId,TxId,TxDate)
	SELECT ItemId,@TxId,@ArrivalDate FROM @TempTable WHERE ChangeStatus IS NOT NULL AND LineType='I'

	EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT

	EXEC [Shipment_Allocation] @PurchaseId,null
	EXEC [Shipment_AllocationInventoryClear] @PurchaseId

	-- End Summary:
	--   1. TempPurchase.LineId is the canonical cart order; this proc does not renumber it.
	--   2. All temp rows are loaded so unchanged surviving lines can also persist
	--      current LineId back to PurchaseDetail.
	--   3. NULL-status rows only update LineId.
	--   4. I/U/D branches keep the same baseline journal/detail behavior.
	--   5. @IsBill = 0 still reuses existing PurchaseDetail rows while creating,
	--      updating, or deleting the bill-side journal rows.
END
