-- ============================================================
-- Shipment_Allocation Phase 1 — ROLLBACK
-- Restores original SPs from _prev copies
-- ============================================================

DROP PROCEDURE IF EXISTS dbo.Shipment_Allocation;
DROP PROCEDURE IF EXISTS dbo.Purchase_Allocation;

IF OBJECT_ID('dbo.Shipment_Allocation_prev') IS NOT NULL
    EXEC sp_rename 'Shipment_Allocation_prev', 'Shipment_Allocation';

IF OBJECT_ID('dbo.Purchase_Allocation_prev') IS NOT NULL
    EXEC sp_rename 'Purchase_Allocation_prev', 'Purchase_Allocation';
