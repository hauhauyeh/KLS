using KLS.Common;
using KLS.Contract.Services;
using System;
using System.Collections.Generic;
using System.Text.Json;

namespace KLS.Services
{
    public class SalesOrderDocumentStageEffectService : ISalesOrderDocumentStageEffectService
    {
        private static readonly Dictionary<string, int> AllowedStageByAction = new(StringComparer.Ordinal)
        {
            [SalesOrderDocumentActionKeys.GenInvoice] = 3,
            [SalesOrderDocumentActionKeys.EmailInvoice] = 3,
            [SalesOrderDocumentActionKeys.GenPickTicket] = 2
        };

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        private readonly ISystemSettingService _systemSettingService;
        private readonly ISalesStageService _salesStageService;

        public SalesOrderDocumentStageEffectService(
            ISystemSettingService systemSettingService,
            ISalesStageService salesStageService)
        {
            _systemSettingService = systemSettingService;
            _salesStageService = salesStageService;
        }

        public void ApplyAfterSuccess(int salesId, string actionKey)
        {
            var stageId = GetConfiguredAllowedStage(actionKey);

            if (!stageId.HasValue)
                return;

            if (stageId.Value == 3)
                _salesStageService.MarkInvoicePrinted(salesId);
            else if (stageId.Value == 2)
                _salesStageService.MarkPickTicketPrinted(salesId);
        }

        private int? GetConfiguredAllowedStage(string actionKey)
        {
            if (!AllowedStageByAction.TryGetValue(actionKey, out var allowedStageId))
                return null;

            var rawConfig = _systemSettingService.GetByKey<string>(GlobalKey.SALES_ORDER_DOCUMENT_MENU_JSON);

            if (string.IsNullOrWhiteSpace(rawConfig))
                return null;

            SalesOrderDocumentMenuConfig? config;

            try
            {
                config = JsonSerializer.Deserialize<SalesOrderDocumentMenuConfig>(rawConfig, JsonOptions);
            }
            catch (JsonException)
            {
                return null;
            }

            if (config?.SingleOrder == null ||
                !config.SingleOrder.TryGetValue(actionKey, out var actionConfig) ||
                !actionConfig.Visible ||
                actionConfig.StageIdAfterSuccess != allowedStageId)
            {
                return null;
            }

            return allowedStageId;
        }

        private sealed class SalesOrderDocumentMenuConfig
        {
            public Dictionary<string, SalesOrderDocumentActionConfig>? SingleOrder { get; set; }
        }

        private sealed class SalesOrderDocumentActionConfig
        {
            public bool Visible { get; set; }
            public int? StageIdAfterSuccess { get; set; }
        }
    }
}
