/*
    Permission_RenameAPCheckDisplayName_rollback.sql
    Reverses the rename back to the prior label.
    Idempotent.
*/

SET NOCOUNT ON;

UPDATE dbo.Permission
SET    DisplayName = 'Accounts Payable Check'
WHERE  PermissionKey = 'Report.AP.APCheck'
  AND  DisplayName  <> 'Accounts Payable Check';

-- Verify
SELECT PermissionId, PermissionKey, DisplayName
FROM   dbo.Permission
WHERE  PermissionKey = 'Report.AP.APCheck';
