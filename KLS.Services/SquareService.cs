using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Square;
using Square.Cards;
using Square.Customers;
using Square.Payments;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SquareService : BaseService, ISquareService
    {
        public SquareService(IUnitOfWork uow) : base(uow)
        {
        }

        public async Task<CreateCardResponse> CreateCard(PaymentMethod paymentMethod)
        {
            try
            {
                var customer = Uow.Customers.GetById(paymentMethod.PayeeId);
                var payee = Uow.Payees.GetById(paymentMethod.PayeeId);

                if (string.IsNullOrEmpty(customer.SquareId))
                {
                    var address = new Address
                    {
                        Country = Square.Country.Us
                    };

                    var create = new CreateCustomerRequest
                    {
                        GivenName = payee.PayeeName,
                        EmailAddress = payee.Email,
                        ReferenceId = customer.PayeeId.ToString(),
                        PhoneNumber = payee.Phone1,
                        Address = address
                    };

                    var result = await InitClient().Customers.CreateAsync(create);

                    customer.SquareId = result.Customer.Id;

                    Uow.Customers.Update(customer);
                    Uow.Commit();
                }

                var cardResult = await InitClient().Cards.CreateAsync(
                new CreateCardRequest
                {
                    IdempotencyKey = Guid.NewGuid().ToString(),
                    SourceId = paymentMethod.SQNonce,
                    Card = new Card
                    {
                        BillingAddress = new Address
                        {
                            AddressLine1 = payee.Address,
                            Locality = payee.City,
                            PostalCode = payee.ZipCode,
                            Country = Square.Country.Us
                        },
                        CardholderName = paymentMethod.AccountName,
                        CustomerId = customer.SquareId,
                        ReferenceId = customer.PayeeId.ToString()
                    }
                });

                return cardResult;
            }
            catch (SquareApiException ex)
            {
                var errorMessages = string.Join(", ", ex.Errors.Select(e => e.Detail));
                throw new Exception($"Square API Error: {errorMessages}");
            }
        }

        public async Task<CreatePaymentResponse> ChargePayment(int payeeId, string squareCustomerId, string squareCardId, long amount, string? idempotencyKey = null)
        {
            try
            {
                var client = InitClient();
                var resolvedKey = string.IsNullOrWhiteSpace(idempotencyKey) ? Guid.NewGuid().ToString() : idempotencyKey;

                CreatePaymentRequest request;
                var amountMoney = new Money
                {
                    Amount = amount,
                    Currency = Currency.Usd
                };

                //saved card payment
                if (!string.IsNullOrEmpty(squareCustomerId))
                {
                    var cardId = Utilities.Decrypt(squareCardId);

                    var cardResponse = await client.Cards.GetAsync(new GetCardsRequest
                    {
                        CardId = cardId
                    });

                    request = new CreatePaymentRequest
                    {
                        IdempotencyKey = resolvedKey,
                        AmountMoney = amountMoney,
                        SourceId = cardResponse.Card.Id,
                        Autocomplete = true,
                        CustomerId = Utilities.Decrypt(squareCustomerId),
                        ReferenceId = payeeId.ToString()
                    };
                }
                else
                {
                    request = new CreatePaymentRequest
                    {
                        IdempotencyKey = resolvedKey,
                        AmountMoney = amountMoney,
                        SourceId = squareCardId, //this is square nonce generated from sqaure form
                        Autocomplete = true,
                        ReferenceId = payeeId.ToString()
                    };
                }

                return await client.Payments.CreateAsync(request);
            }
            catch (SquareApiException ex)
            {
                // Give yourself better logs and a clean exception message upstream
                var errors = ex.Errors?.Select(e => $"{e.Detail}").ToArray();
                var msg = errors?.Length > 0
                    ? string.Join(" | ", errors)
                    : ex.Message;

                throw new InvalidOperationException($"Square payment failed: {msg}", ex);
            }
        }

        private SquareClient InitClient()
        {
            var gateway = Uow.PaymentGateways.Find(x => x.GatewayCode == "SQUARE" && x.IsActive).FirstOrDefault();

            if (gateway == null)
                throw new Exception("No active Square gateway configured.");

            if (string.IsNullOrWhiteSpace(gateway.AccessToken))
                throw new Exception("Square AccessToken is missing for the active gateway.");

            string environment;

            switch (gateway.Environment.Trim().ToLower())
            {
                case "production":
                    environment = SquareEnvironment.Production;
                    break;

                case "sandbox":
                    environment = SquareEnvironment.Sandbox;
                    break;

                default:
                    throw new Exception(
                        $"Invalid Square Environment value: {gateway.Environment}. Must be 'Sandbox' or 'Production'.");
            }

            return new SquareClient(gateway.AccessToken, new ClientOptions
            {
                BaseUrl = environment
            });
        }
    }
}
