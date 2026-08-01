SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ConfirmRun bit = 0;
DECLARE @LocalOnlyStartId int = 100000;
DECLARE @ReseedValue int = @LocalOnlyStartId - 1;

DECLARE @DatabaseName sysname = DB_NAME();
DECLARE @ItemCurrentIdentity numeric(38, 0) = IDENT_CURRENT('dbo.Item');
DECLARE @ItemUnitCurrentIdentity numeric(38, 0) = IDENT_CURRENT('dbo.ItemUnit');
DECLARE @ItemMaxId int = ISNULL((SELECT MAX(ItemId) FROM dbo.Item), 0);
DECLARE @ItemUnitMaxId int = ISNULL((SELECT MAX(ItemUnitId) FROM dbo.ItemUnit), 0);

SELECT
    @DatabaseName AS DatabaseName,
    @LocalOnlyStartId AS LocalOnlyStartId,
    @ReseedValue AS RequestedReseedValue,
    @ItemCurrentIdentity AS ItemCurrentIdentity,
    @ItemMaxId AS ItemMaxId,
    @ItemUnitCurrentIdentity AS ItemUnitCurrentIdentity,
    @ItemUnitMaxId AS ItemUnitMaxId,
    @ConfirmRun AS ConfirmRun;

IF @DatabaseName NOT IN (N'ASAG_2026', N'ASA_2026')
BEGIN
    THROW 51000, 'This seed script must be run only against the downstream ASA target database.', 1;
END;

IF @ItemMaxId >= @LocalOnlyStartId OR @ItemUnitMaxId >= @LocalOnlyStartId
BEGIN
    THROW 51001, 'Target already has Item or ItemUnit rows in the local-only range. Review before reseeding.', 1;
END;

IF @ConfirmRun = 0
BEGIN
    SELECT
        'PreviewOnly' AS Status,
        'Set @ConfirmRun = 1 after review to reseed dbo.Item and dbo.ItemUnit so the next local target identity starts at 100000.' AS Message;
    RETURN;
END;

BEGIN TRANSACTION;

IF @ItemCurrentIdentity < @ReseedValue
BEGIN
    DBCC CHECKIDENT ('dbo.Item', RESEED, 99999) WITH NO_INFOMSGS;
END;

IF @ItemUnitCurrentIdentity < @ReseedValue
BEGIN
    DBCC CHECKIDENT ('dbo.ItemUnit', RESEED, 99999) WITH NO_INFOMSGS;
END;

COMMIT TRANSACTION;

SELECT
    'Completed' AS Status,
    DB_NAME() AS DatabaseName,
    IDENT_CURRENT('dbo.Item') AS ItemCurrentIdentity,
    IDENT_CURRENT('dbo.ItemUnit') AS ItemUnitCurrentIdentity,
    (SELECT MAX(ItemId) FROM dbo.Item) AS ItemMaxId,
    (SELECT MAX(ItemUnitId) FROM dbo.ItemUnit) AS ItemUnitMaxId;
