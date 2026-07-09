-- =============================================================================
-- recalcqav_1_save_prev.sql   (prod-cutover toolkit -- step 1)
-- Run BEFORE the RecalcQAV cutover. Saves the CURRENTLY-deployed RecalcQAV as
-- dbo.RecalcQAV_prev for a fast proc-level rollback.
--
-- GENERIC: captures whatever RecalcQAV body is live on THIS server (local/dev/prod),
-- so it is always correct. (The full DB backup is still the primary rollback.)
-- =============================================================================
SET NOCOUNT ON;

IF OBJECT_ID('dbo.RecalcQAV') IS NULL
BEGIN
    RAISERROR('dbo.RecalcQAV not found on this server -- nothing to save.', 16, 1);
    RETURN;
END

DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.RecalcQAV'));
DECLARE @hdr NVARCHAR(60) = 'PROCEDURE [dbo].[RecalcQAV]';

-- Fail loudly if the CREATE header isn't in the expected form -- then do it by hand
-- (SSMS: right-click RecalcQAV -> Script Procedure as -> CREATE To, rename to RecalcQAV_prev).
IF CHARINDEX(@hdr, @def) = 0
BEGIN
    RAISERROR('RecalcQAV header "%s" not found -- save RecalcQAV_prev manually (SSMS Script as CREATE).', 16, 1, @hdr);
    RETURN;
END

-- rename the header proc name -> RecalcQAV_prev (first occurrence only), force CREATE OR ALTER
SET @def = STUFF(@def, CHARINDEX(@hdr, @def), LEN(@hdr), 'PROCEDURE [dbo].[RecalcQAV_prev]');
IF CHARINDEX('CREATE OR ALTER', @def) = 0
    SET @def = STUFF(@def, CHARINDEX('CREATE', @def), LEN('CREATE'), 'CREATE OR ALTER');

EXEC sys.sp_executesql @def;
PRINT 'Saved the current RecalcQAV as dbo.RecalcQAV_prev.';
GO
