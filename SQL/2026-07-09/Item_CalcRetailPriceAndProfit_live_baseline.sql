
CREATE   PROCEDURE [dbo].[Item_CalcRetailPriceAndProfit]   -- EXEC: DECLARE @rp DECIMAL(18,2),@pp DECIMAL(18,4); EXEC dbo.Item_CalcRetailPriceAndProfit @P1=100,@FactorToBase=1,@RetailPrice=@rp OUTPUT,@RetailProfitPercent=@pp OUTPUT,@MultipleToBase=1; SELECT @rp,@pp;
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

