-- Fn_PriceToBase -- LIVE body captured 2026-07-06. REFERENCE (already MTB-threaded; NOT changed by the price phase).
-- Confirms the price primitive: BasePrice = price * factor / NULLIF(mult,0). Phase-start precheck artifact.

CREATE FUNCTION dbo.Fn_PriceToBase
(
    @price  DECIMAL(18,6),   -- entered price/cost in the selling/pack unit (or a base qty, for reverse use)
    @mult   INT,             -- ItemUnit.MultipleToBase
    @factor DECIMAL(18,6)    -- ItemUnit.FactorToBase
)
RETURNS DECIMAL(18,6)
AS
BEGIN
    -- price scales inversely to qty: base_price = price * factor / multiple.
    -- NULLIF guards a 0 multiple (-> NULL, never divide-by-zero); by CHECK constraint mult>0 so this is belt-and-braces.
    RETURN ROUND(@price * @factor / NULLIF(@mult, 0), 6);
END
