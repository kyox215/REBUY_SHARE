"use client";

import { ArrowLeft, Cable, ClipboardList, Grid2X2, Home, Laptop, Moon, Recycle, Search, ShoppingCart, Smartphone, Sun, UserRound } from "lucide-react";
import { useEffect, useRef, type FormEvent, type ReactNode } from "react";
import { localeToHtmlLang, tr, type Locale, type PrimaryView } from "@/lib/data";
import BrandMark from "@/components/BrandMark";
import SelectMenu, { type SelectMenuOption } from "@/components/SelectMenu";

type SidebarCategory = "electronics" | "accessories" | "used" | "computers";

type AppShellProps = {
  children: ReactNode;
  locale: Locale;
  activeView: PrimaryView;
  topTitle: string;
  showBack: boolean;
  showBottomNav: boolean;
  cartCount: number;
  searchValue: string;
  searchPlaceholder: string;
  onBack: () => void;
  onNavigate: (view: PrimaryView) => void;
  onCart: () => void;
  onSearchChange: (value: string) => void;
  onSearchSubmit: (value: string) => void;
  onCategorySelect?: (category: SidebarCategory) => void;
  onLocaleChange?: (locale: Locale) => void;
  theme?: "dark" | "light";
  onThemeToggle?: () => void;
};

const navItems: Array<{ view: PrimaryView; icon: typeof Home; label: string }> = [
  { view: "home", icon: Home, label: "nav.home" },
  { view: "catalog", icon: Grid2X2, label: "nav.catalog" },
  { view: "orders", icon: ClipboardList, label: "nav.orders" },
  { view: "cart", icon: ShoppingCart, label: "nav.cart" },
  { view: "profile", icon: UserRound, label: "nav.profile" },
];

const sidebarCategories: Array<{ value: SidebarCategory; icon: typeof Home; label: string }> = [
  { value: "electronics", icon: Smartphone, label: "category.electronics" },
  { value: "accessories", icon: Cable, label: "category.accessories" },
  { value: "used", icon: Recycle, label: "category.used" },
  { value: "computers", icon: Laptop, label: "category.computers" },
];

const languageOptions: Array<SelectMenuOption<Locale>> = [
  { value: "zh", label: "中文", triggerLabel: "中文" },
  { value: "it", label: "Italiano", triggerLabel: "IT" },
  { value: "en", label: "English", triggerLabel: "EN" },
];

