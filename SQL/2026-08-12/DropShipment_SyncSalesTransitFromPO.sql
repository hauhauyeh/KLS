SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[DropShipment_SyncSalesTransitFromPO] -- EXEC dbo.DropShipment_SyncSalesTransitFromPO @PurchaseId=100137
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @PurchaseId IS NULL
        RETURN;

    -- 2026-08-12: drop-ship PO vendor progress moves the linked Sales Order forward to Transit.
    -- Finalized Sales stage contract: 0=Order, 1=Picking, 2=Transit, 3=Received, 4=Success.
    UPDATE s
    SET
        StageId = 2,
        UpdatedAt = GETUTCDATE()
    FROM Sales s
    INNER JOIN Purchase p ON p.DropShipSalesId = s.SalesId
    WHERE p.PurchaseId = @PurchaseId
      AND ISNULL(p.IsDropShip, 0) = 1
      AND p.DropShipSalesId IS NOT NULL
      AND s.StageId IN (0, 1)
      AND (
            p.StageId IN (2, 3)
            OR NULLIF(LTRIM(RTRIM(p.ContainerNumber)), '') IS NOT NULL
          );
END
GO
