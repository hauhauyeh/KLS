using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using System.Text.Json;

namespace KLS.Services
{
    public class SalesOrderDocumentStageEffectService : BaseService, ISalesOrderDocumentStageEffectService
    {
        private static readonly IReadOnlyDictionary<string, int> AllowedStageEffects = new Dictionary<string, int>
        {
            [SalesOrderDocumentActionKeys.EmailInvoice] = 4,
            [SalesOrderDocumentActionKeys.GenPickTicket] = 2
        };

        private readonly ISystemSettingService _systemSettingService;
        private readonly ISalesStageService _salesStageService;

        public SalesOrderDocumentStageEffectService(
            IUnitOfWork uow,
            ISystemSettingService systemSettingService,
            ISalesStageService salesStageService) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _salesStageService = salesStageService;
        }

        public void ApplyAfterSuccess(int salesId, string actionKey)
        {
            if (salesId <= 0 || !AllowedStageEffects.TryGetValue(actionKey, out var allowedStageId))
                return;

            var configuredStageId = GetConfiguredStageId(actionKey);
            if (configuredStageId != allowedStageId)
                return;

            if (allowedStageId == 4)
            {
                Uow.Sales.UpdateStage(salesId, 4);
                return;
            }

            if (allowedStageId == 3)
            {
                _salesStageService.MarkInvoicePrinted(salesId);
                return;
            }

            if (allowedStageId == 2)
                _salesStageService.MarkPickTicketPrinted(salesId);
        }

        private int? GetConfiguredStageId(string actionKey)
        {
            var json = _systemSettingService.GetByKey<string>(GlobalKey.SALES_ORDER_DOCUMENT_MENU_JSON);
            if (string.IsNullOrWhiteSpace(json))
                return null;

            try
            {
                using var document = JsonDocument.Parse(json);
                if (document.RootElement.ValueKind != JsonValueKind.Object ||
                    !document.RootElement.TryGetProperty("singleOrder", out var singleOrder) ||
                    singleOrder.ValueKind != JsonValueKind.Object)
                    return null;

                if (!singleOrder.TryGetProperty(actionKey, out var action) ||
                    action.ValueKind != JsonValueKind.Object)
                    return null;

                if (!action.TryGetProperty("visible", out var visible) ||
                    visible.ValueKind != JsonValueKind.True)
                    return null;

                if (!action.TryGetProperty("stageIdAfterSuccess", out var stageId) ||
                    !stageId.TryGetInt32(out var configuredStageId))
                    return null;

                return configuredStageId;
            }
            catch (JsonException)
            {
                return null;
            }
        }
    }
}
