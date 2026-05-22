
CREATE PROCEDURE [dbo].[Scheduler_ImportDriverTimesheet]

AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    DECLARE @TimeTable AS TABLE
    (
        Id INT IDENTITY(1,1),
        ShipDate DATE,
        ShipRoute NVARCHAR(10),
        DriverId INT
    )

    DECLARE @MaxRow INT
    DECLARE @RowNum INT=1
    DECLARE @ShipDate DATETIME
    DECLARE @ShipRoute NVARCHAR(10)
    DECLARE @DriverId INT
    DECLARE @TimesheetNumber INT
    DECLARE @TimesheetId INT
    DECLARE @JobRate DECIMAL(18,2)
    DECLARE @CompanyTimezone NVARCHAR(100)

    SELECT @CompanyTimezone = Timezone FROM Company
    SELECT @JobRate=JobRate FROM EmpJob WHERE JobCode='D'

    INSERT INTO @TimeTable
    SELECT s.ShipDate,s.ShipRoute,s.DriverId
    FROM SalesRoute AS s
    WHERE s.ShipDate=CONVERT(date,GETDATE()) and s.Driver is not null

    SELECT @MaxRow=COUNT(*) FROM @TimeTable

    WHILE @RowNum<=@MaxRow
    BEGIN
        SELECT @ShipDate=ShipDate,@ShipRoute=ShipRoute,@DriverId=DriverId FROM @TimeTable WHERE Id=@RowNum

        SET @TimesheetNumber = NEXT VALUE FOR dbo.Seq_TimesheetNumber;

        -- Convert 9:00 AM local time to UTC
        SET @ShipDate = (SELECT CAST(@ShipDate AS DATETIME) + '09:00:00'
            AT TIME ZONE @CompanyTimezone AT TIME ZONE 'UTC')

        INSERT INTO [dbo].[Timesheet]
           ([TimesheetNumber]
           ,[PayeeId]
           ,[InTime]
           ,[CreatedAt])
        VALUES
           (@TimesheetNumber
           ,@DriverId
           ,@ShipDate
           ,GETUTCDATE())

        SELECT @TimesheetId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[TimesheetDetail]
           ([TimesheetId]
           ,[JobCode]
           ,[Qty]
           ,[JobRate]
           ,[ExtTotal]
           ,[Route])
        VALUES(
           @TimesheetId
           ,'D'
           ,1
           ,@JobRate
           ,@JobRate
           ,@ShipRoute)

        SET @RowNum+=1
    END
END

