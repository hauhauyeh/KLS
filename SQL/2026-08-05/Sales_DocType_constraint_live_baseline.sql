CapturedAtUtc=2026-08-05T04:33:14.6576602
Database=KLS-2026
Table=dbo.Sales
Column=DocType char(2) NULL DEFAULT ('SO')
ConstraintName=CK_Sales_DocType
ConstraintDefinition=([DocType]='DM' OR [DocType]='CM' OR [DocType]='SO')

Rollback target:
ALTER TABLE dbo.Sales DROP CONSTRAINT [CK_Sales_DocType];
ALTER TABLE dbo.Sales WITH CHECK ADD CONSTRAINT [CK_Sales_DocType] CHECK ([DocType]='DM' OR [DocType]='CM' OR [DocType]='SO');
ALTER TABLE dbo.Sales CHECK CONSTRAINT [CK_Sales_DocType];
