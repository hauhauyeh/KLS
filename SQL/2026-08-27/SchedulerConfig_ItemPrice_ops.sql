-- ============================================================
-- SchedulerConfig_ItemPrice_ops  (2026-08-27)  ** OPS - separate explicit go **
--
-- Turns the weekly price update on:
--   'Update Item Prices'     -> Scheduler_UpdateItemPrice   (Mon 06:00)   ENABLE
--   'Update Event On Holiday'-> Scheduler_ChangePriceUpdate (daily 23:50) ENABLE
--                               shifts the Monday job to Tuesday when Monday
--                               is in dbo.Holiday (table is EMPTY today:
--                               enter holidays or nothing shifts)
--   'Update Price Flag'      -> Scheduler_UpdatePriceFlag   (SP missing)   DISABLE
--                               not needed: "already updated" is derived from
--                               ItemCostApply (plan D11). Row kept, not deleted.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

UPDATE dbo.SchedulerConfig
SET IsEnabled = 1, UpdatedAt = GETDATE()
WHERE JobName IN ('Update Item Prices', 'Update Event On Holiday');

UPDATE dbo.SchedulerConfig
SET IsEnabled = 0, UpdatedAt = GETDATE()
WHERE JobName = 'Update Price Flag';

SELECT JobName, SpName, Frequency, DayOfWeek, RunTime, IsEnabled
FROM dbo.SchedulerConfig
WHERE JobName IN ('Update Item Prices', 'Update Event On Holiday', 'Update Price Flag');
GO
