SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

INSERT INTO RolePermission (SystemRoleId, PermissionId)
SELECT v.SystemRoleId, v.PermissionId
FROM (VALUES
    (3, 6000),  -- Sales -> Report menu
    (3, 6400),  -- Sales -> Report.Sales resource
    (3, 6401),  -- Sales -> Sales Daily
    (3, 6405),  -- Sales -> Credit Memo
    (3, 6407),  -- Sales -> Sales Detail
    (3, 6408),  -- Sales -> Sales Daily 2
    (3, 6410),  -- Sales -> Sales Commission
    (3, 6411),  -- Sales -> Sales Commission 2
    (15, 6000), -- Outside Broker -> Report menu
    (15, 6400), -- Outside Broker -> Report.Sales resource
    (15, 6401), -- Outside Broker -> Sales Daily
    (15, 6405), -- Outside Broker -> Credit Memo
    (15, 6407), -- Outside Broker -> Sales Detail
    (15, 6408), -- Outside Broker -> Sales Daily 2
    (15, 6410), -- Outside Broker -> Sales Commission
    (15, 6411)  -- Outside Broker -> Sales Commission 2
) AS v(SystemRoleId, PermissionId)
WHERE NOT EXISTS (
    SELECT 1
    FROM RolePermission rp
    WHERE rp.SystemRoleId = v.SystemRoleId
      AND rp.PermissionId = v.PermissionId
);
GO
