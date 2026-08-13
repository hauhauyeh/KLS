-- Rollback for Permission_AddSalesQuote.sql.
-- Removes only the Sales Quote permission rows seeded in the 3400-3408 range.
-- Deletes dependent RolePermission rows first so rollback can run after manual grants.

DELETE rp
FROM dbo.RolePermission rp
INNER JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey LIKE 'Customer.SalesQuote%'
  AND p.PermissionId BETWEEN 3400 AND 3408;

DELETE FROM dbo.Permission
WHERE PermissionKey LIKE 'Customer.SalesQuote%'
  AND PermissionId BETWEEN 3400 AND 3408;

SELECT PermissionId, PermissionKey
FROM dbo.Permission
WHERE PermissionKey LIKE 'Customer.SalesQuote%'
ORDER BY PermissionId;
