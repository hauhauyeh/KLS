SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Grant AR report access to sales roles.
-- Data scoping remains enforced separately by report logic.

INSERT INTO RolePermission (SystemRoleId, PermissionId)
SELECT v.SystemRoleId, v.PermissionId
FROM (VALUES
    (3, 6101),  -- Sales -> Report.AR.ARInvoice
    (3, 6102),  -- Sales -> Report.AR.ARMonth
    (15, 6101), -- Outside Broker -> Report.AR.ARInvoice
    (15, 6102)  -- Outside Broker -> Report.AR.ARMonth
) v(SystemRoleId, PermissionId)
WHERE NOT EXISTS (
    SELECT 1
    FROM RolePermission rp
    WHERE rp.SystemRoleId = v.SystemRoleId
      AND rp.PermissionId = v.PermissionId
);
GO
