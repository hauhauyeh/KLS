-- ============================================================
-- ItemHistory_Purchase  (2026-05-13)
--
-- Change scope (this round):
--   Add PayeeId and StageId to both UNION branches so the frontend
--   cost-history modal's Edit button can route per-row:
--     - StageId = 6 (Billed) -> Bill Manager (newEditBill)
--     - StageId < 6          -> PO Manager (newEditPO)
--   Per-row PayeeId is also needed because the modal's @Input
--   payeeId is 0 for the common standalone callers (item-list,
--   item-tab-unit, inventory-adj-add-edit) and the SP itself does
--   not filter by @PayeeId, so the result set spans multiple
--   vendors regardless.
--
-- Branch sources:
--   Branch 1 (received bills, View_PurchaseHistory):
--     - v.PayeeId already exposed by the view.
--     - StageId NOT exposed by the view; INNER JOIN Purchase to read
--       pur.StageId. Orphan check ran 2026-05-13: 0 view rows
--       without a matching Purchase row, so INNER JOIN is safe.
--   Branch 2 (unreceived PO lines, PurchaseDetail + Purchase):
--     - p.PayeeId and p.StageId already in scope from the existing
--       INNER JOIN Purchase p.
--
-- Type derivation untouched. Type remains a display-only label;
-- the manager-split rule consumes StageId, not Type.
--
-- _prev already exists for this proc; use CREATE OR ALTER.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[ItemHistory_Purchase]
    @ItemId INT,
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT top 300 *
    FROM (
        -- Received bills (from existing view, joined to Purchase for StageId)
        SELECT
            v.PurchaseDetailId,
            v.PurchaseId,
            v.PurchaseNumber,
            v.VendorDocNumber,
            v.ArrivalDate,
            p.PayeeName,
            v.ShipQty,
            v.FinalQty,
            v.Unit,
            v.FinalPrice,
            v.LandedCostPerCase,
            v.TotalCost,
            CASE WHEN v.FinalQty IS NOT NULL THEN 'Bill' ELSE 'PO' END AS Type,
            0 AS IsPdfExist,
            v.PayeeId,                          -- 2026-05-13: per-row routing
            pur.StageId                         -- 2026-05-13: per-row routing (joined; not in view)
        FROM View_PurchaseHistory AS v
        INNER JOIN Payee AS p ON p.PayeeId = v.PayeeId
        INNER JOIN Purchase AS pur ON pur.PurchaseId = v.PurchaseId
        WHERE v.ItemId = @ItemId

        UNION ALL

        -- Unreceived PO lines (not in view)
        SELECT
            pd.PurchaseDetailId,
            p.PurchaseId,
            p.PurchaseNumber,
            p.VendorDocNumber,
            p.ArrivalDate,
            py.PayeeName,
            pd.OrdQty0 AS ShipQty,
            NULL AS FinalQty,
            pd.Unit,
            pd.OrgPrice AS FinalPrice,
            0 AS LandedCostPerCase,
            0 AS TotalCost,
            'PO' AS Type,
            0 AS IsPdfExist,
            p.PayeeId,                          -- 2026-05-13: per-row routing
            p.StageId                           -- 2026-05-13: per-row routing
        FROM PurchaseDetail pd
        INNER JOIN Purchase p ON p.PurchaseId = pd.PurchaseId
        LEFT JOIN Payee py ON py.PayeeId = p.PayeeId
        WHERE pd.ReceiveQty IS NULL
          AND pd.ItemId = @ItemId
          AND pd.ItemId IS NOT NULL
    ) i
    ORDER BY ArrivalDate DESC, PurchaseId DESC
END
GO
