USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CRM Phase 1 (plan-crm-phase-1-followup-completion-lifecycle)
-- Adds explicit lifecycle columns to CRMFollowUp:
--   CreatedFromActivityId = activity that caused this follow-up
--   CompletedActivityId   = activity created when it was completed
-- Legacy ActivityId stays as-is (read-only legacy, ambiguous meaning).
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('CRMFollowUp') AND name = 'CreatedFromActivityId')
BEGIN
    ALTER TABLE [dbo].[CRMFollowUp] ADD [CreatedFromActivityId] INT NULL;
    ALTER TABLE [dbo].[CRMFollowUp] ADD CONSTRAINT [FK_CRMFollowUp_CreatedFromActivity]
        FOREIGN KEY ([CreatedFromActivityId]) REFERENCES [CRMActivity]([ActivityId]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('CRMFollowUp') AND name = 'CompletedActivityId')
BEGIN
    ALTER TABLE [dbo].[CRMFollowUp] ADD [CompletedActivityId] INT NULL;
    ALTER TABLE [dbo].[CRMFollowUp] ADD CONSTRAINT [FK_CRMFollowUp_CompletedActivity]
        FOREIGN KEY ([CompletedActivityId]) REFERENCES [CRMActivity]([ActivityId]);
END
GO

-- ============================================================
-- ROLLBACK (run manually if needed):
-- ALTER TABLE [dbo].[CRMFollowUp] DROP CONSTRAINT [FK_CRMFollowUp_CreatedFromActivity];
-- ALTER TABLE [dbo].[CRMFollowUp] DROP COLUMN [CreatedFromActivityId];
-- ALTER TABLE [dbo].[CRMFollowUp] DROP CONSTRAINT [FK_CRMFollowUp_CompletedActivity];
-- ALTER TABLE [dbo].[CRMFollowUp] DROP COLUMN [CompletedActivityId];
-- ============================================================
