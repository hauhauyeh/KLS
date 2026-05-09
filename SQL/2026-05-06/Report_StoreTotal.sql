CREATE OR ALTER PROCEDURE [dbo].[Report_StoreTotal] --[Report_StoreTotal] '01/02/2026'
	
	@ShipDate DATE
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	/*
	    2026-05-04 live baseline note:
	    The previous live version returned only a flattened Store Total row shape:
	    - Section
	    - ItemName with Notes already concatenated into the display text
	    - ShipQty
	    - Unit
	    - ShipDate

	    That older shape could not support the newer split-aware packing builder
	    because the source sale/customer identity and raw comment field were gone
	    before the shared packing logic ran.

	    Old live select:
	        SELECT sd.SalesDetailId As Id,
	        st.Section,
	        CASE WHEN sd.Notes IS NOT NULL THEN i.ItemName+' ('+sd.Notes+')' ELSE i.ItemName END AS ItemName,
	        sd.ShipQty,
	        sd.Unit,
	        s.ShipDate
	*/

	SELECT
		sd.SalesDetailId AS Id,
		i.ItemId,
		st.Section,
		i.ItemName,
		sd.Notes AS Comment,
		sd.ShipQty,
		sd.Unit,
		s.ShipDate,
		CAST(s.SalesNumber AS NVARCHAR(50)) AS SalesNumber,
		p.PayeeName
	FROM Sales AS s
	INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
	INNER JOIN Item AS i ON sd.ItemId = i.ItemId
	LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
	LEFT JOIN Payee AS p ON p.PayeeId = s.ShipId
	WHERE s.ShipDate = @ShipDate
	  AND sd.ShipQty > 0
	  AND st.Zone = 'Cooler'
	  AND sd.Unit NOT IN ('cs', 'lbs')
	ORDER BY st.SortOrder, i.ItemName, s.SalesNumber

END
