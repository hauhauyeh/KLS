SET QUOTED_IDENTIFIER ON;
GO

-- 1. Customer table — Stripe customer ID
ALTER TABLE Customer ADD StripeId NVARCHAR(255) NULL;

-- 2. PaymentMethod table — encrypted Stripe PaymentMethod ID
ALTER TABLE PaymentMethod ADD StripePmId NVARCHAR(500) NULL;

-- 3. Insert Stripe gateway config (inactive until keys are set)
INSERT INTO PaymentGateway (GatewayCode, GatewayName, Environment, IsActive, ClientKey, AccessToken, MerchantId, Version, Notes, CreatedAt)
VALUES ('STRIPE', 'Stripe', 'Sandbox', 0, '<pk_test_xxx>', '<sk_test_xxx>', NULL, NULL,
        'ClientKey = Publishable Key, AccessToken = Secret Key', GETUTCDATE());
