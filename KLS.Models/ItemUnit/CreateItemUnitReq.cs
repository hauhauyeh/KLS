namespace KLS.Models
{
    // Payload for creating a non-base unit WITH its ratio already set (the draft-row add flow in the unit view).
    // Replaces the old auto-name / 1:1 CreateUnit(itemId) that produced immutable "unit2" junk. The ratio must be
    // valid at creation because it is immutable afterward (A.5).
    public class CreateItemUnitReq
    {
        public int ItemId { get; set; }
        public string? Unit { get; set; }
        public decimal FactorToBase { get; set; } = 1;   // denominator (÷N => FactorToBase=N, MultipleToBase=1)
        public int MultipleToBase { get; set; } = 1;      // numerator   (×N => MultipleToBase=N, FactorToBase=1)
        public decimal? P1 { get; set; }                  // optional; defaulted from base P1 + markup when null
        public decimal? PricePercentToBase { get; set; }  // optional; defaulted from ITEM_DEFAULT_RETAILPROFIT
        public string? Barcode { get; set; }
    }
}
