SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [dbo].[Fn_GetUPC](@BarcodeW NVARCHAR(50)) -- SELECT * FROM dbo.Fn_GetUPC('CABGRSH5')

	RETURNS @Results TABLE (UPC NVARCHAR(50))
AS
BEGIN
	
	DECLARE @UPCLen INT
	DECLARE @UPC NVARCHAR(50)
	DECLARE @i INT = 1

	-- 2026-09-02 BADBARCODE-GUARD: some ItemUnit.Barcode values are item codes, not barcodes
	-- (e.g. 'CABGRSH5'). The 11- and 8-char branches below CAST each character to INT for the
	-- check digit, so any letter crashed invoice generation with a varchar-to-int conversion
	-- error. A barcode that is NULL, empty, or contains any non-digit can never be a valid
	-- UPC/EAN: return a single NULL row instead of reaching those branches.
	IF @BarcodeW IS NULL OR LTRIM(RTRIM(@BarcodeW)) = '' OR @BarcodeW LIKE '%[^0-9]%'
	BEGIN
		INSERT INTO @Results(UPC) VALUES(NULL)
		RETURN
	END

	SELECT @UPCLen=LEN(@BarcodeW)

	IF @UPCLen=12
		SET @UPC='0'+@BarcodeW
	ELSE IF @UPCLen=13
		SET @UPC=@BarcodeW
	ELSE IF @UPCLen=11
	BEGIN
		DECLARE @Checksum INT

		-- Create a table variable to store positions (1 to 11)
		DECLARE @Digits TABLE(Digit INT, Position INT)

		 -- Populate the @Digits table manually
		WHILE @i <= 11
		BEGIN
			INSERT INTO @Digits (Digit, Position)
			VALUES (CAST(SUBSTRING(@BarcodeW, @i, 1) AS INT), @i)
			SET @i = @i + 1
		END

		-- Calculate the checksum digit
		SELECT @Checksum = (10 - (SUM(CASE WHEN Position % 2 = 1 THEN Digit * 3 ELSE Digit END) % 10)) % 10
		FROM @Digits

		-- Construct the full UPC-A barcode
		SET @UPC = @BarcodeW + CAST(@Checksum AS VARCHAR(1))
	END
	ELSE IF @UPCLen=8
	BEGIN
		DECLARE @FirstDigit CHAR(1) = LEFT(@BarcodeW, 1);
		DECLARE @ManufacturerCode CHAR(5) = SUBSTRING(@BarcodeW, 2, 5);
		DECLARE @LastDigit CHAR(1) = SUBSTRING(@BarcodeW, 7, 1);
		DECLARE @UpcA CHAR(12);	
    
		-- Expand UPC-E to UPC-A (12-digit) based on rules
		IF @LastDigit IN ('0', '1', '2')
			SET @UpcA = @FirstDigit + LEFT(@ManufacturerCode, 2) + '00' + RIGHT(@ManufacturerCode, 3) + @LastDigit;
		ELSE IF @LastDigit = '3'
			SET @UpcA = @FirstDigit + LEFT(@ManufacturerCode, 3) + '00000' + RIGHT(@ManufacturerCode, 2);
		ELSE IF @LastDigit = '4'
			SET @UpcA = @FirstDigit + LEFT(@ManufacturerCode, 4) + '00000' + RIGHT(@ManufacturerCode, 1);
		ELSE
			SET @UpcA = @FirstDigit + @ManufacturerCode + '0000' + @LastDigit;

		-- Calculate Check Digit for UPC-A (12th digit)
		DECLARE @CheckDigit INT;
		DECLARE @Sum INT = 0;
		DECLARE @Digit INT;

		WHILE @I <= 11
		BEGIN
			SET @Digit = CAST(SUBSTRING(@UpcA, @I, 1) AS INT);
			SET @Sum = @Sum + CASE WHEN @I % 2 = 1 THEN @Digit * 3 ELSE @Digit END;
			SET @I = @I + 1;
		END

		SET @CheckDigit = (10 - (@Sum % 10)) % 10;
		SET @UpcA = @UpcA + CAST(@CheckDigit AS CHAR(1));

		-- Convert UPC-A (12-digit) to EAN-13 by adding a leading zero
		SET @UPC = '0' + @UpcA;
	END

	INSERT INTO @Results(UPC) VALUES(@UPC)

	RETURN
END

