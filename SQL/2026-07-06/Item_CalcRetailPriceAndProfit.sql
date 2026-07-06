-- =============================================================================
-- Item_CalcRetailPriceAndProfit -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-06 (price phase, vertical 2): thread combine-up into the retail price/profit calc.
--   New @MultipleToBase INT = 1 param, DEFAULTED and LAST -> both callers stay identity until
--   Item_UpdateBaseP1 (vertical 3) passes it: Item_UpdateBaseP1 (positional 4-arg, the LIVE path)
--   and the DEAD C# CalcRetailPriceProfit endpoint (4 named args). SP-ONLY -- no C#/FE change
--   (see 2026-07-06-dead-code-calcretailpriceprofit.md). Rollout guard: @Mult = ISNULL(NULLIF(...,0),1).
--   CASE 1 (reverse profit) and CASE 2 (forward price via Fn_Calc_RetailPrice, which now takes @MultipleToBase).
--   Identity for all production data (Mult=1); only CHIFT (Mult=10) computes combine-up.
-- Baseline: KLS/SQL/2026-07-06/Item_CalcRetailPriceAndProfit_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Item_CalcRetailPriceAndProfit]   -- EXEC: DECLARE @rp DECIMAL(18,2),@pp DECIMAL(18,4); EXEC dbo.Item_CalcRetailPriceAndProfit @P1=100,@FactorToBase=1,@RetailPrice=@rp OUTPUT,@RetailProfitPercent=@pp OUTPUT,@MultipleToBase=1; SELECT @rp,@pp;
(
    @P1           DECIMAL(18,2),
    @FactorToBase DECIMAL(18,2),
    @RetailPrice  DECIMAL(18,2) OUTPUT,
    @RetailProfitPercent DECIMAL(18,4) OUTPUT,
    @MultipleToBase INT = 1   -- 2026-07-06: combine-up numerator; defaulted + last so old callers stay identity
)
AS
BEGIN
    SET NOCOUNT ON;

    -- 2026-07-06: rollout guard -- normalize NULL/0 -> 1 (see price-side phase plan).
    DECLARE @Mult INT = ISNULL(NULLIF(@MultipleToBase, 0), 1);

    --------------------------------------------------------------------------
    -- CASE 1: RetailPrice provided by user -> derive RetailProfitPercent (reverse)
    --------------------------------------------------------------------------
    IF (@RetailPrice IS NOT NULL AND @RetailPrice > 0)
    BEGIN
        -- 2026-07-06: threaded combine-up numerator (* @Mult). Old (Mult=1 identity):
        -- SET @RetailProfitPercent = ROUND(1 - (@P1 / (@RetailPrice * @FactorToBase)), 4);
        SET @RetailProfitPercent = ROUND(1 - (@P1 * @Mult / (@RetailPrice * @FactorToBase)), 4);
        RETURN;
    END

    IF @RetailProfitPercent IS NULL
        SELECT @RetailProfitPercent=SettingValue FROM SystemSetting WHERE SettingKey='ITEM_DEFAULT_RETAILPROFIT'

    --------------------------------------------------------------------------
    -- CASE 2: RetailPrice missing -> calculate RetailPrice from profit% (forward)
    -- Uses Fn_Calc_RetailPrice (now accepts @MultipleToBase; it normalizes internally too).
    --------------------------------------------------------------------------
    -- 2026-07-06: pass @MultipleToBase through (added trailing arg).
    EXEC Fn_Calc_RetailPrice
        @P1,
        @FactorToBase,
        @RetailProfitPercent,
        @RetailPrice OUTPUT,
        @MultipleToBase;
END
