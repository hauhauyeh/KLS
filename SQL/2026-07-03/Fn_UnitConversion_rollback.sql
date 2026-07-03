-- Rollback for Fn_UnitConversion.sql (Phase B step 1 — new rational-unit conversion UDFs).
-- These functions did not exist before 2026-07-03, so rollback = drop them.
-- SAFE ONLY while no object references them. Once Phase B swaps conversion sites to
-- these UDFs, dropping them will break those SPs — roll those SPs back FIRST.
DROP FUNCTION IF EXISTS dbo.Fn_QtyToBase
GO
DROP FUNCTION IF EXISTS dbo.Fn_PriceToBase
GO
