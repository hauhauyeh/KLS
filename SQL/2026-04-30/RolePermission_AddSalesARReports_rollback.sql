SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Rollback AR report access granted to sales roles.

DELETE FROM RolePermission
WHERE SystemRoleId IN (3, 15)
  AND PermissionId IN (6101, 6102);
GO
