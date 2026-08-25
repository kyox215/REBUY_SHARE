import { AlertTriangle, CheckCircle2, ShoppingCart, XCircle } from "lucide-react";
import PriceBlock from "@/components/PriceBlock";
import SpriteImage from "@/components/SpriteImage";
import UsedFacts from "@/components/UsedFacts";
import { stockState, tr, type Locale, type Product, type Role } from "@/lib/data";

type ProductCardProps = {
  product: Product;
  role: Role;
  locale: Locale;
  cartQuantity: number;
  onOpen: () => void;
  onAdd: () => void;
};

export default function ProductCard({
  product,
  role,
  locale,
  cartQuantity,
  onOpen,
  onAdd,
}: ProductCardProps) {
  const state = stockState(product);
  const stateIcon = state === "in-stock" ? CheckCircle2 : state === "low-stock" ? AlertTriangle : XCircle;
  const StateIcon = stateIcon;
  const stateKey = state === "in-stock" ? "product.inStock" : state === "low-stock" ? "product.lowStock" : "product.outOfStock";

  return (
    <article className={`product-card ${product.kind === "used" ? "product-card--used" : ""}`}>
      <button type="button" className="product-card__visual-button" onClick={onOpen} aria-label={`${tr(locale, "buttons.view")}: ${product.name[locale]}`}>
        <SpriteImage variant={product.sprite} alt={product.name[locale]} priority={product.id === "charger"} />
      </button>
      <div className="product-card__body">
        <div className="product-card__meta">
          <span className="tag">{tr(locale, product.kind === "used" ? "product.used" : "product.new")}</span>
          {product.kind === "used" ? <span className="muted">{tr(locale, "product.single")}</span> : null}
        </div>
        <button type="button" className="product-card__title" onClick={onOpen}>
          {product.name[locale]}
        </button>
        <p className="product-card__summary">{product.summary[locale]}</p>
        <p className="seller-line">{product.merchant}</p>
        <PriceBlock product={product} role={role} locale={locale} quantity={cartQuantity || 1} compact />
        {product.kind === "used" ? <UsedFacts product={product} locale={locale} compact /> : null}
        <div className={`stock-line stock-line--${state}`}>
          <StateIcon size={16} aria-hidden="true" />
          <span>{tr(locale, stateKey)}</span>
          {state !== "out-of-stock" ? <span className="muted">· {product.inventory} {product.unit[locale]}</span> : null}
        </div>
        <button type="button" className="button button--secondary product-card__add" onClick={onAdd} disabled={state === "out-of-stock"}>
          <ShoppingCart size={17} aria-hidden="true" />
          {state === "out-of-stock" ? tr(locale, "product.outOfStock") : tr(locale, "buttons.add")}
          {cartQuantity > 0 ? <span className="button__count">{cartQuantity}</span> : null}
        </button>
      </div>
    </article>
  );
}
