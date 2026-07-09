-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B1-Item_CalcUnitFromPack1: 4-decimal pricing §B Phase-1 (storage/type widen, inert).
--   Widen @P1 param + @RetailPrice local 2dp -> 4dp. Fully inert: both vars are currently DEAD (declared,
--   never used/returned) — this is cosmetic consistency with the rest of the price engine.
CREATE OR ALTER PROCEDURE [dbo].[Item_CalcUnitFromPack1] --[Item_CalcUnitFromPack1] 'cs/10pk',10

	@SetPacking NVARCHAR(200),
	-- 4dp widen (currently unused): was DECIMAL(18,2)
	@P1 DECIMAL(18,4)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @BaseUnit NVARCHAR(100);
	DECLARE @PackSize NVARCHAR(100);
	DECLARE @RetailUnit NVARCHAR(50);
	DECLARE @FactorToBase DECIMAL(18,6);
	
	-- 4dp widen (currently unused): was DECIMAL(18,2)
	DECLARE @RetailPrice DECIMAL(18,4)=0;
	DECLARE @ItemExists NVARCHAR(50)
	DECLARE @RProfit DECIMAL(18,4)

	EXEC [Fn_Calc_FromPack1] @SetPacking,@BaseUnit OUTPUT,@PackSize OUTPUT,@RetailUnit OUTPUT,@FactorToBase OUTPUT

	DECLARE @ItemUnit AS TABLE(
		Id INT IDENTITY(1,1),
		Unit NVARCHAR(50),
		FactorToBase DECIMAL(18,6),
		IsBaseUnit BIT,
		IsDefaultSalesUnit BIT
	)

	INSERT INTO @ItemUnit
	VALUES(@BaseUnit,1,1,1)

	INSERT INTO @ItemUnit
	VALUES(@RetailUnit,@FactorToBase,0,0)

	SELECT * FROM @ItemUnit WHERE Unit IS NOT NULL

END
GO


