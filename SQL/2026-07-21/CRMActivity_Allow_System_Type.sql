USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CRM Phase 2 (plan-crm-phase-2-system-activities)
-- CK_CRMActivity_Type only allows Call/Email/Visit/WhatsApp/Note/Meeting.
-- System-generated activities (stage change, conversion) use
-- ActivityType = 'System', so the constraint must include it.
-- ============================================================

ALTER TABLE [dbo].[CRMActivity] DROP CONSTRAINT [CK_CRMActivity_Type];
GO

ALTER TABLE [dbo].[CRMActivity] WITH CHECK ADD CONSTRAINT [CK_CRMActivity_Type]
    CHECK ([ActivityType] IN ('Call','Email','Visit','WhatsApp','Note','Meeting','System'));
GO

-- ============================================================
-- ROLLBACK (run manually if needed; fails if System rows exist):
-- ALTER TABLE [dbo].[CRMActivity] DROP CONSTRAINT [CK_CRMActivity_Type];
-- ALTER TABLE [dbo].[CRMActivity] WITH CHECK ADD CONSTRAINT [CK_CRMActivity_Type]
--     CHECK ([ActivityType] IN ('Call','Email','Visit','WhatsApp','Note','Meeting'));
-- ============================================================
