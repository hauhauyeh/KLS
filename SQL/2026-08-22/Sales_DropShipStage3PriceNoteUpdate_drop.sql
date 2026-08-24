SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Retired after all application callers moved to Sales_DropShipRestrictedUpdate.
IF OBJECT_ID(N'dbo.Sales_DropShipStage3PriceNoteUpdate', N'P') IS NOT NULL
    DROP PROCEDURE dbo.Sales_DropShipStage3PriceNoteUpdate;
GO
