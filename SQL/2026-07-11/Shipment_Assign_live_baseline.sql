-- Live baseline of dbo.Shipment_Assign captured 2026-07-11 (frozen rollback reference).
-- Body byte-exact from sys.sql_modules; standard SET header added so this file is runnable.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[Shipment_Assign]

	@PurchaseId INT,
	@ShipmentIds NVARCHAR(MAX)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @ShipmentIds IS NOT NULL AND LTRIM(RTRIM(@ShipmentIds)) <> ''
	BEGIN
		INSERT INTO ShipmentPurchase (ShipmentId, PurchaseId)
		SELECT CAST(value AS INT) AS ShipmentId, @PurchaseId
		FROM STRING_SPLIT(@ShipmentIds, ',');
	END

	EXEC dbo.Shipment_Allocation @PurchaseId = @PurchaseId, @AllocationType = NULL;

    EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;

	------------------------------------------------------------
    -- Recalculate Each Affected Shipment status
    ------------------------------------------------------------
    DECLARE @ShipmentId INT;

    DECLARE shipment_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT ShipmentId FROM ShipmentPurchase WHERE PurchaseId = @PurchaseId;

    OPEN shipment_cursor;
    FETCH NEXT FROM shipment_cursor INTO @ShipmentId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --EXEC dbo.Shipment_UpdateStatus @ShipmentId

        EXEC dbo.Shipment_GenerateBill @ShipmentId;

        FETCH NEXT FROM shipment_cursor INTO @ShipmentId;
    END

    CLOSE shipment_cursor;
    DEALLOCATE shipment_cursor;
END
