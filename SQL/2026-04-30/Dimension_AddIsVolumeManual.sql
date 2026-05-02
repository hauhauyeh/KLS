-- Add IsVolumeManual flag to Item table for dimension view
ALTER TABLE Item ADD IsVolumeManual BIT NOT NULL DEFAULT 0;
GO
