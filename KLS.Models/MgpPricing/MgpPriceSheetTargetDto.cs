namespace KLS.Models;

public record MgpPriceSheetTargetDto(
    int SheetNo,
    string CustomerName,
    int PayeeId,
    bool HasOwnList);
