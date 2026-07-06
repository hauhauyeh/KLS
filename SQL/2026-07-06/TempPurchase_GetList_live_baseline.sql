-- =============================================================================
-- TempPurchase_GetList -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- Sole rollback artifact for the MultipleToBase threading. Do not edit.
-- Deployable as-is (DROP + CREATE) to restore the pre-change proc.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[TempPurchase_GetList]
GO


CREATE PROCEDURE [dbo].[TempPurchase_GetList] --[TempPurchase_GetList] 100001,200002,0,null,null,null

	@EmpId INT,
	@PayeeId INT,
	@PurchaseId INT,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(10),
	@Id INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	SET @Qry = '
    SELECT *
    FROM (
        SELECT t.*,
               i.ItemName,
               i.ItemCode,
               i.CaseWeight,
               p.LandedCostPerCase,
               p.BaseFinalQty,
               -- 2026-06-29 (Plan 2c): per-case landed cost split by shipment ChargeType.
               -- Correlated over ShipmentAllocation for this line; NULL when the line has no
               -- allocation of that type yet (draft line, or that charge not entered).
               FreightPerCase = (
                   SELECT ROUND(SUM(sa.AllocatedAmount) / NULLIF(p.BaseFinalQty, 0), 2)
                   FROM   dbo.ShipmentAllocation sa
                   JOIN   dbo.ShipmentCharge sc ON sc.ChargeId = sa.ChargeId
                   WHERE  sa.PurchaseDetailId = t.PurchaseDetailId
                     AND  sc.ChargeType = ''Freight''
               ),
               DutyPerCase = (
                   SELECT ROUND(SUM(sa.AllocatedAmount) / NULLIF(p.BaseFinalQty, 0), 2)
                   FROM   dbo.ShipmentAllocation sa
                   JOIN   dbo.ShipmentCharge sc ON sc.ChargeId = sa.ChargeId
                   WHERE  sa.PurchaseDetailId = t.PurchaseDetailId
                     AND  sc.ChargeType = ''Duty''
               )
        FROM TempPurchase t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        LEFT JOIN View_PurchaseHistory p
               ON p.PurchaseId = t.PurchaseId
              AND p.PurchaseDetailId = t.PurchaseDetailId

        UNION ALL

        SELECT t.*,
               a.AccountName,
               a.AccountCode,
               NULL,   -- CaseWeight
               NULL,   -- LandedCostPerCase
               NULL,   -- BaseFinalQty
               NULL,   -- FreightPerCase (2026-06-29 Plan 2c)
               NULL    -- DutyPerCase    (2026-06-29 Plan 2c)
        FROM TempPurchase t
        INNER JOIN Account a ON t.AccountId = a.AccountId
    ) x
    WHERE x.EmpId = ' + CONVERT(VARCHAR,@EmpId) + '
      AND x.PurchaseId = ' + CONVERT(VARCHAR,@PurchaseId) + '
      AND x.PayeeId = ' + CONVERT(VARCHAR,@PayeeId) + ''

    IF @Id IS NOT NULL
        SET @Qry += ' AND x.TempPurchaseId='+CONVERT(VARCHAR,@Id)

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry += ' ORDER BY x.LineId'

	EXEC (@Qry)
END
