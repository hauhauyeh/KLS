/*
    Permission_RenameAPCheckDisplayName.sql
    2026-05-27

    Updates the DisplayName for the existing 'Report.AP.APCheck' permission
    from 'Accounts Payable Check' to 'AP Outstanding Checks'. The
    PermissionKey itself is unchanged so existing RolePermission grants
    remain valid; this is purely a label refresh for the permission
    management UI.

    Idempotent.
*/

SET NOCOUNT ON;

UPDATE dbo.Permission
SET    DisplayName = 'AP Outstanding Checks'
WHERE  PermissionKey = 'Report.AP.APCheck'
  AND  DisplayName  <> 'AP Outstanding Checks';

-- Verify
SELECT PermissionId, PermissionKey, DisplayName
FROM   dbo.Permission
WHERE  PermissionKey = 'Report.AP.APCheck';
