SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Shipment_UnassignPurchases] -- EXEC dbo.Shipment_UnassignPurchases @ShipmentId = 1, @ShipmentPurchaseIds = '1,2'
    @ShipmentId INT,
    @ShipmentPurchaseIds NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Shipment WHERE ShipmentId = @ShipmentId)
        THROW 50301, 'Shipment_UnassignPurchases: shipment not found.', 1;

    DECLARE @Tokens TABLE (RawTok NVARCHAR(50), ParsedId INT NULL);

    INSERT INTO @Tokens (RawTok, ParsedId)
    SELECT NULLIF(LTRIM(RTRIM(value)), ''),
           TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT)
    FROM STRING_SPLIT(ISNULL(@ShipmentPurchaseIds, ''), ',')
    WHERE NULLIF(LTRIM(RTRIM(value)), '') IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Tokens WHERE ParsedId IS NULL)
        THROW 50302, 'One or more selected assignment ids are not valid integers.', 1;

    DECLARE @Ids TABLE (ShipmentPurchaseId INT PRIMARY KEY);

    INSERT INTO @Ids (ShipmentPurchaseId)
    SELECT DISTINCT ParsedId
    FROM @Tokens;

    IF NOT EXISTS (SELECT 1 FROM @Ids)
        THROW 50303, 'No source bills were selected for unassignment.', 1;

    IF EXISTS (
        SELECT 1
        FROM @Ids i
        LEFT JOIN dbo.ShipmentPurchase sp
          ON sp.ShipmentPurchaseId = i.ShipmentPurchaseId
         AND sp.ShipmentId = @ShipmentId
        WHERE sp.ShipmentPurchaseId IS NULL
    )
        THROW 50304, 'One or more selected source bills are not assigned to this shipment.', 1;

    -- Generated AP package must be removable before any source link is changed.
    IF EXISTS (
        SELECT 1
        FROM dbo.Purchase p
        WHERE ISNULL(p.IsShipment, 0) = 1
          AND p.SourceShipmentId = @ShipmentId
          AND (ISNULL(p.IsLocked, 0) = 1 OR ISNULL(p.PaymentApplied, 0) > 0)
    )
        THROW 50305, 'Cannot unassign. Generated shipment AP bill is locked or paid.', 1;

    DECLARE @RemovedPurchases TABLE (PurchaseId INT PRIMARY KEY);

    INSERT INTO @RemovedPurchases (PurchaseId)
    SELECT DISTINCT sp.PurchaseId
    FROM dbo.ShipmentPurchase sp
    JOIN @Ids i
      ON i.ShipmentPurchaseId = sp.ShipmentPurchaseId;

    DECLARE @ExtraPurchaseIds NVARCHAR(MAX);

    SELECT @ExtraPurchaseIds = STRING_AGG(CONVERT(NVARCHAR(MAX), PurchaseId), ',')
    FROM @RemovedPurchases;

    BEGIN TRY
        BEGIN TRAN;

        -- Remove allocations for the selected source bills in this shipment.
        DELETE sa
        FROM dbo.ShipmentAllocation sa
        INNER JOIN dbo.ShipmentCharge sc
            ON sc.ChargeId = sa.ChargeId
        INNER JOIN dbo.PurchaseDetail pd
            ON pd.PurchaseDetailId = sa.PurchaseDetailId
        INNER JOIN @RemovedPurchases rp
            ON rp.PurchaseId = pd.PurchaseId
        WHERE sc.ShipmentId = @ShipmentId;

        -- Remove bill-scoped charges owned by the selected assignment rows.
        DELETE sc
        FROM dbo.ShipmentCharge sc
        JOIN @Ids i
          ON i.ShipmentPurchaseId = sc.ShipmentPurchaseId;

        DELETE sp
        FROM dbo.ShipmentPurchase sp
        JOIN @Ids i
          ON i.ShipmentPurchaseId = sp.ShipmentPurchaseId
        WHERE sp.ShipmentId = @ShipmentId;

        EXEC dbo.Shipment_ResetCompletionAndReallocate
             @ShipmentId = @ShipmentId,
             @RebuildChargeSummaries = 0,
             @DeleteGeneratedApBills = 1,
             @ExtraPurchaseIds = @ExtraPurchaseIds;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    SELECT UnassignedCount = (SELECT COUNT(*) FROM @Ids);
END
