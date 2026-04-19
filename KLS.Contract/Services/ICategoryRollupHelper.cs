namespace KLS.Contract.Services
{
    /// <summary>
    /// Builds a category tree descendant map once per request. Shared between
    /// HomeService (home-page featured-category item counts) and PromoHelperService
    /// (item-level promo category scope). One place to own the tree walk so both
    /// services stay consistent.
    /// </summary>
    public interface ICategoryRollupHelper
    {
        /// <summary>
        /// For each active ItemCategory, returns the list of descendant CategoryIds
        /// including the category itself. Inactive categories are excluded from
        /// both the keys and the descendant lists.
        /// </summary>
        Dictionary<int, List<int>> GetDescendantMap();
    }
}
