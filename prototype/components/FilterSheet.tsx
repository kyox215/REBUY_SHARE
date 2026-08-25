import { Check, SlidersHorizontal } from "lucide-react";
import { useEffect, useMemo, useRef } from "react";
import { tr, type Locale } from "@/lib/data";
import SelectMenu, { type SelectMenuOption } from "@/components/SelectMenu";

export type CatalogFilter = "all" | "new" | "used" | "inStock";
export type SortOrder = "featured" | "priceLow" | "priceHigh";

type FilterSheetProps = {
  locale: Locale;
  open: boolean;
  filter: CatalogFilter;
  sort: SortOrder;
  onOpenChange: (open: boolean) => void;
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

const filterSheetId = "rebuy-filter-sheet";
const filterSheetTitleId = "rebuy-filter-sheet-title";

export default function FilterSheet({
  locale,
  open,
  filter,
  sort,
  onOpenChange,
  onFilterChange,
  onSortChange,
  onClear,
}: FilterSheetProps) {
  const triggerRef = useRef<HTMLButtonElement>(null);
  const firstControlRef = useRef<HTMLButtonElement>(null);
  const sortOptions = useMemo<Array<SelectMenuOption<SortOrder>>>(() => [
    { value: "featured", label: tr(locale, "catalog.sort") },
    { value: "priceLow", label: tr(locale, "catalog.sortLow") },
    { value: "priceHigh", label: tr(locale, "catalog.sortHigh") },
  ], [locale]);

  useEffect(() => {
    if (open) {
      firstControlRef.current?.focus();
    }
  }, [open]);

  const closeSheet = () => {
    onOpenChange(false);
    triggerRef.current?.focus();
  };

  const handleTriggerClick = () => {
    if (open) {
      closeSheet();
      return;
    }

    onOpenChange(true);
  };

  return (
    <div className="filter-area">
      <div className="filter-toolbar">
        <button
          ref={triggerRef}
          type="button"
          className={`button button--secondary ${open ? "is-active" : ""}`}
          onClick={handleTriggerClick}
          aria-controls={filterSheetId}
          aria-expanded={open}
          aria-haspopup="dialog"
        >
          <SlidersHorizontal size={17} aria-hidden="true" />
          {tr(locale, "catalog.filter")}
        </button>
        <SelectMenu<SortOrder>
          value={sort}
          options={sortOptions}
          onChange={onSortChange}
          ariaLabel={tr(locale, "catalog.sort")}
          className="sort-control"
          align="end"
        />
      </div>
      {open ? (
        <section
          id={filterSheetId}
          className="filter-sheet"
          role="dialog"
          aria-labelledby={filterSheetTitleId}
          onKeyDown={(event) => {
            if (event.key === "Escape") {
              event.preventDefault();
              closeSheet();
            }
          }}
        >
          <div className="filter-sheet__header">
            <div>
              <span className="eyebrow">{tr(locale, "catalog.filterApplied")}</span>
              <h2 id={filterSheetTitleId}>{tr(locale, "catalog.filterTitle")}</h2>
            </div>
            <button ref={firstControlRef} type="button" className="text-button" onClick={onClear}>
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
          <button type="button" className="button button--primary filter-sheet__apply" onClick={closeSheet}>
            {tr(locale, "buttons.apply")}
          </button>
        </section>
      ) : null}
    </div>
  );
}
