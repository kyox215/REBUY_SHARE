"use client";

import { ArrowLeft, ClipboardList, Grid2X2, Home, Search, ShoppingCart, UserRound } from "lucide-react";
import type { ReactNode, FormEvent } from "react";
import { tr, type Locale, type PrimaryView } from "@/lib/data";

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
};

const navItems: Array<{ view: PrimaryView; icon: typeof Home; label: string }> = [
  { view: "home", icon: Home, label: "nav.home" },
  { view: "catalog", icon: Grid2X2, label: "nav.catalog" },
  { view: "orders", icon: ClipboardList, label: "nav.orders" },
  { view: "cart", icon: ShoppingCart, label: "nav.cart" },
  { view: "profile", icon: UserRound, label: "nav.profile" },
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
}: AppShellProps) {
  const handleSearch = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    onSearchSubmit(searchValue);
  };

  return (
    <div className="app-shell" lang={locale === "zh" ? "zh-CN" : locale === "it" ? "it" : "en"}>
      <header className="topbar">
        <div className="topbar__inner page-width">
          {showBack ? (
            <button
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
              <span className="brand__mark" aria-hidden="true">R</span>
              <span>Rebuy</span>
              <small>prototype</small>
            </button>
          )}
          {!showBack ? (
            <form className="global-search" onSubmit={handleSearch} role="search">
              <Search size={18} aria-hidden="true" />
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
          <button type="button" className="icon-button topbar__cart" onClick={onCart} aria-label={tr(locale, "nav.cart")} title={tr(locale, "nav.cart")}>
            <ShoppingCart size={21} aria-hidden="true" />
            {cartCount > 0 ? <span className="cart-badge">{cartCount > 99 ? "99+" : cartCount}</span> : null}
          </button>
        </div>
      </header>

      <main
        className={`app-content page-width${showBottomNav ? "" : " app-content--secondary"}`}
      >
        {children}
      </main>

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