export default function AppShell({
  children,
  locale,
  activeView,
  topTitle,
  showBack,
  showBottomNav,
  cartCount,
  searchValue,
  searchPlaceholder,
  onBack,
  onNavigate,
  onCart,
  onSearchChange,
  onSearchSubmit,
  onCategorySelect,
  onLocaleChange,
  theme = "light",
  onThemeToggle,
}: AppShellProps) {
  const backButtonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (showBack) {
      backButtonRef.current?.focus();
    }
  }, [showBack]);

  const handleSearch = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    onSearchSubmit(searchValue);
  };

  return (
    <div className="app-shell" lang={localeToHtmlLang(locale)}>
      <header className="topbar">
        <div className="topbar__inner page-width">
          {showBack ? (
            <button
              ref={backButtonRef}
              type="button"
              className="topbar__back"
              onClick={onBack}
              aria-label={tr(locale, "buttons.back")}
              title={tr(locale, "buttons.back")}
            >
              <ArrowLeft size={20} aria-hidden="true" />
            </button>
          ) : (
            <button type="button" className="brand" onClick={() => onNavigate("home")}>
              <BrandMark />
            </button>
          )}
          {!showBack ? (
            <form className="global-search" onSubmit={handleSearch} role="search">
              <button
                type="submit"
                className="global-search__submit"
                aria-label={tr(locale, "search.submit")}
                title={tr(locale, "search.submit")}
              >
                <Search size={18} aria-hidden="true" />
              </button>
              <input
                type="search"
                value={searchValue}
                onChange={(event) => onSearchChange(event.target.value)}
                placeholder={searchPlaceholder}
                aria-label={searchPlaceholder}
              />
              {searchValue ? (
                <button type="button" className="global-search__clear" onClick={() => onSearchChange("")} aria-label={tr(locale, "buttons.clear")} title={tr(locale, "buttons.clear")}>
                  ×
                </button>
              ) : null}
            </form>
          ) : (
            <div className="topbar__title">{topTitle}</div>
          )}
          <div className="topbar__tools">
            {onLocaleChange ? (
              <SelectMenu<Locale>
                value={locale}
                options={languageOptions}
                onChange={onLocaleChange}
                ariaLabel={tr(locale, "profile.language")}
                className="topbar__locale"
                align="end"
                compact
              />
            ) : null}
            {onThemeToggle ? (
              <button
                type="button"
                className="icon-button topbar__theme"
                onClick={onThemeToggle}
                aria-label={tr(locale, theme === "dark" ? "profile.light" : "profile.dark")}
                title={tr(locale, theme === "dark" ? "profile.light" : "profile.dark")}
              >
                {theme === "dark" ? <Sun size={19} aria-hidden="true" /> : <Moon size={19} aria-hidden="true" />}
              </button>
            ) : null}
            <button type="button" className="icon-button topbar__cart" onClick={onCart} aria-label={tr(locale, "nav.cart")} title={tr(locale, "nav.cart")}>
              <ShoppingCart size={21} aria-hidden="true" />
              {cartCount > 0 ? <span className="cart-badge">{cartCount > 99 ? "99+" : cartCount}</span> : null}
            </button>
          </div>
        </div>
      </header>

      {showBottomNav ? (
        <div className="buyer-layout page-width">
          <aside className="buyer-sidebar" aria-label={tr(locale, "nav.catalog")}>
            <div className="buyer-sidebar__heading">
              <BrandMark compact />
              <span>{tr(locale, "nav.catalog")}</span>
            </div>
            <nav className="buyer-sidebar__nav" aria-label={tr(locale, "nav.home")}>
              {navItems.map(({ view, icon: Icon, label }) => (
                <button
                  type="button"
                  className={`buyer-sidebar__item ${activeView === view ? "is-active" : ""}`}
                  key={view}
                  onClick={() => onNavigate(view)}
                  aria-current={activeView === view ? "page" : undefined}
                >
                  <Icon size={17} aria-hidden="true" />
                  <span>{tr(locale, label)}</span>
                  {view === "cart" && cartCount > 0 ? <em>{cartCount > 99 ? "99+" : cartCount}</em> : null}
                </button>
              ))}
            </nav>
            <div className="buyer-sidebar__section">
              <span className="buyer-sidebar__label">{tr(locale, "home.categories")}</span>
              {sidebarCategories.map(({ value, icon: Icon, label }) => (
                <button
                  type="button"
                  className="buyer-sidebar__item buyer-sidebar__item--category"
                  key={value}
                  onClick={() => onCategorySelect ? onCategorySelect(value) : onNavigate("catalog")}
                >
                  <Icon size={16} aria-hidden="true" />
                  <span>{tr(locale, label)}</span>
                </button>
              ))}
            </div>
          </aside>
          <main className="app-content">
            {children}
          </main>
        </div>
      ) : (
        <main className="app-content page-width app-content--secondary">
          {children}
        </main>
      )}

      {showBottomNav ? (
        <nav className="bottom-nav" aria-label={tr(locale, "nav.home")}>
          <div className="bottom-nav__inner page-width">
            {navItems.map(({ view, icon: Icon, label }) => (
              <button
                type="button"
                className={`bottom-nav__item ${activeView === view ? "is-active" : ""}`}
                key={view}
                onClick={() => onNavigate(view)}
                aria-current={activeView === view ? "page" : undefined}
              >
                <Icon size={21} strokeWidth={activeView === view ? 2.3 : 1.8} aria-hidden="true" />
                <span>{tr(locale, label)}</span>
                {view === "cart" && cartCount > 0 ? <em>{cartCount > 99 ? "99+" : cartCount}</em> : null}
              </button>
            ))}
          </div>
        </nav>
      ) : null}
    </div>
  );
}
