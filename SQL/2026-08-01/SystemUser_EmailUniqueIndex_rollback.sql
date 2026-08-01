SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    2026-08-01  Rollback for SystemUser_EmailUniqueIndex.sql

    Drops the unique filtered index on SystemUser.Email.
    Does not touch the Email column or any data.
*/

DROP INDEX IF EXISTS UX_SystemUser_Email ON dbo.SystemUser;
GO
