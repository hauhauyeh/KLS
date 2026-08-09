-- SCR_C_FK_UNASSIGN_20260710: per-bill redesign - BLOCK CopyToBill (PO->bill receive) if this purchase is
-- already in a shipment with per-bill split charges or a generated shipment bill (must unassign via the
-- shipment workflow first). Plus a defensive per-bill ShipmentCharge delete before the ShipmentPurchase
-- delete (normally 0 rows given the guard) so FK_ShipmentCharge_ShipmentPurchase can't block it.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-09 PO-BILL-REFS: require and persist V-Doc#/CONT# before normal PO CopyToBill.
CREATE OR ALTER PROCEDURE [dbo].[PurchaseOrder_CopyToBill] -- EXEC dbo.PurchaseOrder_CopyToBill @PurchaseId=31,@ItemsJson=N'[]',@EmpId=60,@ShipmentIds=NULL,@OrderMode=N'original',@VendorDocNumber=N'VDOC',@ContainerNumber=N'CONT'
    @PurchaseId INT,
    @ItemsJson NVARCHAR(MAX),
    @EmpId INT,
    @ShipmentIds NVARCHAR(MAX),
    @OrderMode NVARCHAR(20) = NULL,
    @VendorDocNumber NVARCHAR(100) = NULL,
    @ContainerNumber NVARCHAR(100) = NULL
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    DECLARE @PayeeId INT
    DECLARE @PurchaseNumber INT
    DECLARE @TxId BIGINT
    DECLARE @IsDropShip BIT
    DECLARE @DropShipSalesId INT
    DECLARE @FinalVendorDocNumber NVARCHAR(100)
    DECLARE @FinalContainerNumber NVARCHAR(100)
    DECLARE @NormalizedOrderMode NVARCHAR(20) = LOWER(LTRIM(RTRIM(ISNULL(@OrderMode, 'original'))))

    SELECT
        @PayeeId = PayeeId,
        @PurchaseNumber = PurchaseNumber,
        @IsDropShip = ISNULL(IsDropShip, 0),
        @DropShipSalesId = DropShipSalesId,
        @FinalVendorDocNumber = COALESCE(
            NULLIF(UPPER(LTRIM(RTRIM(@VendorDocNumber))), ''),
            NULLIF(UPPER(LTRIM(RTRIM(VendorDocNumber))), '')
        ),
        @FinalContainerNumber = COALESCE(
            NULLIF(UPPER(LTRIM(RTRIM(@ContainerNumber))), ''),
            NULLIF(UPPER(LTRIM(RTRIM(ContainerNumber))), '')
        )
    FROM Purchase
    WHERE PurchaseId = @PurchaseId

    IF @PurchaseNumber IS NULL
    BEGIN
        RAISERROR('Purchase order not found for CopyToBill.', 16, 1);
        RETURN;
    END

    IF @IsDropShip = 1 OR @DropShipSalesId IS NOT NULL
    BEGIN
        RAISERROR('Drop-ship PO must be received from Order Manager.', 16, 1);
        RETURN;
    END

    IF @FinalVendorDocNumber IS NULL
    BEGIN
        RAISERROR('V-Doc# is required before receiving PO to Bill.', 16, 1);
        RETURN;
    END

    IF @FinalContainerNumber IS NULL
    BEGIN
        RAISERROR('CONT# is required before receiving PO to Bill.', 16, 1);
        RETURN;
    END

    -- SCR_C_FK_UNASSIGN_20260710: CopyToBill is the PO->bill receive/convert path and must run BEFORE the
    -- freight-split / shipment-bill-generation workflow. If this purchase is already in a shipment that has
    -- per-bill split charges OR a generated consolidated shipment bill, block reassignment here (fail BEFORE
    -- any mutation) - the user must unassign via the shipment workflow first.
    IF EXISTS (SELECT 1 FROM dbo.ShipmentCharge sc
               WHERE sc.ShipmentPurchaseId IN (SELECT ShipmentPurchaseId FROM dbo.ShipmentPurchase WHERE PurchaseId = @PurchaseId))
       OR EXISTS (SELECT 1 FROM dbo.Purchase p
                  WHERE p.IsShipment = 1
                    AND p.SourceShipmentId IN (SELECT ShipmentId FROM dbo.ShipmentPurchase WHERE PurchaseId = @PurchaseId))
        THROW 50055, 'This bill already has shipment split charges or a generated shipment bill. Unassign it from the shipment before receiving/reassigning.', 1;

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

    -- 1. update source
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
    UPDATE Purchase
    SET
        ArrivalDate = GETDATE(),
        VendorDocNumber = @FinalVendorDocNumber,
        ContainerNumber = @FinalContainerNumber
    WHERE PurchaseId = @PurchaseId
    SELECT @TxId = TxId
    FROM TransactionJournal WHERE SourceDocType = 'Purchase' AND SourceDocNumber = @PurchaseNumber
    UPDATE TransactionJournal SET TxDate = GETDATE() WHERE TxId = @TxId

    --4. IF Shipment asssign delete existing assign shipment
    UPDATE s SET Status = 'Draft'
    FROM Shipment s
    JOIN ShipmentPurchase as sp ON s.ShipmentId = sp.ShipmentId
    WHERE PurchaseId = @PurchaseId;

    -- SCR_C_FK_UNASSIGN_20260710: drop this purchase's per-bill charges first (their ShipmentAllocation
    -- cascade-deletes) so FK_ShipmentCharge_ShipmentPurchase does not block removing its shipment link.
    DELETE FROM ShipmentCharge
    WHERE ShipmentPurchaseId IN (SELECT ShipmentPurchaseId FROM ShipmentPurchase WHERE PurchaseId = @PurchaseId);

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


