SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Purchase_CalcTotalAndPercent codex candidate
-- Baseline: live dbo.Purchase_CalcTotalAndPercent from KLS_Latest
--
-- Summary:
--   Goal: keep Purchase_CalcTotalAndPercent focused on post-posting follow-up
--   work after the core purchase/journal rows are already written.
--
-- Improvements:
--   1. Core totals and base qty no longer belong to this helper
--   2. The old helper-owned logic is kept as commented reference
--   3. This proc remains the owner of payment/due-date/aging/stage follow-up
--      and related maintenance after posting
--
-- What this proc still owns:
--   1. AmountDue / payment / discount follow-up
--   2. DueDate / aging / invoice aging refresh
--   3. Payee aging refresh
--   4. PO stage update
--   5. ItemUnit recent-cost refresh

CREATE OR ALTER PROCEDURE [dbo].[Purchase_CalcTotalAndPercent]
 
	@PurchaseId INT,
	@FinalTotal DECIMAL(18,2) OUTPUT
AS
BEGIN
	-- Section 1: initialize working variables for post-posting follow-up.
 
	SET NOCOUNT ON;
 
	--Calculate purchase total,aging,freight

	DECLARE @BillTotal DECIMAL(18,2);

	DECLARE @Aging INT=0;

	DECLARE @InvoiceAging INT=0;

	DECLARE @DueDate DATE;

	DECLARE @DiscDate DATE

	DECLARE @DiscRate DECIMAL(18,4)

	DECLARE @AmountDue DECIMAL(18,2);

	DECLARE @PaymentApplied DECIMAL(18,2);

	DECLARE @DiscountApplied DECIMAL(18,2);

	DECLARE @IsLocked BIT=0;	

	DECLARE @IsFreightOnly BIT=0

	DECLARE @FreightInside DECIMAL(18,2);

	DECLARE @CustomDutyInside DECIMAL(18,2);

	DECLARE @ArrivalDate DATE
	DECLARE @TermId INT;
	DECLARE @PayeeId INT

	-- Section 2: read current persisted purchase detail totals and header context.
	SELECT @BillTotal=ISNULL(SUM(ROUND((BillQty * BillPrice),2)),0),

	@FinalTotal=ISNULL(SUM(ROUND((FinalQty * FinalPrice),2)),0) 

	FROM PurchaseDetail WHERE PurchaseId=@PurchaseId



	SELECT 

	@ArrivalDate=ArrivalDate,

	@DueDate=DueDate,

	@TermId=TermId,

	@PayeeId=PayeeId

	FROM Purchase WHERE PurchaseId=@PurchaseId



	-- Section 3: refresh due date and aging from the purchase's own stored term
	-- and arrival date.
	IF @DueDate IS NULL

		EXEC Fn_Calc_DueDate @ArrivalDate,@TermId,@DueDate OUTPUT,@DiscDate OUTPUT,@DiscRate OUTPUT



	--Calculate Aging

	EXEC Fn_Calc_Aging @ArrivalDate,@PayeeId,@FinalTotal,@Aging OUTPUT,@InvoiceAging OUTPUT



	SELECT @FreightInside=SUM(ROUND(FinalQty*FinalPrice,2)) 

	FROM PurchaseDetail As pd inner join Account AS a ON a.AccountId=pd.AccountId 

	WHERE PurchaseId=@PurchaseId AND a.AccountCode in ('@COGSF','@INVC')



	SELECT @CustomDutyInside=SUM(ROUND(FinalQty*FinalPrice,2)) 

	FROM PurchaseDetail As pd inner join Account AS a ON a.AccountId=pd.AccountId 

	WHERE PurchaseId=@PurchaseId AND a.AccountCode='@CD'



	SET @IsFreightOnly =

	IIF(

      EXISTS (SELECT 1 FROM PurchaseDetail WHERE PurchaseId = @PurchaseId)

      AND NOT EXISTS (

          SELECT 1

          FROM PurchaseDetail pd

          LEFT JOIN Account a ON a.AccountId = pd.AccountId

          WHERE pd.PurchaseId = @PurchaseId

            AND (

                  pd.ItemId IS NOT NULL

                  OR a.AccountId IS NULL

				  OR a.AccountCode NOT IN ('@INVC')

                  --OR a.AccountCode NOT IN ('@COGSF', '@CD', '@INVC')

                )

		),

      1, 0

	);



	SELECT 

	@PaymentApplied = ISNULL(SUM(PaymentApplied), 0),

	@DiscountApplied = ISNULL(SUM(DiscountApplied), 0) 

	FROM VendorPaymentDetail WHERE PurchaseId = @PurchaseId;

		

	IF (@PaymentApplied!=0 OR @DiscountApplied!=0)

		SET @AmountDue=@FinalTotal-(@PaymentApplied+@DiscountApplied)

	ELSE

		SET @AmountDue=@FinalTotal



	-- Section 4: core totals and base-qty refresh are no longer owned here.
	-- Core totals and base-qty refresh are now owned by the posting procedures
	-- before journal creation/update. This helper remains for post-commit
	-- purchase follow-up fields and related maintenance only.
	--
	-- Legacy reference only. Original/live helper ownership included:
	--   VendorTotal = @BillTotal
	--   PurchaseTotal = @FinalTotal
	--   LineId renumber
	--   BaseReceiveQty = ROUND(ReceiveQty / FactorToBase, 6)
	--   BaseFinalQty   = ROUND(FinalQty / FactorToBase, 6)
	--
	-- UPDATE Purchase	SET
	-- 	VendorTotal=@BillTotal,
	-- 	PurchaseTotal=@FinalTotal,
	-- 	AmountDue=@AmountDue,
	-- 	PaymentApplied=@PaymentApplied,
	-- 	DiscountApplied=@DiscountApplied,
	-- 	Aging=@Aging,
	-- 	InvoiceAging=@InvoiceAging,
	-- 	DueDate=@DueDate,
	-- 	IsFreightOnly=@IsFreightOnly,
	-- 	UpdatedAt=GETUTCDATE()
	-- WHERE PurchaseId=@PurchaseId
	--
	-- ;WITH cte AS
	-- (
	-- 	SELECT *,
	-- 		   ROW_NUMBER() OVER (ORDER BY LineId) AS NewLineId
	-- 	FROM PurchaseDetail
	-- 	WHERE PurchaseId = @PurchaseId
	-- )
	-- UPDATE cte
	-- SET
	-- 	LineId = NewLineId,
	-- 	BaseReceiveQty = ROUND(ReceiveQty / FactorToBase, 6),
	-- 	BaseFinalQty   = ROUND(FinalQty / FactorToBase, 6);

	-- Section 5: write post-posting financial follow-up back to Purchase.
	UPDATE Purchase	SET 

		AmountDue=@AmountDue,

		PaymentApplied=@PaymentApplied,

		DiscountApplied=@DiscountApplied,

		Aging=@Aging,

		InvoiceAging=@InvoiceAging,

		DueDate=@DueDate,

		--FreightInside=@FreightInside,

		IsFreightOnly=@IsFreightOnly,

		--CustomDutyInside=@CustomDutyInside,

		UpdatedAt=GETUTCDATE()

	WHERE PurchaseId=@PurchaseId

	-- Calculate Duty Percent
	--;WITH duty AS

 --   (

 --       SELECT

	--		pd.PurchaseId,

 --           pd.PurchaseDetailId,

 --           pd.BaseFinalQty,

	--		Price = pd.FinalPrice,

	--		TempDuty = ROUND(

	--			pd.FinalPrice * 

	--			CAST(ISNULL(pd.CustomDutyRate,0) + ISNULL(pd.TariffPercent,0) AS decimal(18,6)),

	--		4),

	--		LineVolume = ROUND(pd.BaseFinalQty * pd.ItemVolume,4)

 --       FROM dbo.PurchaseDetail AS pd

 --       WHERE pd.PurchaseId = @PurchaseId AND pd.ItemId IS NOT NULL

 --   ),

 --   calc AS

	--(

	--	SELECT *,

	--		LineDuty = TempDuty*BaseFinalQty,

	--		TotalDuty = SUM(TempDuty*BaseFinalQty) OVER (PARTITION BY PurchaseId),

	--		TotalVolume = SUM(LineVolume) OVER (PARTITION BY PurchaseId)

	--	FROM duty

	--)



 --   UPDATE pd

 --   SET

 --       pd.DutySharePercent   = ROUND(c.LineDuty   / NULLIF(c.TotalDuty,   0), 4),

 --       pd.VolumeSharePercent = ROUND(c.LineVolume / NULLIF(c.TotalVolume, 0), 4)

 --   FROM dbo.PurchaseDetail AS pd

 --   JOIN calc AS c ON c.PurchaseDetailId = pd.PurchaseDetailId

	-- Section 6: run downstream follow-up still owned by this helper.
	EXEC [Payee_UpdateAging] @PayeeId,0

	-- Update stage
	UPDATE p
	SET StageId =
    CASE
		/* 6 - Billed : */
		WHEN StageId = 6 THEN 6

        /* 5 - Received : all lines received */
    
    WHEN NOT EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ReceiveQty IS NULL AND ItemId IS NOT NULL
        )
        THEN 5   -- Received

        /* 4 - Partially Received : some received */
        WHEN EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ReceiveQty IS NOT NULL AND ItemId IS NOT NULL
        )
        THEN 4   -- Partially Received

        /* 3 - Shipped : all lines shipped */
        WHEN NOT EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ShipQty IS NULL AND ItemId IS NOT NULL
        )
        THEN 3   -- Shipped

        /* 2 - Partially Shipped : some shipped */
        WHEN EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ShipQty IS NOT NULL AND ItemId IS NOT NULL
        )
        THEN 2   -- Partially Shipped

        /* 1 - Ordered */
        ELSE 1   -- Ordered
    END
	FROM Purchase p
	WHERE p.PurchaseId = @PurchaseId and IsStartFromPO=1;


	----Update ItemUnit RecentCost

	;WITH LatestCost AS


	(

		SELECT ItemId, TotalCost

		FROM dbo.View_PurchaseHistory

		WHERE RN = 1 AND PurchaseId = @PurchaseId

	)



	UPDATE iu

	SET iu.RecentCost = ROUND(lc.TotalCost / NULLIF(iu.FactorToBase, 0), 2)

	FROM dbo.ItemUnit iu

	INNER JOIN LatestCost lc ON lc.ItemId = iu.ItemId;

	-- End Summary:
	--   1. Core totals and base qty no longer belong to this helper.
	--   2. This proc owns AmountDue, due-date, aging, and related follow-up.
	--   3. PO stage refresh remains here.
	--   4. ItemUnit recent-cost refresh remains here.

END


