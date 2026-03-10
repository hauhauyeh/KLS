CREATE TABLE TempSalesPromo (
    TempSalesPromoId INT IDENTITY(1,1) PRIMARY KEY,
    OwnerTempSalesId INT NOT NULL,
    PromoTempSalesId INT NOT NULL,
    PromotionId      INT NOT NULL,
    PromotionBogoId  INT NOT NULL,
    CONSTRAINT FK_TempSalesPromo_Owner FOREIGN KEY (OwnerTempSalesId) REFERENCES TempSales(TempSalesId),
    CONSTRAINT FK_TempSalesPromo_Promo FOREIGN KEY (PromoTempSalesId) REFERENCES TempSales(TempSalesId),
    CONSTRAINT UQ_TempSalesPromo_OwnerBogo UNIQUE (OwnerTempSalesId, PromotionBogoId)
);

CREATE INDEX IX_TempSalesPromo_Owner ON TempSalesPromo(OwnerTempSalesId);
CREATE INDEX IX_TempSalesPromo_Promo ON TempSalesPromo(PromoTempSalesId);
