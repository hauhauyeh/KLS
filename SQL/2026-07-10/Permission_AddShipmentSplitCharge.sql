-- Permission seed for the Shipment "Split Charge To Bills" action (Phase C split-on-entry helper).
-- The Vendor.Shipment resource (7250) already exists; this adds one button child.
-- Idempotent. Slot 7258 is the next free child under 7250 (7251-7257 taken; 7258-7265 verified free 2026-07-10).
-- Deploy: run inline (-Q) or via stdin; single batch.

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Vendor.Shipment.SplitCharge')
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (7258, 'Vendor.Shipment.SplitCharge', 'Split Charge To Bills', 'Vendor', 'Shipment', 'SplitCharge', 'button', 7250, 7258, NULL, NULL, 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END
