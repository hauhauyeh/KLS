CREATE OR ALTER PROCEDURE [dbo].[Report_Harvills] --[Report_Harvills] '3/3/2020'
	
	@ShipDate DATE
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	/*
	    2026-05-04 live baseline note:
	    The previous live version excluded these cooler sections in SQL:
	    - Tofu
	    - Misc
	    - Meats

	    The Harvills service then applied a second service-side filter to remove
	    Asian after SQL returned it. That made the report scope split between SQL
	    and backend code.

	    Old live SQL filter:
	        AND st.Zone='Cooler' AND st.Section NOT IN ('Tofu','Misc','Meats')
	*/

	SELECT
		sd.SalesDetailId AS Id,
		i.ItemId,
		s.ShipDate,
		st.Section,
		i.ItemName,
		sd.Notes AS Comment,
		sd.ShipQty,
		sd.Unit
	FROM Sales AS s
	INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
	INNER JOIN Item AS i ON sd.ItemId = i.ItemId
	LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
	WHERE s.ShipDate = @ShipDate
	  AND sd.ShipQty > 0
	  AND st.Zone = 'Cooler'
	  AND st.Section NOT IN ('Tofu', 'Misc', 'Meats', 'Asian')
	ORDER BY st.SortOrder, i.ItemName

END
