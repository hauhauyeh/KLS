-- Rollback for Permission_AddItemAvgCostReview.sql — removes the page child only.
-- (Leaves the Report.Item resource 6500 intact — it is shared by the other Item reports.)

DELETE FROM dbo.Permission WHERE PermissionKey = 'Report.Item.ItemAvgCostReview';
