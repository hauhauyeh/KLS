-- SET options required for compile-time settings. See kls-sql-standard.md
-- Part 1 "Required SP Header".
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
DROP PROCEDURE IF EXISTS [dbo].[Purchase_AssignedShipment];
GO


CREATE PROCEDURE [dbo].[Purchase_AssignedShipment]
    @PurchaseId INT,
    @IsShipment BIT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ROW_NUMBER() OVER(ORDER BY sp.ShipmentPurchaseId) AS Id,
        sp.ShipmentPurchaseId,
        sp.ShipmentId,
        s.ShipmentType,
        s.ContainerType,
        s.ContainerNo,
        s.Status,
        p.PayeeName,
        sc.ChargeId,
        sc.ChargeType,
        sc.AllocationMethod,
        sc.ChargeAmount,
        sc.Notes,
        sa_agg.UsedMethod,
        CAST(CASE WHEN EXISTS (
            SELECT 1 FROM dbo.Purchase bill
            WHERE bill.SourceShipmentId = s.ShipmentId
            AND bill.IsLocked = 1
        ) THEN 1 ELSE 0 END AS BIT) AS IsLocked
    FROM dbo.ShipmentPurchase sp
    INNER JOIN dbo.Shipment s ON sp.ShipmentId = s.ShipmentId
    INNER JOIN dbo.Payee p ON s.PayeeId = p.PayeeId
    LEFT JOIN dbo.ShipmentCharge sc ON sc.ShipmentId = s.ShipmentId
    OUTER APPLY (
        SELECT TOP 1 sa.AllocationMethod AS UsedMethod
        FROM dbo.ShipmentAllocation sa
        WHERE sa.ChargeId = sc.ChargeId
    ) sa_agg
    WHERE sp.PurchaseId = @PurchaseId
END


GO
