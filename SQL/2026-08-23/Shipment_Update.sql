SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Shipment_Update] -- EXEC dbo.Shipment_Update @ShipmentId = 1
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 2026-08-23 CONFIRM_CHARGES_COMPLETE:
    -- Header/charge edits make completion provisional again. They must not generate
    -- final AP charge bills; explicit confirmation owns that.
    EXEC dbo.Shipment_ResetCompletionAndReallocate
         @ShipmentId = @ShipmentId,
         @RebuildChargeSummaries = 0,
         @DeleteGeneratedApBills = 1;
END

