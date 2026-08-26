"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  BadgeCheck,
  Boxes,
  Cable,
  ChevronRight,
  CircleUserRound,
  Clock3,
  Languages,
  Laptop,
  Moon,
  PackageCheck,
  ReceiptText,
  Recycle,
  ShieldCheck,
  Smartphone,
  Store,
  Sun,
  Truck,
  WalletCards,
} from "lucide-react";
import AppShell from "@/components/AppShell";
import FilterSheet, { type CatalogFilter, type SortOrder } from "@/components/FilterSheet";
import PriceBlock from "@/components/PriceBlock";
import ProductCard from "@/components/ProductCard";
import QuantityStepper from "@/components/QuantityStepper";
import SellerGroup from "@/components/SellerGroup";
import SpriteImage from "@/components/SpriteImage";
import StatusBanner from "@/components/StatusBanner";
import UsedFacts from "@/components/UsedFacts";
import {
  buildDemoOrders,
  findProduct,
  formatCurrency,
  makeLocalOrder,
  minimumQuantity,
  localeToHtmlLang,
  priceForProduct,
  products,
  statusLabel,
  stockState,
  tr,
  type AppView,
  type CartItem,
  type Locale,
  type MerchantOrder,
  type OrderBatch,
  type OrderStatus,
  type PrimaryView,
  type Product,
  type Role,
  type StockState,
} from "@/lib/data";

type CategoryFilter = "all" | "electronics" | "accessories" | "used" | "computers";
type CatalogMode = "directory" | "results";
type Theme = "dark" | "light";

const primaryViews: PrimaryView[] = ["home", "catalog", "orders", "cart", "profile"];

const primaryTitleKeys: Record<PrimaryView, string> = {
  home: "nav.home",
  catalog: "catalog.title",
  orders: "orders.title",
  cart: "cart.title",
  profile: "profile.title",
};

const categoryItems: Array<{ value: Exclude<CategoryFilter, "all">; label: string; icon: typeof Smartphone }> = [
  { value: "electronics", label: "category.electronics", icon: Smartphone },
  { value: "accessories", label: "category.accessories", icon: Cable },
  { value: "used", label: "category.used", icon: Recycle },
  { value: "computers", label: "category.computers", icon: Laptop },
];

const homeFeaturedProducts = (["charger", "headphones", "phone"] as const)
  .map((productId) => products.find((product) => product.id === productId))
  .filter((product): product is Product => Boolean(product));

const roleItems: Array<{ value: Role; label: string; status: string; icon: typeof CircleUserRound }> = [
  { value: "guest", label: "profile.guest", status: "profile.guestStatus", icon: CircleUserRound },
  { value: "retail", label: "profile.retail", status: "profile.retailStatus", icon: Store },
  { value: "wholesale", label: "profile.wholesale", status: "profile.wholesaleStatus", icon: BadgeCheck },
];

const statusSteps: Array<{ status: OrderStatus; icon: typeof ReceiptText }> = [
  { status: "submitted", icon: ReceiptText },
  { status: "processing", icon: Boxes },
  { status: "shipping", icon: Truck },
  { status: "completed", icon: ShieldCheck },
];

function isPrimaryView(value: AppView): value is PrimaryView {
  return (primaryViews as AppView[]).includes(value);
}

function productMatchesCategory(product: Product, category: CategoryFilter): boolean {
  if (category === "all") return true;
  if (category === "used") return product.kind === "used";
  if (category === "accessories") return product.id === "charger" || product.id === "headphones";
  if (category === "computers") return product.id === "laptop";
  return product.id === "phone" || product.id === "headphones" || product.id === "laptop";
}

function stockCopyKey(state: StockState): string {
  if (state === "out-of-stock") return "product.outOfStock";
  if (state === "low-stock") return "product.lowStock";
  return "product.inStock";
}

function itemCount(items: Array<{ quantity: number }>): number {
  return items.reduce((sum, item) => sum + item.quantity, 0);
}

function orderTotal(order: OrderBatch): number {
  return order.merchantOrders.reduce((sum, merchantOrder) => sum + merchantOrder.subtotal, 0);
}

