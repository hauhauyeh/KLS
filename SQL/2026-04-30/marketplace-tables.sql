-- Marketplace Integration Tables
-- Run against KLS_Latest database

-- 1. MarketAccount — Marketplace connection accounts (Amazon, eBay, Walmart, etc.)
CREATE TABLE [dbo].[MarketAccount] (
    [MarketAccountId]   INT             IDENTITY(1,1) NOT NULL,
    [MarketType]        VARCHAR(50)     NOT NULL,
    [AccountName]       NVARCHAR(200)   NOT NULL,
    [StoreCode]         VARCHAR(100)    NULL,
    [RegionCode]        VARCHAR(50)     NULL,
    [ApiBaseUrl]        VARCHAR(500)    NULL,
    [SettingsJson]      NVARCHAR(MAX)   NULL,       -- AES-encrypted JSON credentials
    [IsActive]          BIT             NOT NULL DEFAULT 1,
    [LastSyncAt]        DATETIME2       NULL,
    [LastSyncStatus]    VARCHAR(20)     NULL,
    [LastError]         NVARCHAR(1000)  NULL,
    [Notes]             NVARCHAR(500)   NULL,
    [CreatedAt]         DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    [UpdatedAt]         DATETIME2       NULL,
    CONSTRAINT [PK_MarketAccount] PRIMARY KEY CLUSTERED ([MarketAccountId])
);

-- 2. MarketItemMap — Maps ERP Items to marketplace SKUs/listings
CREATE TABLE [dbo].[MarketItemMap] (
    [MarketItemMapId]       INT             IDENTITY(1,1) NOT NULL,
    [MarketAccountId]       INT             NOT NULL,
    [ItemId]                INT             NOT NULL,
    [ItemUnitId]            INT             NULL,
    [ExternalSku]           VARCHAR(100)    NULL,
    [ExternalListingId]     VARCHAR(200)    NULL,
    [ExternalVariantId]     VARCHAR(200)    NULL,
    [ExternalItemName]      NVARCHAR(500)   NULL,
    [MappingStatus]         VARCHAR(20)     NOT NULL DEFAULT 'mapped',
    [IsActive]              BIT             NOT NULL DEFAULT 1,
    [LastSyncAt]            DATETIME2       NULL,
    [LastSyncStatus]        VARCHAR(20)     NULL,
    [LastError]             NVARCHAR(1000)  NULL,
    [LastPriceSyncAt]       DATETIME2       NULL,
    [LastPriceSyncStatus]   VARCHAR(20)     NULL,
    [LastInventorySyncAt]   DATETIME2       NULL,
    [LastInventorySyncStatus] VARCHAR(20)   NULL,
    [CreatedAt]             DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    [UpdatedAt]             DATETIME2       NULL,
    CONSTRAINT [PK_MarketItemMap] PRIMARY KEY CLUSTERED ([MarketItemMapId]),
    CONSTRAINT [FK_MarketItemMap_Account] FOREIGN KEY ([MarketAccountId]) REFERENCES [dbo].[MarketAccount]([MarketAccountId]),
    CONSTRAINT [UQ_MarketItemMap_Account_Sku] UNIQUE ([MarketAccountId], [ExternalSku])
);

-- 3. MarketOrder — Orders pulled from marketplaces
CREATE TABLE [dbo].[MarketOrder] (
    [MarketOrderId]         INT             IDENTITY(1,1) NOT NULL,
    [MarketAccountId]       INT             NOT NULL,
    [ExternalOrderId]       VARCHAR(100)    NOT NULL,
    [ExternalOrderNo]       VARCHAR(100)    NULL,
    [ExternalCustomerId]    VARCHAR(100)    NULL,
    [OrderDate]             DATETIME2       NULL,
    [OrderStatus]           VARCHAR(50)     NOT NULL DEFAULT 'pending',
    [CustomerName]          NVARCHAR(200)   NULL,
    [CustomerEmail]         NVARCHAR(200)   NULL,
    [Phone]                 VARCHAR(50)     NULL,
    [ShipToName]            NVARCHAR(200)   NULL,
    [ShipToCompany]         NVARCHAR(200)   NULL,
    [ShipToAddress1]        NVARCHAR(255)   NULL,
    [ShipToAddress2]        NVARCHAR(255)   NULL,
    [ShipToCity]            NVARCHAR(100)   NULL,
    [ShipToState]           NVARCHAR(100)   NULL,
    [ShipToPostalCode]      VARCHAR(30)     NULL,
    [ShipToCountry]         NVARCHAR(100)   NULL,
    [CurrencyCode]          VARCHAR(10)     NULL,
    [Subtotal]              DECIMAL(18,2)   NULL,
    [ShippingAmount]        DECIMAL(18,2)   NULL,
    [TaxAmount]             DECIMAL(18,2)   NULL,
    [DiscountAmount]        DECIMAL(18,2)   NULL,
    [OrderTotal]            DECIMAL(18,2)   NULL,
    [ErpSalesId]            INT             NULL,
    [ImportedToErp]         BIT             NOT NULL DEFAULT 0,
    [ImportedToErpAt]       DATETIME2       NULL,
    [RawJson]               NVARCHAR(MAX)   NULL,
    [LastSyncAt]            DATETIME2       NULL,
    [LastSyncStatus]        VARCHAR(20)     NULL,
    [LastError]             NVARCHAR(1000)  NULL,
    [CreatedAt]             DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    [UpdatedAt]             DATETIME2       NULL,
    CONSTRAINT [PK_MarketOrder] PRIMARY KEY CLUSTERED ([MarketOrderId]),
    CONSTRAINT [FK_MarketOrder_Account] FOREIGN KEY ([MarketAccountId]) REFERENCES [dbo].[MarketAccount]([MarketAccountId]),
    CONSTRAINT [UQ_MarketOrder_Account_ExternalOrderId] UNIQUE ([MarketAccountId], [ExternalOrderId])
);

