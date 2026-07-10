
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B-Phase2-Slice4a-Item_CalcRetailPriceAndProfit: widen the retail-calc chain to (18,4).
--   Widen @P1 + @RetailPrice OUTPUT -> (18,4) so 4dp flows to/from Fn_Calc_RetailPrice (CASE 2). CASE 1
--   (reverse) profit-percent ROUND(...,4) is a PERCENT -> untouched. @FactorToBase (ratio) left. Inert at
--   setting=2 (<=2dp data); round-once + setting gate live in Fn_Calc_RetailPrice (Slice-4a).
CREATE OR ALTER PROCEDURE [dbo].[Item_CalcRetailPriceAndProfit]   -- EXEC: DECLARE @rp DECIMAL(18,4),@pp DECIMAL(18,4); EXEC dbo.Item_CalcRetailPriceAndProfit @P1=100,@FactorToBase=1,@RetailPrice=@rp OUTPUT,@RetailProfitPercent=@pp OUTPUT,@MultipleToBase=1; SELECT @rp,@pp;
(
    -- 4dp widen (entered base price): was DECIMAL(18,2)
    @P1           DECIMAL(18,4),
    @FactorToBase DECIMAL(18,2),
    -- 4dp widen (retail price out): was DECIMAL(18,2)
    @RetailPrice  DECIMAL(18,4) OUTPUT,
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
GO
