-- ============================================================
-- Phase 1: Permission System — DDL (Tables + Indexes)
-- Database: KLS_Latest
-- Run once. Additive only — no existing tables modified.
-- ============================================================

-- 1. Permission registry table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Permission')
BEGIN
    CREATE TABLE [dbo].[Permission] (
        [PermissionId]   INT IDENTITY(1,1) PRIMARY KEY,
        [PermissionKey]  NVARCHAR(150) NOT NULL,
        [DisplayName]    NVARCHAR(200) NOT NULL,
        [Module]         NVARCHAR(50)  NOT NULL,
        [Resource]       NVARCHAR(50)  NOT NULL,
        [Action]         NVARCHAR(50)  NOT NULL,
        [PermissionType] NVARCHAR(20)  NOT NULL,        -- 'menu', 'page', 'button'
        [ParentKey]      NVARCHAR(150) NULL,
        [SortOrder]      INT NOT NULL DEFAULT 0,
        [Description]    NVARCHAR(500) NULL,
        [OldKey]         NVARCHAR(150) NULL,             -- migration mapping: 'Items-List'
        [IsActive]       BIT NOT NULL DEFAULT 1,
        [CreatedAt]      DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [UQ_Permission_Key] UNIQUE ([PermissionKey])
    );
    PRINT 'Created table: Permission';
END
ELSE
    PRINT 'Table Permission already exists — skipping.';
GO

-- 2. Role-Permission junction table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'RolePermission')
BEGIN
    CREATE TABLE [dbo].[RolePermission] (
        [RolePermissionId] INT IDENTITY(1,1) PRIMARY KEY,
        [SystemRoleId]     INT NOT NULL,
        [PermissionId]     INT NOT NULL,
        [GrantedAt]        DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [GrantedBy]        INT NULL,
        CONSTRAINT [FK_RolePermission_SystemRole] FOREIGN KEY ([SystemRoleId])
            REFERENCES [dbo].[SystemRole]([SystemRoleId]),
        CONSTRAINT [FK_RolePermission_Permission] FOREIGN KEY ([PermissionId])
            REFERENCES [dbo].[Permission]([PermissionId]),
        CONSTRAINT [UQ_RolePermission] UNIQUE ([SystemRoleId], [PermissionId])
    );
    PRINT 'Created table: RolePermission';
END
ELSE
    PRINT 'Table RolePermission already exists — skipping.';
GO

-- 3. Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Permission_Module')
    CREATE NONCLUSTERED INDEX IX_Permission_Module ON Permission ([Module]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Permission_Type')
    CREATE NONCLUSTERED INDEX IX_Permission_Type ON Permission ([PermissionType]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Permission_ParentKey')
    CREATE NONCLUSTERED INDEX IX_Permission_ParentKey ON Permission ([ParentKey]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Permission_OldKey')
    CREATE NONCLUSTERED INDEX IX_Permission_OldKey ON Permission ([OldKey]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RolePermission_RoleId')
    CREATE NONCLUSTERED INDEX IX_RolePermission_RoleId ON RolePermission ([SystemRoleId]) INCLUDE ([PermissionId]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RolePermission_PermissionId')
    CREATE NONCLUSTERED INDEX IX_RolePermission_PermissionId ON RolePermission ([PermissionId]) INCLUDE ([SystemRoleId]);

PRINT 'Indexes created.';
GO

-- 4. Verify
SELECT 'Permission' AS TableName, COUNT(*) AS RowCount FROM Permission
UNION ALL
SELECT 'RolePermission', COUNT(*) FROM RolePermission;
GO
