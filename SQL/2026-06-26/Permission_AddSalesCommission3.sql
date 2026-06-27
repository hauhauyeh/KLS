-- Permission_AddSalesCommission3.sql
-- Seeds the Report.Sales.SalesCommission3 page permission (id 6417) under the Report.Sales
-- resource (6400), next free slot after SalesSummary (6416). Verified free: 6417 did not exist.
-- Idempotent. Does NOT touch RolePermission -- role grants are assigned separately (admin UI),
-- so after this runs you must grant the permission to the roles that should see the report.
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionKey = 'Report.Sales.SalesCommission3')
BEGIN
    SET IDENTITY_INSERT Permission ON;
    INSERT INTO Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (6417, 'Report.Sales.SalesCommission3', 'Sales Commission 3', 'Report', 'Sales', 'SalesCommission3', 'page', 6400, 6417, NULL, NULL, 1, GETDATE());
    SET IDENTITY_INSERT Permission OFF;
    PRINT 'Inserted Report.Sales.SalesCommission3 (6417).';
END
ELSE
    PRINT 'Report.Sales.SalesCommission3 already exists -- skipped.';
