-- ============================================================================
-- Phase A -- add MultipleToBase to ItemUnit   (FactorToBase -> rational migration)
-- Master plan: note-txdetail-itemunit-master-plan.md (Effort A, Phase A)
-- Detail:      itemunit-factor-to-rational-migration-plan.md
-- ============================================================================
-- MultipleToBase is the NUMERATOR of the unit ratio; FactorToBase stays the denominator:
--     BaseQty = Qty * MultipleToBase / FactorToBase
-- DEFAULT 1  =>  identity:  BaseQty = Qty * 1 / FactorToBase  =  today's  Qty / FactorToBase.
-- So this column is INERT on deploy -- all 5,106 existing rows behave EXACTLY as before, and no
-- code needs to change until Phase B threads "* MultipleToBase" through the conversion sites.
--
-- Combine-up units (base = SMALLEST unit) store MultipleToBase = N, FactorToBase = 1
--   e.g. a 6-pack over singles: MultipleToBase = 6, FactorToBase = 1  (exact integers, no decimals).
-- Measured: 0 combine-up rows exist today, so there is NO data back-fill -- every current row is
-- already a valid MultipleToBase = 1 rational.
-- ============================================================================

-- (1) The column: INT, NOT NULL, DEFAULT 1 (identity).
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.ItemUnit') AND name = 'MultipleToBase')
BEGIN
    ALTER TABLE dbo.ItemUnit
        ADD MultipleToBase INT NOT NULL
            CONSTRAINT DF_ItemUnit_MultipleToBase DEFAULT (1);
END
GO

-- (2) Numerator must be positive (mirrors the FactorToBase > 0 expectation).
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = 'CK_ItemUnit_MultipleToBase_Positive')
BEGIN
    ALTER TABLE dbo.ItemUnit
        ADD CONSTRAINT CK_ItemUnit_MultipleToBase_Positive CHECK (MultipleToBase > 0);
END
GO

-- (3) v1 ratio rule (master plan decision 5.3): ONE side of the ratio must be 1.
--     Allows "larger multiples of base" (MultipleToBase=N, FactorToBase=1) OR "smaller fractions
--     of base" (MultipleToBase=1, FactorToBase=N), but NOT arbitrary packs like 3/2.
--     Keeps UI / validation / packing-display / testing simple; relax later only on real need.
--     Safe on existing data: all rows are MultipleToBase = 1, so every current row passes.
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = 'CK_ItemUnit_Ratio_OneSideOne')
BEGIN
    ALTER TABLE dbo.ItemUnit
        ADD CONSTRAINT CK_ItemUnit_Ratio_OneSideOne
            CHECK (MultipleToBase = 1 OR FactorToBase = 1);
END
GO

-- Post-deploy assertions (each should return 0):
-- SELECT COUNT(*) AS BadPositive FROM dbo.ItemUnit WHERE MultipleToBase <= 0 OR FactorToBase <= 0;
-- SELECT COUNT(*) AS BadRatio    FROM dbo.ItemUnit WHERE MultipleToBase <> 1 AND FactorToBase <> 1;
