-- =============================================================================
-- Fn_QtyToBase / Fn_PriceToBase — rational unit conversion (Phase B, step 1)
-- =============================================================================
-- WHAT: two pure-math scalar UDFs that centralize the ItemUnit rational-ratio
--       conversion formula in ONE tested place, so the ~18 conversion sites
--       (Sales_Insert, Purchase_Insert, etc.) call a function instead of each
--       hand-writing "* MultipleToBase / FactorToBase". The NEXT unit-model
--       change then becomes 1 edit, not 18.
--
-- WHY the pair: quantity and price/cost scale INVERSELY.
--   forward qty : base = entered_qty   * MultipleToBase / FactorToBase
--   price/cost  : base = entered_price * FactorToBase   / MultipleToBase
--   (the reverse-qty case, EnteredQty = BaseQty * FactorToBase / MultipleToBase,
--    uses the same shape as price — so Fn_PriceToBase covers it.)
--
-- IDENTITY GUARANTEE: every current row is MultipleToBase = 1, so
--   Fn_QtyToBase(q,1,f) = ROUND(q/f,6)  — byte-identical to today's formula.
--   Combine-up 6pk-over-pk: Fn_QtyToBase(q,6,1) = q*6 (exact integers, no
--   recurring-decimal /0.1666667 pain).
--
-- INLINING: on this server (SQL Server 17.x / 2025, compat 170) a pure
--   "RETURN <math>" scalar UDF is auto-inlined into the query plan → ZERO
--   runtime call overhead (compile-time substitution). is_inlineable is
--   AUTO-COMPUTED by the engine (read-only) — we do NOT set it. Just verify
--   it comes out 1 after deploy (see verification query at the bottom).
--   No WITH INLINE clause, no data access, deterministic → qualifies for 1.
--
-- ROUND + NULLIF live INSIDE the fn so call sites become a clean 1:1 swap:
--   ROUND(sd.ShipQty / NULLIF(sd.FactorToBase,0),6)
--     -> dbo.Fn_QtyToBase(sd.ShipQty, sd.MultipleToBase, sd.FactorToBase)
--
-- New objects (no prior version) — additive, zero callers today. Rollback = DROP.
-- Ref: itemunit-factor-to-rational-migration-plan.md §4 (Phase B, RECOMMENDED UDF).
-- =============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- -----------------------------------------------------------------------------
-- Fn_QtyToBase — forward quantity conversion (entered qty -> base-unit qty)
-- Example: SELECT dbo.Fn_QtyToBase(3, 1, 10)  -- split-down: 3 cases /10 = 0.3
--          SELECT dbo.Fn_QtyToBase(2, 6, 1)   -- combine-up: 2 six-packs *6 = 12
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS dbo.Fn_QtyToBase
GO
CREATE FUNCTION dbo.Fn_QtyToBase
(
    @qty    DECIMAL(18,6),   -- entered quantity, in the selling/pack unit
    @mult   INT,             -- ItemUnit.MultipleToBase (packs of base per entered unit; base unit = 1)
    @factor DECIMAL(18,6)    -- ItemUnit.FactorToBase   (sub-units per base;          base unit = 1)
)
RETURNS DECIMAL(18,6)
AS
BEGIN
    -- base = qty * multiple / factor.  NULLIF guards a legacy 0 factor (-> NULL, never divide-by-zero).
    RETURN ROUND(@qty * @mult / NULLIF(@factor, 0), 6);
END
GO

-- -----------------------------------------------------------------------------
-- Fn_PriceToBase — price/cost conversion (entered price -> base-unit price).
-- Also serves reverse-qty (base qty -> entered qty) — same inverse shape.
-- Example: SELECT dbo.Fn_PriceToBase(30, 1, 10) -- $30/pack, 10 packs/case -> $300 per base (case)
--          SELECT dbo.Fn_PriceToBase(12, 6, 1)  -- $12 per six-pack /6     -> $2.00 per base (pack)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS dbo.Fn_PriceToBase
GO
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
GO

-- =============================================================================
-- VERIFICATION (run after deploy):
--   -- 1) both must show is_inlineable = 1
--   SELECT o.name, m.is_inlineable
--   FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
--   WHERE o.name IN ('Fn_QtyToBase','Fn_PriceToBase');
--   -- 2) identity + combine-up sanity
--   SELECT dbo.Fn_QtyToBase(3,1,10)   AS split_qty_expect_0_300000,
--          dbo.Fn_QtyToBase(2,6,1)    AS combine_qty_expect_12,
--          dbo.Fn_PriceToBase(30,1,10) AS split_price_expect_300,
--          dbo.Fn_PriceToBase(12,6,1)  AS combine_price_expect_2;
-- =============================================================================
