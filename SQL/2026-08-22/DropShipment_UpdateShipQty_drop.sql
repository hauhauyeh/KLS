SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Retired: restricted PO editing now saves entered ShipQty through
-- Purchase_DropShipPORestrictedUpdate.
DROP PROCEDURE IF EXISTS [dbo].[DropShipment_UpdateShipQty];
GO
