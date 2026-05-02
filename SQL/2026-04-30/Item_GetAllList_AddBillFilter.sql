
CREATE PROCEDURE [dbo].[Item_GetAllList]
	@Pageno INT,
	@Pagesize INT,
	@Search NVARCHAR(200),
	@StartDate DATE,
	@EndDate DATE,
	@VendorId INT,
	@Container NVARCHAR(50),
	@CategoryId INT = NULL,
	@Filterby NVARCHAR(50),
	@Id INT,
	@SortField NVARCHAR(50)
