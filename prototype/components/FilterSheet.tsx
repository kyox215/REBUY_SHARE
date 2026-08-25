import { Check, SlidersHorizontal } from "lucide-react";
import { tr, type Locale } from "@/lib/data";

export type CatalogFilter = "all" | "new" | "used" | "inStock";
export type SortOrder = "featured" | "priceLow" | "priceHigh";

type FilterSheetProps = {
  locale: Locale;
  open: boolean;
  filter: CatalogFilter;
  sort: SortOrder;
  onToggle: () => void;
  onFilterChange: (filter: CatalogFilter) => void;
  onSortChange: (sort: SortOrder) => void;
  onClear: () => void;
};

const filterOptions: Array<{ value: CatalogFilter; label: string }> = [
  { value: "all", label: "filter.all" },
  { value: "new", label: "filter.new" },
  { value: "used", label: "filter.used" },
  { value: "inStock", label: "filter.inStock" },
];

export default function FilterSheet({
  locale,
  open,
  filter,
  sort,
  onToggle,
  onFilterChange,
  onSortChange,
  onClear,
}: FilterSheetProps) {
  return (
    <div className="filter-area">
      <div className="filter-toolbar">
        <button type="button" className={`button button--secondary ${open ? "is-active" : ""}`} onClick={onToggle} aria-expanded={open}>
          <SlidersHorizontal size={17} aria-hidden="true" />
          {tr(locale, "catalog.filter")}
        </button>
        <label className="sort-control">
          <span className="sr-only">{tr(locale, "catalog.sort")}</span>
          <select value={sort} onChange={(event) => onSortChange(event.target.value as SortOrder)}>
            <option value="featured">{tr(locale, "catalog.sort")}</option>
            <option value="priceLow">{tr(locale, "catalog.sortLow")}</option>
            <option value="priceHigh">{tr(locale, "catalog.sortHigh")}</option>
          </select>
        </label>
      </div>
      {open ? (
        <section className="filter-sheet" aria-label={tr(locale, "catalog.filterTitle")}>
          <div className="filter-sheet__header">
            <div>
              <span className="eyebrow">{tr(locale, "catalog.filterApplied")}</span>
              <h2>{tr(locale, "catalog.filterTitle")}</h2>
            </div>
            <button type="button" className="text-button" onClick={onClear}>
              {tr(locale, "catalog.clear")}
            </button>
          </div>
          <div className="filter-options" role="group" aria-label={tr(locale, "catalog.filterTitle")}>
            {filterOptions.map((option) => (
              <button
                type="button"
                className={`filter-option ${filter === option.value ? "is-selected" : ""}`}
                key={option.value}
                onClick={() => onFilterChange(option.value)}
                aria-pressed={filter === option.value}
              >
                {filter === option.value ? <Check size={16} aria-hidden="true" /> : <span className="filter-option__empty" aria-hidden="true" />}
                {tr(locale, option.label)}
              </button>
            ))}
          </div>
          <button type="button" className="button button--primary filter-sheet__apply" onClick={onToggle}>
            {tr(locale, "buttons.apply")}
          </button>
        </section>
      ) : null}
    </div>
  );
}
