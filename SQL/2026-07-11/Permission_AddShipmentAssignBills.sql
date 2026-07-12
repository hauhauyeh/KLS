-- Permission seed for the Shipment "Assign Bills To Shipment" action (Multi-Bill Assign flow).
-- The Vendor.Shipment resource (7250) already exists; this adds one button child.
-- Idempotent. Slot 7259 is the next free child under 7250 (7258 = SplitCharge; 7259 verified free 2026-07-11).
-- Deploy: run inline (-Q) or via stdin; single batch.

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Vendor.Shipment.AssignBills')
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (7259, 'Vendor.Shipment.AssignBills', 'Assign Bills To Shipment', 'Vendor', 'Shipment', 'AssignBills', 'button', 7250, 7259, NULL, NULL, 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END
