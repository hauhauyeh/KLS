
CREATE PROCEDURE [dbo].[PurchaseOrder_CopyToBill] --[PurchaseOrder_CopyToBill] 31,60,null
	
	@PurchaseId INT,
	@ItemsJson NVARCHAR(MAX),
	@EmpId INT,
	@ShipmentIds NVARCHAR(MAX),
	@OrderMode NVARCHAR(20) = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @PayeeId INT
	DECLARE @PurchaseNumber INT
	DECLARE @TxId BIGINT
	DECLARE @NormalizedOrderMode NVARCHAR(20) = LOWER(LTRIM(RTRIM(ISNULL(@OrderMode, 'original'))))

	SELECT @PayeeId=PayeeId, @PurchaseNumber=PurchaseNumber FROM Purchase WHERE PurchaseId=@PurchaseId

	DECLARE @Receivetable AS TABLE
	(
		SortId INT IDENTITY(1,1),
		PurchaseDetailId INT,
		ReceiveQty DECIMAL(18,2),
		ChangeStatus NVARCHAR(1)
	)

	INSERT INTO @Receivetable(PurchaseDetailId,ReceiveQty)
	SELECT *
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        PurchaseDetailId INT '$.PurchaseDetailId',
        ReceiveQty DECIMAL(18,2) '$.ReceiveQty'
    );

	-- Add items not sent in JSON as NULL (means "not received" / undo)
	INSERT INTO @Receivetable (PurchaseDetailId, ReceiveQty)
	SELECT pd.PurchaseDetailId, NULL
	FROM PurchaseDetail pd
	WHERE pd.PurchaseId = @PurchaseId
	  AND NOT EXISTS (
		  SELECT 1
		  FROM @Receivetable r
		  WHERE r.PurchaseDetailId = pd.PurchaseDetailId
	  );

	-- 1. update change status based on old and new receive qty
	UPDATE r SET r.ChangeStatus=
	CASE 
		WHEN pd.ReceiveQty IS NULL     AND r.ReceiveQty IS NOT NULL THEN 'I'
        WHEN pd.ReceiveQty IS NOT NULL AND r.ReceiveQty IS NOT NULL THEN 'U'
        WHEN pd.ReceiveQty IS NOT NULL AND r.ReceiveQty IS NULL     THEN 'D'
		ELSE r.ChangeStatus  -- both NULL (no change)
	END
	FROM PurchaseDetail AS pd
	INNER JOIN @Receivetable AS r
		ON pd.PurchaseDetailId = r.PurchaseDetailId
	WHERE pd.PurchaseId = @PurchaseId;

	-- 2026-04-20: copy-to-bill writes ReceiveQty / FinalQty directly on the PO
	-- detail before Purchase_PartialUpdate runs, so BaseReceiveQty / BaseFinalQty
	-- must be updated in the same statement to avoid stale PurchaseDetail values.
	UPDATE pd
	SET 
		ReceiveQty =
			CASE WHEN r.ReceiveQty IS NOT NULL THEN
					CASE 
						WHEN pd.IsFree = 1 THEN r.ReceiveQty
						WHEN pd.IsOut  = 1 THEN 0
						WHEN pd.IsCRCG = 1 THEN 0
						ELSE r.ReceiveQty
					END
				ELSE r.ReceiveQty
			END,
		FinalQty =
			CASE 
				WHEN r.ReceiveQty IS NOT NULL THEN
					CASE 
						WHEN pd.IsFree = 1 THEN 0
						WHEN pd.IsOut  = 1 THEN 0
						WHEN pd.IsCRCG = 1 THEN r.ReceiveQty
						ELSE r.ReceiveQty
					END
				ELSE r.ReceiveQty
			END,
		BaseReceiveQty =
			CASE
				WHEN
					CASE WHEN r.ReceiveQty IS NOT NULL THEN
							CASE
								WHEN pd.IsFree = 1 THEN r.ReceiveQty
								WHEN pd.IsOut  = 1 THEN 0
								WHEN pd.IsCRCG = 1 THEN 0
								ELSE r.ReceiveQty
							END
						ELSE r.ReceiveQty
					END IS NULL
					OR NULLIF(pd.FactorToBase, 0) IS NULL
				THEN NULL
				ELSE ROUND(
					(
						CASE WHEN r.ReceiveQty IS NOT NULL THEN
								CASE
									WHEN pd.IsFree = 1 THEN r.ReceiveQty
									WHEN pd.IsOut  = 1 THEN 0
									WHEN pd.IsCRCG = 1 THEN 0
									ELSE r.ReceiveQty
								END
							ELSE r.ReceiveQty
						END
					) / pd.FactorToBase, 6)
			END,
		BaseFinalQty =
			CASE
				WHEN
					CASE
						WHEN r.ReceiveQty IS NOT NULL THEN
							CASE
								WHEN pd.IsFree = 1 THEN 0
								WHEN pd.IsOut  = 1 THEN 0
								WHEN pd.IsCRCG = 1 THEN r.ReceiveQty
								ELSE r.ReceiveQty
							END
						ELSE r.ReceiveQty
					END IS NULL
					OR NULLIF(pd.FactorToBase, 0) IS NULL
				THEN NULL
				ELSE ROUND(
					(
						CASE
							WHEN r.ReceiveQty IS NOT NULL THEN
								CASE
									WHEN pd.IsFree = 1 THEN 0
									WHEN pd.IsOut  = 1 THEN 0
									WHEN pd.IsCRCG = 1 THEN r.ReceiveQty
									ELSE r.ReceiveQty
								END
							ELSE r.ReceiveQty
						END
					) / pd.FactorToBase, 6)
			END
	FROM PurchaseDetail AS pd
	INNER JOIN @Receivetable AS r
		ON pd.PurchaseDetailId = r.PurchaseDetailId
	WHERE pd.PurchaseId = @PurchaseId;

	--2. Update shipqty and billqty if is null
	UPDATE PurchaseDetail SET ShipQty = ReceiveQty, BillQty = FinalQty 
	WHERE PurchaseId = @PurchaseId AND ShipQty IS NULL

	--2. inject to temp cart
	EXEC [Purchase_Inject] @EmpId,@PayeeId,@PurchaseId,0

	--3. change temp cart change status based on recive table status
	UPDATE TempPurchase SET ChangeStatus=r.ChangeStatus
	FROM TempPurchase AS t
	INNER JOIN @Receivetable AS r
		ON t.PurchaseDetailId = r.PurchaseDetailId
	WHERE EmpId=@EmpId AND PurchaseId=@PurchaseId

	-- Save receive-list order into temp cart only when explicitly requested.
	IF @NormalizedOrderMode = 'new'
	BEGIN
		UPDATE t
		SET t.LineId = r.SortId
		FROM TempPurchase AS t
		INNER JOIN @Receivetable AS r
			ON t.PurchaseDetailId = r.PurchaseDetailId
		WHERE t.EmpId = @EmpId
		  AND t.PurchaseId = @PurchaseId;
	END

	---Update date 
	UPDATE Purchase SET ArrivalDate = GETDATE() WHERE PurchaseId = @PurchaseId
	SELECT @TxId = TxId
	FROM TransactionJournal WHERE SourceDocType = 'Purchase' AND SourceDocNumber = @PurchaseNumber
	UPDATE TransactionJournal SET TxDate = GETDATE() WHERE TxId = @TxId

	--4. IF Shipment asssign delete existing assign shipment
	UPDATE s SET Status = 'Draft' 
	FROM Shipment s 
	JOIN ShipmentPurchase as sp ON s.ShipmentId = sp.ShipmentId
	WHERE PurchaseId = @PurchaseId;

	DELETE FROM ShipmentPurchase WHERE PurchaseId = @PurchaseId;

	IF @ShipmentIds IS NOT NULL AND LTRIM(RTRIM(@ShipmentIds)) <> ''
	BEGIN
		INSERT INTO ShipmentPurchase (ShipmentId, PurchaseId)
		SELECT CAST(value AS INT) AS ShipmentId, @PurchaseId
		FROM STRING_SPLIT(@ShipmentIds, ',');

		UPDATE s SET Status = 'Assigned' 
		FROM Shipment s 
		JOIN STRING_SPLIT(@ShipmentIds, ',') as t ON s.ShipmentId = t.value
	END

	--5. 
	EXEC [Purchase_PartialUpdate] @PurchaseId,@EmpId,0
END

