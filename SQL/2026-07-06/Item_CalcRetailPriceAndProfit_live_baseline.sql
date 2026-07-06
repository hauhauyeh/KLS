-- =============================================================================
-- Item_CalcRetailPriceAndProfit -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- Sole rollback artifact for the MultipleToBase threading. Do not edit.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Item_CalcRetailPriceAndProfit]
GO

CREATE PROCEDURE [dbo].[Item_CalcRetailPriceAndProfit]
(
    @P1           DECIMAL(18,2),
    @FactorToBase DECIMAL(18,2),    
    @RetailPrice  DECIMAL(18,2) OUTPUT,
    @RetailProfitPercent DECIMAL(18,4) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------------------------
    -- CASE 1: If RetailPrice is provided by user ? calculate RetailProfit
    --------------------------------------------------------------------------
    IF (@RetailPrice IS NOT NULL AND @RetailPrice > 0)
    BEGIN
        SET @RetailProfitPercent = ROUND(1 - (@P1 / (@RetailPrice * @FactorToBase)), 4);
        RETURN;
    END

    IF @RetailProfitPercent IS NULL
        SELECT @RetailProfitPercent=SettingValue FROM SystemSetting WHERE SettingKey='ITEM_DEFAULT_RETAILPROFIT'

    --------------------------------------------------------------------------
    -- CASE 2: RetailPrice is missing ? calculate RetailPrice from profit%
    -- Uses your existing Fn_Calc_RetailPrice procedure
    --------------------------------------------------------------------------
    EXEC Fn_Calc_RetailPrice 
        @P1,
        @FactorToBase,
        @RetailProfitPercent,
        @RetailPrice OUTPUT;
END
