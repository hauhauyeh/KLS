-- Permission seed for the Item AvgCost Review report.
-- The Report.Item resource (6500) already exists, so this adds only the page child.
-- Idempotent. Slot 6503 is the next free child under 6500 (6501/6502 taken).
-- Deploy: run inline (-Q) or via stdin; it is a single batch.

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Report.Item.ItemAvgCostReview')
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (6503, 'Report.Item.ItemAvgCostReview', 'Item -> Item AvgCost Review', 'Report', 'Item', 'ItemAvgCostReview', 'page', 6500, 6503, NULL, NULL, 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END
