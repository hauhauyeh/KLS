
CREATE TABLE BankFeedMatch (
    BankFeedMatchId BIGINT IDENTITY(1,1) PRIMARY KEY,
    BankFeedTransactionId BIGINT NOT NULL,
    TxId BIGINT NOT NULL,
    TxDetailId BIGINT NOT NULL,
    CONSTRAINT FK_BankFeedMatch_BankFeedTx
        FOREIGN KEY (BankFeedTransactionId)
        REFERENCES BankFeedTransaction(BankFeedTransactionId),
    CONSTRAINT FK_BankFeedMatch_TxDetail
        FOREIGN KEY (TxDetailId)
        REFERENCES TransactionJournalDetail(TxDetailId),
    CONSTRAINT UQ_BankFeedMatch_TxDetailId
        UNIQUE (TxDetailId)
);
GO

CREATE INDEX IX_BankFeedMatch_BankFeedTransactionId
    ON BankFeedMatch(BankFeedTransactionId);
GO

-- Migrate existing single-match data
INSERT INTO BankFeedMatch (BankFeedTransactionId, TxId, TxDetailId)
SELECT BankFeedTransactionId, MatchedTxId, MatchedTxDetailId
FROM BankFeedTransaction
WHERE MatchedTxId IS NOT NULL AND MatchedTxDetailId IS NOT NULL;
GO