-- 4. MarketOrderItem — Line items for marketplace orders
CREATE TABLE [dbo].[MarketOrderItem] (
    [MarketOrderItemId]     INT             IDENTITY(1,1) NOT NULL,
    [MarketOrderId]         INT             NOT NULL,
    [ExternalLineId]        VARCHAR(100)    NULL,
    [ExternalSku]           VARCHAR(100)    NULL,
    [ExternalListingId]     VARCHAR(200)    NULL,
    [ExternalVariantId]     VARCHAR(200)    NULL,
    [ExternalItemName]      NVARCHAR(500)   NULL,
    [ItemId]                INT             NULL,
    [ItemUnitId]            INT             NULL,
    [MarketItemMapId]       INT             NULL,
    [Qty]                   DECIMAL(18,3)   NOT NULL DEFAULT 0,
    [UnitPrice]             DECIMAL(18,2)   NULL,
    [DiscountAmount]        DECIMAL(18,2)   NULL,
    [TaxAmount]             DECIMAL(18,2)   NULL,
    [LineTotal]             DECIMAL(18,2)   NULL,
    [MatchStatus]           VARCHAR(20)     NOT NULL DEFAULT 'unmatched',
    [Notes]                 NVARCHAR(500)   NULL,
    [CreatedAt]             DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    [UpdatedAt]             DATETIME2       NULL,
    CONSTRAINT [PK_MarketOrderItem] PRIMARY KEY CLUSTERED ([MarketOrderItemId]),
    CONSTRAINT [FK_MarketOrderItem_Order] FOREIGN KEY ([MarketOrderId]) REFERENCES [dbo].[MarketOrder]([MarketOrderId])
);

-- 5. MarketSyncLog — Sync operation logs
CREATE TABLE [dbo].[MarketSyncLog] (
    [MarketSyncLogId]       INT             IDENTITY(1,1) NOT NULL,
    [MarketAccountId]       INT             NOT NULL,
    [SyncType]              VARCHAR(50)     NOT NULL,
    [StartedAt]             DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    [FinishedAt]            DATETIME2       NULL,
    [Success]               BIT             NULL,
    [RecordsProcessed]      INT             NULL,
    [RecordsSucceeded]      INT             NULL,
    [RecordsFailed]         INT             NULL,
    [ReferenceNo]           VARCHAR(100)    NULL,
    [ErrorMessage]          NVARCHAR(MAX)   NULL,
    [PayloadSummary]        NVARCHAR(MAX)   NULL,
    [CreatedAt]             DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_MarketSyncLog] PRIMARY KEY CLUSTERED ([MarketSyncLogId]),
    CONSTRAINT [FK_MarketSyncLog_Account] FOREIGN KEY ([MarketAccountId]) REFERENCES [dbo].[MarketAccount]([MarketAccountId])
);

-- Indexes for common queries
CREATE NONCLUSTERED INDEX [IX_MarketItemMap_AccountId] ON [dbo].[MarketItemMap]([MarketAccountId]);
CREATE NONCLUSTERED INDEX [IX_MarketOrder_AccountId] ON [dbo].[MarketOrder]([MarketAccountId]);
CREATE NONCLUSTERED INDEX [IX_MarketOrder_OrderDate] ON [dbo].[MarketOrder]([OrderDate]);
CREATE NONCLUSTERED INDEX [IX_MarketOrderItem_OrderId] ON [dbo].[MarketOrderItem]([MarketOrderId]);
CREATE NONCLUSTERED INDEX [IX_MarketSyncLog_AccountId] ON [dbo].[MarketSyncLog]([MarketAccountId]);