export default function PrototypeApp() {
  const [locale, setLocale] = useState<Locale>("zh");
  const [role, setRole] = useState<Role>("retail");
  const [theme, setTheme] = useState<Theme>("light");
  const [reducedMotion, setReducedMotion] = useState(false);
  const [systemReducedMotion, setSystemReducedMotion] = useState(false);
  const reducedMotionRef = useRef(reducedMotion);
  const [view, setView] = useState<AppView>("home");
  const [detailOrigin, setDetailOrigin] = useState<PrimaryView>("home");
  const [selectedProductId, setSelectedProductId] = useState<string | null>(null);
  const [selectedOrderId, setSelectedOrderId] = useState<string | null>(null);
  const [selectedMerchantOrderId, setSelectedMerchantOrderId] = useState<string | null>(null);
  const [detailQuantity, setDetailQuantity] = useState(1);
  const [catalogMode, setCatalogMode] = useState<CatalogMode>("directory");
  const [searchDraft, setSearchDraft] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<CategoryFilter>("all");
  const [catalogFilter, setCatalogFilter] = useState<CatalogFilter>("all");
  const [sortOrder, setSortOrder] = useState<SortOrder>("featured");
  const [filterOpen, setFilterOpen] = useState(false);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [orders, setOrders] = useState<OrderBatch[]>(() => buildDemoOrders("retail"));
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const detailProduct = selectedProductId ? findProduct(selectedProductId) : undefined;

  const cartGroups = useMemo(() => {
    const grouped = new Map<string, Array<{ item: CartItem; product: Product }>>();
    cart.forEach((item) => {
      const product = findProduct(item.productId);
      if (!product) return;
      const current = grouped.get(product.merchant) ?? [];
      current.push({ item, product });
      grouped.set(product.merchant, current);
    });
    return Array.from(grouped.entries()).map(([merchant, items]) => ({ merchant, items }));
  }, [cart]);

  const cartItemCount = useMemo(() => itemCount(cart), [cart]);

  const cartTotal = useMemo(
    () =>
      cart.reduce((sum, item) => {
        const product = findProduct(item.productId);
        return product ? sum + priceForProduct(product, role, item.quantity) * item.quantity : sum;
      }, 0),
    [cart, role],
  );

  const filteredProducts = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    const matching = products.filter((product) => {
      const searchable = [
        product.merchant,
        ...Object.values(product.name),
        ...Object.values(product.summary),
      ]
        .join(" ")
        .toLowerCase();
      const matchesQuery = !query || searchable.includes(query);
      const matchesCategory = productMatchesCategory(product, categoryFilter);
      const matchesFilter =
        catalogFilter === "all" ||
        (catalogFilter === "new" && product.kind === "new") ||
        (catalogFilter === "used" && product.kind === "used") ||
        (catalogFilter === "inStock" && product.inventory > 0);
      return matchesQuery && matchesCategory && matchesFilter;
    });

    if (sortOrder === "featured") return matching;
    return [...matching].sort((first, second) => {
      const firstQuantity = cart.find((item) => item.productId === first.id)?.quantity ?? minimumQuantity(first, role);
      const secondQuantity = cart.find((item) => item.productId === second.id)?.quantity ?? minimumQuantity(second, role);
      const firstPrice = priceForProduct(first, role, firstQuantity);
      const secondPrice = priceForProduct(second, role, secondQuantity);
      return sortOrder === "priceLow" ? firstPrice - secondPrice : secondPrice - firstPrice;
    });
  }, [cart, catalogFilter, categoryFilter, role, searchQuery, sortOrder]);

  const selectedOrder = orders.find((order) => order.id === selectedOrderId) ?? orders[0];
  const selectedMerchantOrder: MerchantOrder | undefined = selectedOrder
    ? selectedOrder.merchantOrders.find((merchantOrder) => merchantOrder.id === selectedMerchantOrderId) ??
      selectedOrder.merchantOrders[0]
    : undefined;

  useEffect(() => {
    const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const syncSystemPreference = () => setSystemReducedMotion(mediaQuery.matches);
    syncSystemPreference();
    mediaQuery.addEventListener("change", syncSystemPreference);
    return () => mediaQuery.removeEventListener("change", syncSystemPreference);
  }, []);

  useEffect(() => {
    document.documentElement.lang = localeToHtmlLang(locale);
  }, [locale]);

  useEffect(() => {
    reducedMotionRef.current = reducedMotion || systemReducedMotion;
  }, [reducedMotion, systemReducedMotion]);

  useEffect(() => {
    if (!toast) return;
    const timeoutId = window.setTimeout(() => setToast(null), 3200);
    return () => window.clearTimeout(timeoutId);
  }, [toast]);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: reducedMotionRef.current ? "auto" : "smooth" });
  }, [view]);

  const showToast = (messageKey: string) => {
    setToast(tr(locale, messageKey));
  };

  const handleSearchChange = (value: string) => {
    setSearchDraft(value);
    if (!value) setSearchQuery("");
  };

  const handleSearchSubmit = (value: string) => {
    setSearchDraft(value);
    setSearchQuery(value.trim());
    setCategoryFilter("all");
    setCatalogMode("results");
    setView("catalog");
  };

  const selectCategory = (category: Exclude<CategoryFilter, "all">) => {
    setCategoryFilter(category);
    setSearchDraft("");
    setSearchQuery("");
    setCatalogFilter("all");
    setSortOrder("featured");
    setFilterOpen(false);
    setCatalogMode("results");
    setView("catalog");
  };

  const openCategoryDirectory = () => {
    setCatalogMode("directory");
    setCategoryFilter("all");
    setSearchDraft("");
    setSearchQuery("");
    setCatalogFilter("all");
    setSortOrder("featured");
    setFilterOpen(false);
    setView("catalog");
  };

  const clearAllConditions = () => {
    setSearchDraft("");
    setSearchQuery("");
    setCategoryFilter("all");
    setCatalogFilter("all");
    setSortOrder("featured");
  };

  const openProduct = (productId: string) => {
    const product = findProduct(productId);
    if (!product) return;
    const origin = isPrimaryView(view) ? view : detailOrigin;
    const existing = cart.find((item) => item.productId === productId);
    setDetailOrigin(origin);
    setSelectedProductId(productId);
    setDetailQuantity(existing?.quantity ?? minimumQuantity(product, role));
    setView("detail");
  };

  const handleBack = () => {
    if (view === "detail") {
      setView(detailOrigin);
      return;
    }
    if (view === "checkout") {
      setView("cart");
      return;
    }
    if (view === "order-detail") {
      setView("orders");
      return;
    }
    setView("home");
  };

  const handleNavigate = (nextView: PrimaryView) => {
    if (nextView === "catalog") {
      openCategoryDirectory();
      return;
    }
    setView(nextView);
  };

  const changeRole = (nextRole: Role) => {
    setRole(nextRole);
    if (detailProduct) {
      setDetailQuantity(Math.max(1, minimumQuantity(detailProduct, nextRole)));
    }
  };

  const addToCart = (productId: string, requestedQuantity = 1, exactQuantity = false) => {
    const product = findProduct(productId);
    if (!product) return;
    const minimum = minimumQuantity(product, role);
    if (product.inventory <= 0) {
      showToast("product.outOfStock");
      return;
    }
    if (product.inventory < minimum) {
      setToast(
        tr(locale, "price.minimum") +
          " " +
          minimum +
          " " +
          product.unit[locale] +
          " · " +
          tr(locale, "product.lowStock"),
      );
      return;
    }

    setCart((current) => {
      const existing = current.find((item) => item.productId === productId);
      const nextQuantity =
        product.kind === "used"
          ? 1
          : exactQuantity
            ? Math.min(product.inventory, Math.max(minimum, requestedQuantity))
            : existing
              ? Math.min(product.inventory, existing.quantity + 1)
              : Math.min(product.inventory, Math.max(minimum, requestedQuantity));

      if (!existing) return [...current, { productId, quantity: nextQuantity }];
      return current.map((item) => (item.productId === productId ? { ...item, quantity: nextQuantity } : item));
    });
    showToast("toast.added");
  };

  const changeCartQuantity = (productId: string, quantity: number) => {
    const product = findProduct(productId);
    if (!product || product.kind === "used") return;
    const minimum = minimumQuantity(product, role);
    if (product.inventory < minimum) return;
    const nextQuantity = Math.min(product.inventory, Math.max(minimum, quantity));
    setCart((current) => current.map((item) => (item.productId === productId ? { ...item, quantity: nextQuantity } : item)));
  };

  const removeFromCart = (productId: string) => {
    setCart((current) => current.filter((item) => item.productId !== productId));
    showToast("toast.removed");
  };

  const goToCheckout = () => {
    if (cart.length > 0) setView("checkout");
  };

  const submitOrder = () => {
    if (role === "guest" || isSubmitting || cart.length === 0) return;
    setIsSubmitting(true);
    const order = makeLocalOrder(cart, role);
    window.setTimeout(() => {
      setOrders((current) => [order, ...current]);
      setCart([]);
      setSelectedOrderId(order.id);
      setSelectedMerchantOrderId(order.merchantOrders[0]?.id ?? null);
      setIsSubmitting(false);
      setView("orders");
      showToast("toast.orderCreated");
    }, reducedMotion || systemReducedMotion ? 80 : 280);
  };

  const openOrder = (orderId: string, merchantOrderId?: string) => {
    const order = orders.find((candidate) => candidate.id === orderId);
    if (!order) return;
    setSelectedOrderId(orderId);
    setSelectedMerchantOrderId(merchantOrderId ?? order.merchantOrders[0]?.id ?? null);
    setView("order-detail");
  };

  const renderEmpty = (title: string, note: string, actionLabel: string, onAction: () => void) => (
    <section className="empty-state">
      <div className="empty-state__icon">
        <WalletCards size={24} aria-hidden="true" />
      </div>
      <h1>{title}</h1>
      <p>{note}</p>
      <button type="button" className="button button--primary" onClick={onAction}>
        {actionLabel}
      </button>
    </section>
  );

  const renderHome = () => (
    <>
      <section className="home-intro">
        <h1>{tr(locale, "home.greeting")}</h1>
        <p>{tr(locale, "home.subtitle")}</p>
      </section>

      <section className="section-block" aria-labelledby="home-recommended-title">
        <div className="section-heading">
          <div>
            <h2 id="home-recommended-title">{tr(locale, "home.recommended")}</h2>
          </div>
        </div>
        <div className="product-grid">
          {homeFeaturedProducts.map((product) => (
            <ProductCard
              key={product.id}
              product={product}
              role={role}
              locale={locale}
              cartQuantity={cart.find((item) => item.productId === product.id)?.quantity ?? 0}
              onOpen={() => openProduct(product.id)}
              onAdd={() => addToCart(product.id)}
            />
          ))}
        </div>
      </section>

      <section className="section-block" aria-labelledby="home-categories-title">
        <div className="section-heading">
          <div>
            <h2 id="home-categories-title">{tr(locale, "home.categories")}</h2>
          </div>
        </div>
        <div className="category-grid">
          {categoryItems.map(({ value, label, icon: Icon }) => (
            <button type="button" className="category-tile" key={value} onClick={() => selectCategory(value)}>
              <span className="category-tile__icon">
                <Icon size={22} aria-hidden="true" />
              </span>
              <span>{tr(locale, label)}</span>
              <ChevronRight size={17} aria-hidden="true" />
            </button>
          ))}
        </div>
      </section>

      <StatusBanner>{tr(locale, "notice.demo")}</StatusBanner>
    </>
  );

  const renderCatalog = () => {
    if (catalogMode === "directory") {
      return (
        <section className="page-section catalog-directory" aria-labelledby="catalog-directory-title">
          <div className="page-heading">
            <div>
              <h1 id="catalog-directory-title">{tr(locale, "catalog.directoryTitle")}</h1>
              <p className="page-heading__note">{tr(locale, "catalog.directoryNote")}</p>
            </div>
          </div>
          <div className="category-grid catalog-directory__grid">
            {categoryItems.map(({ value, label, icon: Icon }) => (
              <button type="button" className="category-tile" key={value} onClick={() => selectCategory(value)}>
                <span className="category-tile__icon">
                  <Icon size={22} aria-hidden="true" />
                </span>
                <span>{tr(locale, label)}</span>
                <ChevronRight size={17} aria-hidden="true" />
              </button>
            ))}
          </div>
        </section>
      );
    }

    const activeCategoryLabel =
      categoryFilter !== "all"
        ? tr(locale, categoryItems.find((item) => item.value === categoryFilter)?.label ?? "category.electronics")
        : null;

    return (
      <section className="page-section catalog-results">
        <div className="page-heading">
          <div>
            <h1>{activeCategoryLabel ?? tr(locale, "catalog.title")}</h1>
            {searchQuery ? <p className="page-heading__note">“{searchQuery}”</p> : null}
          </div>
          <span className="page-heading__count">
            {filteredProducts.length} {tr(locale, "catalog.results")}
          </span>
        </div>

        <button type="button" className="catalog-back-button" onClick={openCategoryDirectory}>
          <ChevronRight size={17} aria-hidden="true" />
          {tr(locale, "catalog.backToCategories")}
        </button>

        <div className="catalog-context">
          {activeCategoryLabel ? <span className="context-label">{activeCategoryLabel}</span> : null}
        </div>

        <FilterSheet
          locale={locale}
          open={filterOpen}
          filter={catalogFilter}
          sort={sortOrder}
          onOpenChange={setFilterOpen}
          onFilterChange={setCatalogFilter}
          onSortChange={setSortOrder}
          onClear={clearAllConditions}
        />

        {filteredProducts.length === 0 ? (
          <section className="empty-state empty-state--catalog">
            <div className="empty-state__icon">
              <Smartphone size={24} aria-hidden="true" />
            </div>
            <h2>{tr(locale, "catalog.noResults")}</h2>
            <p>{tr(locale, "catalog.noResultsNote")}</p>
            <button type="button" className="button button--secondary" onClick={clearAllConditions}>
              {tr(locale, "catalog.clear")}
            </button>
          </section>
        ) : (
          <div className="product-grid">
            {filteredProducts.map((product) => (
              <ProductCard
                key={product.id}
                product={product}
                role={role}
                locale={locale}
                cartQuantity={cart.find((item) => item.productId === product.id)?.quantity ?? 0}
                onOpen={() => openProduct(product.id)}
                onAdd={() => addToCart(product.id)}
              />
            ))}
          </div>
        )}
      </section>
    );
  };

  const renderDetail = () => {
    if (!detailProduct) {
      return renderEmpty(
        tr(locale, "catalog.noResults"),
        tr(locale, "catalog.noResultsNote"),
        tr(locale, "buttons.back"),
        handleBack,
      );
    }

    const state = stockState(detailProduct);
    const minimum = minimumQuantity(detailProduct, role);
    const canBuy = detailProduct.inventory > 0 && detailProduct.inventory >= minimum;
    const displayQuantity = canBuy
      ? Math.min(detailProduct.inventory, Math.max(minimum, detailQuantity))
      : 1;

    return (
      <section className={`detail-page ${detailProduct.kind === "used" ? "detail-page--used" : ""}`}>
        <div className="detail-layout">
          <div className="detail-media">
            <SpriteImage variant={detailProduct.sprite} alt={detailProduct.name[locale]} priority />
            <div className="detail-media__meta">
              <span className="tag">{tr(locale, detailProduct.kind === "used" ? "product.used" : "product.new")}</span>
              <span className="muted">{detailProduct.merchant}</span>
            </div>
          </div>
          <div className="detail-copy">
            <span className="eyebrow">{tr(locale, "details.title")}</span>
            <h1>{detailProduct.name[locale]}</h1>
            <p className="detail-copy__summary">{detailProduct.summary[locale]}</p>
            <PriceBlock product={detailProduct} role={role} locale={locale} quantity={displayQuantity} />
            <div className={"stock-line stock-line--" + state}>
              <span className="stock-dot" aria-hidden="true" />
              <span>{tr(locale, stockCopyKey(state))}</span>
              {detailProduct.inventory > 0 ? (
                <span className="muted">
                  · {detailProduct.kind === "used" ? tr(locale, "cart.singleItem") : `${detailProduct.inventory} ${detailProduct.unit[locale]}`}
                </span>
              ) : null}
            </div>
            {!canBuy && detailProduct.inventory > 0 ? (
              <StatusBanner tone="warning">
                {tr(locale, "price.minimum")} {minimum} {detailProduct.unit[locale]} · {tr(locale, "product.lowStock")}
              </StatusBanner>
            ) : null}
            {detailProduct.kind === "used" ? <UsedFacts product={detailProduct} locale={locale} /> : null}
            <div className="detail-buy">
              <div>
                <span className="eyebrow">{tr(locale, "details.quantity")}</span>
                {detailProduct.kind === "used" ? (
                  <span className="fixed-quantity">{tr(locale, "cart.singleItem")}</span>
                ) : canBuy ? (
                  <QuantityStepper
                    value={displayQuantity}
                    min={minimum}
                    max={detailProduct.inventory}
                    locale={locale}
                    onChange={setDetailQuantity}
                  />
                ) : (
                  <span className="fixed-quantity">{tr(locale, "product.outOfStock")}</span>
                )}
              </div>
              <div className="detail-buy__actions">
                <button
                  type="button"
                  className="button button--secondary"
                  disabled={!canBuy}
                  onClick={() => addToCart(detailProduct.id, displayQuantity, true)}
                >
                  {tr(locale, "buttons.add")}
                </button>
                <button
                  type="button"
                  className="button button--primary"
                  disabled={!canBuy}
                  onClick={() => {
                    addToCart(detailProduct.id, displayQuantity, true);
                    if (canBuy) setView("cart");
                  }}
                >
                  {tr(locale, "buttons.buy")}
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="detail-sections">
          <section className="info-section">
            <div className="section-heading">
              <div>
                <h2>{tr(locale, "details.specs")}</h2>
              </div>
            </div>
            <dl className="detail-fact-list">
              <div>
                <dt>{tr(locale, "details.seller")}</dt>
                <dd>{detailProduct.merchant}</dd>
              </div>
              <div>
                <dt>{tr(locale, "details.package")}</dt>
                <dd>{detailProduct.unit[locale]}</dd>
              </div>
              <div>
                <dt>{tr(locale, "details.inventory")}</dt>
                <dd>{detailProduct.inventory > 0 ? tr(locale, "status.available") : tr(locale, "product.outOfStock")}</dd>
              </div>
            </dl>
          </section>
          <section className="info-section">
            <div className="section-heading">
              <div>
                <h2>{tr(locale, "details.delivery")}</h2>
              </div>
            </div>
            <StatusBanner>{tr(locale, "checkout.shippingNote")}</StatusBanner>
            <p className="info-note">{tr(locale, "details.policy")}: {tr(locale, "checkout.paymentNote")}</p>
          </section>
        </div>
      </section>
    );
  };

  const renderCart = () => {
    if (cartGroups.length === 0) {
      return renderEmpty(
        tr(locale, "cart.empty"),
        tr(locale, "cart.emptyNote"),
        tr(locale, "cart.shopNow"),
        () => handleNavigate("catalog"),
      );
    }

    return (
      <section className="page-section">
        <div className="page-heading">
          <div>
            <h1>{tr(locale, "cart.title")}</h1>
          </div>
          <span className="page-heading__count">{cartItemCount}</span>
        </div>
        <div className="cart-layout">
          <div className="cart-groups">
            {cartGroups.map((group) => (
              <SellerGroup
                key={group.merchant}
                merchant={group.merchant}
                items={group.items}
                role={role}
                locale={locale}
                onChangeQuantity={changeCartQuantity}
                onRemove={removeFromCart}
                onOpen={openProduct}
              />
            ))}
          </div>
          <aside className="summary-panel">
            <span className="eyebrow">{tr(locale, "cart.total")}</span>
            <strong className="summary-panel__total">{formatCurrency(cartTotal, locale)}</strong>
            <div className="summary-panel__line">
              <span>{tr(locale, "cart.subtotal")}</span>
              <span>{formatCurrency(cartTotal, locale)}</span>
            </div>
            {role === "guest" ? <StatusBanner tone="warning">{tr(locale, "cart.loginRequired")}</StatusBanner> : null}
            <button type="button" className="button button--primary button--full" onClick={goToCheckout}>
              {tr(locale, "buttons.checkout")}
            </button>
          </aside>
        </div>
      </section>
    );
  };

  const renderCheckout = () => {
    if (cartGroups.length === 0) {
      return renderEmpty(
        tr(locale, "cart.empty"),
        tr(locale, "cart.emptyNote"),
        tr(locale, "cart.shopNow"),
        () => handleNavigate("catalog"),
      );
    }

    return (
      <section className="page-section">
        <div className="checkout-layout">
          <div className="checkout-main">
            <section className="info-section">
              <div className="section-heading">
                <div>
                  <h2>{tr(locale, "checkout.demoAddress")}</h2>
                </div>
              </div>
              <div className="demo-address">
                <div className="demo-address__icon">
                  <Truck size={20} aria-hidden="true" />
                </div>
                <div>
                  <strong>{tr(locale, "checkout.demoAddressPoint")}</strong>
                  <p>{tr(locale, "checkout.demoAddressNote")}</p>
                </div>
              </div>
            </section>

            <section className="info-section">
              <div className="section-heading">
                <div>
                  <h2>{tr(locale, "checkout.summary")}</h2>
                </div>
                <button type="button" className="text-button" onClick={() => setView("cart")}>
                  {tr(locale, "buttons.change")}
                </button>
              </div>
              <div className="checkout-shops">
                {cartGroups.map((group) => (
                  <section className="checkout-shop" key={group.merchant}>
                    <div className="checkout-shop__head">
                      <strong>{group.merchant}</strong>
                      <span>{itemCount(group.items.map(({ item }) => item))} {tr(locale, "orders.items")}</span>
                    </div>
                    {group.items.map(({ item, product }) => (
                      <div className="checkout-line" key={product.id}>
                        <SpriteImage variant={product.sprite} alt={product.name[locale]} />
                        <div>
                          <strong>{product.name[locale]}</strong>
                          <PriceBlock product={product} role={role} locale={locale} quantity={item.quantity} compact />
                        </div>
                        <span>{item.quantity} ×</span>
                        <strong>{formatCurrency(priceForProduct(product, role, item.quantity) * item.quantity, locale)}</strong>
                      </div>
                    ))}
                  </section>
                ))}
              </div>
            </section>

            <div className="checkout-notes">
              <StatusBanner>{tr(locale, "checkout.shippingNote")}</StatusBanner>
              <StatusBanner>{tr(locale, "checkout.paymentNote")}</StatusBanner>
            </div>
          </div>
          <aside className="summary-panel">
            <span className="eyebrow">{tr(locale, "cart.total")}</span>
            <strong className="summary-panel__total">{formatCurrency(cartTotal, locale)}</strong>
            {role === "guest" ? (
              <StatusBanner tone="warning">{tr(locale, "checkout.guestBlock")}</StatusBanner>
            ) : null}
            <button
              type="button"
              className="button button--primary button--full"
              onClick={submitOrder}
              disabled={role === "guest" || isSubmitting}
              aria-busy={isSubmitting}
            >
              {tr(locale, isSubmitting ? "buttons.submitting" : "buttons.submit")}
            </button>
          </aside>
        </div>
      </section>
    );
  };

  const renderOrders = () => (
    <section className="page-section">
      <div className="page-heading">
        <div>
          <h1>{tr(locale, "orders.title")}</h1>
        </div>
        <span className="page-heading__count">{orders.length}</span>
      </div>
      {orders.length === 0 ? (
        renderEmpty(
          tr(locale, "orders.empty"),
          tr(locale, "orders.emptyNote"),
          tr(locale, "cart.shopNow"),
          () => handleNavigate("catalog"),
        )
      ) : (
        <div className="order-list">
          {orders.map((order) => (
            <article className="order-batch" key={order.id}>
              <div className="order-batch__head">
                <div>
                  <span className="eyebrow">{tr(locale, "orders.batch")}</span>
                  <h2>{order.id}</h2>
                  <p>{order.createdAt[locale]}</p>
                </div>
                <div className="order-batch__total">
                  <span className={"status-chip status-chip--" + order.status}>{statusLabel(locale, order.status)}</span>
                  <strong>{formatCurrency(orderTotal(order), locale)}</strong>
                </div>
              </div>
              <div className="order-suborders">
                {order.merchantOrders.map((merchantOrder) => (
                  <button
                    type="button"
                    className="order-suborder"
                    key={merchantOrder.id}
                    onClick={() => openOrder(order.id, merchantOrder.id)}
                  >
                    <span className="order-suborder__icon">
                      <Store size={18} aria-hidden="true" />
                    </span>
                    <span className="order-suborder__copy">
                      <strong>{merchantOrder.merchant}</strong>
                      <small>
                        {itemCount(merchantOrder.items)} {tr(locale, "orders.items")} · {statusLabel(locale, merchantOrder.status)}
                      </small>
                    </span>
                    <strong>{formatCurrency(merchantOrder.subtotal, locale)}</strong>
                    <ChevronRight size={18} aria-hidden="true" />
                  </button>
                ))}
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );

  const renderOrderDetail = () => {
    if (!selectedOrder || !selectedMerchantOrder) {
      return renderEmpty(
        tr(locale, "orders.empty"),
        tr(locale, "orders.emptyNote"),
        tr(locale, "nav.orders"),
        () => handleNavigate("orders"),
      );
    }

    const currentStatusIndex = statusSteps.findIndex((step) => step.status === selectedMerchantOrder.status);
    return (
      <section className="page-section">
        <div className="detail-order-head">
          <div>
            <span className="eyebrow">{selectedOrder.id}</span>
            <h1>{selectedMerchantOrder.merchant}</h1>
            <p>{selectedMerchantOrder.delivery[locale]}</p>
          </div>
          <span className={"status-chip status-chip--" + selectedMerchantOrder.status}>
            {statusLabel(locale, selectedMerchantOrder.status)}
          </span>
        </div>

        <section className="info-section">
          <div className="section-heading">
            <div>
              <h2>{tr(locale, "orders.timeline")}</h2>
            </div>
          </div>
          <div className="order-timeline">
            {statusSteps.map((step, index) => {
              const StepIcon = step.icon;
              return (
                <div className={"timeline-step " + (index <= currentStatusIndex ? "is-complete" : "")} key={step.status}>
                  <span className="timeline-step__icon">
                    <StepIcon size={17} aria-hidden="true" />
                  </span>
                  <span>{statusLabel(locale, step.status)}</span>
                </div>
              );
            })}
          </div>
        </section>

        <section className="info-section">
          <div className="section-heading">
            <div>
              <h2>{tr(locale, "orders.suborder")}</h2>
            </div>
          </div>
          <div className="order-detail-items">
            {selectedMerchantOrder.items.map((item) => {
              const product = findProduct(item.productId);
              if (!product) return null;
              return (
                <div className="order-detail-line" key={item.productId}>
                  <SpriteImage variant={product.sprite} alt={product.name[locale]} />
                  <div>
                    <strong>{product.name[locale]}</strong>
                    <p>{item.quantity} × {formatCurrency(item.unitPrice, locale)}</p>
                  </div>
                  <strong>{formatCurrency(item.quantity * item.unitPrice, locale)}</strong>
                </div>
              );
            })}
          </div>
          <div className="order-detail-total">
            <span>{tr(locale, "cart.sellerSubtotal")}</span>
            <strong>{formatCurrency(selectedMerchantOrder.subtotal, locale)}</strong>
          </div>
        </section>
      </section>
    );
  };

  const renderProfile = () => (
    <section className="page-section profile-page">
      <div className="page-heading">
        <div>
          <h1>{tr(locale, "profile.title")}</h1>
        </div>
        <CircleUserRound size={28} aria-hidden="true" />
      </div>

      <StatusBanner>{tr(locale, "profile.demoOnly")}</StatusBanner>

      <section className="profile-section">
        <div className="section-heading">
          <div>
            <h2>{tr(locale, "profile.identity")}</h2>
          </div>
        </div>
        <p className="info-note">{tr(locale, "profile.demoNote")}</p>
        <div className="role-list">
          {roleItems.map(({ value, label, status, icon: Icon }) => (
            <button
              type="button"
              className={"role-option " + (role === value ? "is-selected" : "")}
              key={value}
              onClick={() => changeRole(value)}
              aria-pressed={role === value}
            >
              <span className="role-option__icon">
                <Icon size={20} aria-hidden="true" />
              </span>
              <span>
                <strong>{tr(locale, label)}</strong>
                <small>{tr(locale, status)}</small>
              </span>
              {role === value ? <BadgeCheck size={18} aria-hidden="true" /> : null}
            </button>
          ))}
        </div>
      </section>

      <section className="profile-section">
        <div className="section-heading">
          <div>
            <h2>{tr(locale, "profile.language")}</h2>
          </div>
          <Languages size={20} aria-hidden="true" />
        </div>
        <div className="segmented-control" aria-label={tr(locale, "profile.language")}>
          {(["zh", "it", "en"] as Locale[]).map((value) => (
            <button
              type="button"
              className={locale === value ? "is-selected" : ""}
              key={value}
              onClick={() => setLocale(value)}
              aria-pressed={locale === value}
            >
              {value === "zh" ? "中文" : value === "it" ? "Italiano" : "English"}
            </button>
          ))}
        </div>
      </section>

      <section className="profile-section">
        <div className="section-heading">
          <div>
            <h2>{tr(locale, "profile.appearance")}</h2>
          </div>
        </div>
        <label className="setting-row">
          <span className="setting-row__copy">
            <Moon size={18} aria-hidden="true" />
            <span>{tr(locale, theme === "dark" ? "profile.dark" : "profile.light")}</span>
          </span>
          <input
            type="checkbox"
            checked={theme === "dark"}
            onChange={(event) => setTheme(event.target.checked ? "dark" : "light")}
          />
          <span className="toggle-track" aria-hidden="true">
            <span />
          </span>
        </label>
        <label className="setting-row">
          <span className="setting-row__copy">
            {reducedMotion ? <Clock3 size={18} aria-hidden="true" /> : <Sun size={18} aria-hidden="true" />}
            <span>{tr(locale, "profile.reduced")}</span>
          </span>
          <input
            type="checkbox"
            checked={reducedMotion}
            onChange={(event) => setReducedMotion(event.target.checked)}
          />
          <span className="toggle-track" aria-hidden="true">
            <span />
          </span>
        </label>
      </section>
    </section>
  );

  const renderCurrentView = () => {
    switch (view) {
      case "home":
        return renderHome();
      case "catalog":
        return renderCatalog();
      case "detail":
        return renderDetail();
      case "cart":
        return renderCart();
      case "checkout":
        return renderCheckout();
      case "orders":
        return renderOrders();
      case "order-detail":
        return renderOrderDetail();
      case "profile":
        return renderProfile();
      default:
        return renderHome();
    }
  };

  const activePrimaryView: PrimaryView =
    view === "checkout"
      ? "cart"
      : view === "order-detail"
        ? "orders"
        : isPrimaryView(view)
          ? view
          : detailOrigin;

  const topTitle = isPrimaryView(view)
    ? tr(locale, primaryTitleKeys[view])
    : view === "detail"
      ? tr(locale, "details.title")
      : view === "checkout"
        ? tr(locale, "checkout.title")
        : tr(locale, "orders.suborder");

  return (
    <div className={"prototype-root " + (theme === "light" ? "theme-light " : "") + (reducedMotion ? "reduce-motion" : "")}>
      <AppShell
        locale={locale}
        activeView={activePrimaryView}
        topTitle={topTitle}
        showBack={!isPrimaryView(view)}
        showBottomNav={isPrimaryView(view)}
        cartCount={cartItemCount}
        searchValue={searchDraft}
        searchPlaceholder={tr(locale, "search.placeholder")}
        onBack={handleBack}
        onNavigate={handleNavigate}
        onCart={() => setView("cart")}
        onSearchChange={handleSearchChange}
        onSearchSubmit={handleSearchSubmit}
        onCategorySelect={selectCategory}
        onLocaleChange={setLocale}
        theme={theme}
        onThemeToggle={() => setTheme((current) => (current === "dark" ? "light" : "dark"))}
      >
        {renderCurrentView()}
      </AppShell>
      {toast ? (
        <div className="toast" role="status">
          {toast}
        </div>
      ) : null}
    </div>
  );
}
