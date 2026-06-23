using KLS.Models;
using KLS.Services.Marketplace.ShipStation;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Webhook
{
    [ApiController]
    [Route("api/webhook/shipstation")]
    public class ShipStationWebhookController : ControllerBase
    {
        private readonly ShipStationWebhookService _webhookService;

        public ShipStationWebhookController(ShipStationWebhookService webhookService)
        {
            _webhookService = webhookService;
        }

        [HttpPost("{marketAccountId}/{secret}")]
        public async Task<IActionResult> Receive(
            int marketAccountId,
            string secret,
            [FromBody] ShipStationWebhookPayload payload,
            CancellationToken ct)
        {
            try
            {
                if (payload == null || string.IsNullOrEmpty(payload.resource_url))
                    return Ok();

                await _webhookService.ProcessWebhookAsync(marketAccountId, secret, payload, ct);
            }
            catch
            {
                // Swallow all errors — always return 200 to prevent ShipStation retries
            }

            return Ok();
        }
    }
}
