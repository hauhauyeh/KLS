-- =============================================================================
-- Fn_Calc_RetailPrice -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- Sole rollback artifact for the MultipleToBase threading. Do not edit.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Fn_Calc_RetailPrice]
GO


CREATE PROCEDURE [dbo].[Fn_Calc_RetailPrice]

   @P1 DECIMAL(18,2),
   @FactorToBase DECIMAL(18,2),
   @RetailProfitPercent DECIMAL(18,4),
   @RetailPrice DECIMAL(18,2) OUTPUT 
AS
BEGIN

	SET NOCOUNT ON;

	IF (@FactorToBase = 0 OR @FactorToBase IS NULL)
		SET @FactorToBase = 1
		
	IF @RetailProfitPercent IS NULL
		SELECT @RetailProfitPercent=SettingValue FROM SystemSetting WHERE SettingKey='ITEM_DEFAULT_RETAILPROFIT'
		
	SET @RetailPrice = (@P1/(1-@RetailProfitPercent))/@FactorToBase

	--New Formula
	--SET @RetailPrice = (@P1 / @FactorToBase) / (1 - @RetailProfitPercent)

	EXEC Fn_PriceRoundUp @RetailPrice,@RetailPrice OUTPUT

	SET @RetailPrice = ISNULL(@RetailPrice,0)
  
	RETURN
END
