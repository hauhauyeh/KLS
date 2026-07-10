CREATE PROCEDURE [dbo].[TempBombSales_Inject]

	@DateRange NVARCHAR(50),
	@ShipDate DATE,
	@ItemId INT,
	@ShipQty DECIMAL(18,2),
	@Unit NVARCHAR(50),
	@Price DECIMAL(18,2),
	@ShipRoute NVARCHAR(20),
	@PayeeId INT,
	@SalesNumber INT,
	@IsPound BIT,
	@EmpId INT
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);
	DECLARE @GetDate DATE=GETDATE()	
	DECLARE @FromDate DATE = NULL;
	DECLARE @ToDate   DATE = NULL;   -- inclusive end (we'll use <=)


	SET @Qry =
        'SELECT
            ' + CONVERT(VARCHAR, @EmpId) + ',
            s.SalesId,
            s.ShipId,
            sd.ItemId,
			sd.ItemUnitId,
			sd.Unit,
            sd.OrdQty,
            sd.ShipQty,
            sd.BillQty,
            sd.UnitPrice,
            sd.Notes,
            sd.IsTaxable,
			sd.IsUserOverWrite,
			sd.OrgPrice,
			sd.DiscountPercent,
			sd.FactorToBase,
            sd.SalesDetailId,
            CASE WHEN (sd.BillQty=0 AND sd.ShipQty!=0) THEN 1 ELSE 0 END, --Free
		    CASE WHEN (sd.BillQty=0 AND sd.ShipQty=0) THEN 1 ELSE 0 END,  --Out
		    CASE WHEN (sd.BillQty!=0 AND sd.ShipQty=0) THEN 1 ELSE 0 END --Credit
        FROM Sales AS s
        INNER JOIN SalesDetail AS sd
            ON s.SalesId = sd.SalesId
        LEFT JOIN Item AS i
            ON sd.ItemId = i.ItemId
        LEFT JOIN Payee AS p
            ON s.ShipId = p.PayeeId
        WHERE 1 = 1';

	IF @ShipDate IS NOT NULL
    BEGIN
        SET @FromDate = @ShipDate;
        SET @ToDate   = @ShipDate;
    END
    ELSE IF @DateRange IS NOT NULL
    BEGIN
        SET @DateRange = UPPER(LTRIM(RTRIM(@DateRange)));

        IF @DateRange = 'TODAY'
        BEGIN
            SET @FromDate = @GetDate;
            SET @ToDate   = @GetDate;
        END
        ELSE IF @DateRange = 'TOMORROW'
        BEGIN
            SET @FromDate = DATEADD(DAY, 1, @GetDate);
            SET @ToDate   = DATEADD(DAY, 1, @GetDate);
        END
        ELSE IF @DateRange = 'YESTERDAY'
        BEGIN
            SET @FromDate = DATEADD(DAY, -1, @GetDate);
            SET @ToDate   = DATEADD(DAY, -1, @GetDate);
        END
        ELSE IF @DateRange = 'BEFOREYESTERDAY'
        BEGIN
            SET @FromDate = DATEADD(DAY, -2, @GetDate);
            SET @ToDate   = DATEADD(DAY, -2, @GetDate);
        END
        ELSE IF @DateRange = 'TODAY>'
        BEGIN
            SET @FromDate = DATEADD(DAY, 1, @GetDate); -- strictly greater than today
            SET @ToDate   = NULL;
        END
        ELSE IF @DateRange = 'TODAY<'
        BEGIN
            SET @FromDate = NULL;
            SET @ToDate   = DATEADD(DAY, -1, @GetDate); -- strictly less than today
        END
        ELSE IF @DateRange = 'PAST7'
        BEGIN
            SET @FromDate = DATEADD(DAY, -7, @GetDate);
            SET @ToDate   = @GetDate;
        END
        ELSE IF @DateRange = 'PAST30'
        BEGIN
            SET @FromDate = DATEADD(DAY, -30, @GetDate);
            SET @ToDate   = @GetDate;
        END
    END

    -- Add only one (or two) predicates
    IF @FromDate IS NOT NULL
        SET @Qry += ' AND s.ShipDate >= ''' + CONVERT(VARCHAR(10), @FromDate, 120) + '''';

    IF @ToDate IS NOT NULL
        SET @Qry += ' AND s.ShipDate <= ''' + CONVERT(VARCHAR(10), @ToDate, 120) + '''';

	--IF @ShipDate IS NOT NULL
	--	SET @Qry += ' AND s.ShipDate='''+CONVERT(VARCHAR,@ShipDate)+'''' 

	IF @ItemId IS NOT NULL
		SET @Qry += ' AND sd.ItemId='+ CONVERT(VARCHAR,@ItemId) +''

	IF @ShipQty IS NOT NULL
		SET @Qry += ' AND sd.ShipQty='+ CONVERT(VARCHAR,@ShipQty) +''

	IF @Unit IS NOT NULL
		SET @Qry += ' AND sd.Unit='''+ @Unit +''''

	IF @Price IS NOT NULL AND @IsPound=0
		SET @Qry += ' AND sd.UnitPrice='+ CONVERT(VARCHAR,@Price) +''

	--check zero weight like shrimp
	IF @Price IS NOT NULL AND @IsPound=1
		SET @Qry += ' AND (sd.UnitPrice='+ CONVERT(VARCHAR,@Price) +' OR ((sd.Unit=''lb'' and sd.ShipQty=1 and sd.IsUserOverWrite=0)) OR (sd.Unit=''lbs'' and sd.ShipQty>=1 and sd.IsUserOverWrite=0))'

	IF @ShipRoute IS NOT NULL
		SET @Qry += ' AND s.ShipRoute ='''+ CONVERT(VARCHAR,@ShipRoute) +''''

	IF @SalesNumber IS NOT NULL
		SET @Qry += ' AND s.SalesNumber ='+ CONVERT(VARCHAR,@SalesNumber) +''

	IF @PayeeId IS NOT NULL
		SET @Qry += ' AND s.ShipId ='+ CONVERT(VARCHAR,@PayeeId) +''


	SET @Qry+=' ORDER BY s.ShipDate DESC,s.ShipRoute,p.PayeeName,s.SalesNumber'

	DELETE FROM TempBombSales WHERE EmpId=@EmpId

	INSERT INTO [dbo].[TempBombSales]
           ([EmpId]
           ,[SalesId]
           ,[PayeeId]
           ,[ItemId]
		   ,[ItemUnitId]
		   ,[Unit]
		   ,[OrdQty]
		   ,[ShipQty]
		   ,[BillQty]
		   ,[UnitPrice]
		   ,[Notes]
		   ,[IsTaxable]
		   ,[IsUserOverWrite]
		   ,[OrgPrice]
		   ,[DiscountPercent]
		   ,[FactorToBase]
		   ,[SalesDetailId]
           ,[IsFree]
           ,[IsOut]
           ,[IsCRCG])
	EXEC(@Qry)

END


