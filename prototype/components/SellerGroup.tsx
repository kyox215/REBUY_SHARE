import { Trash2 } from "lucide-react";
import PriceBlock from "@/components/PriceBlock";
import QuantityStepper from "@/components/QuantityStepper";
import SpriteImage from "@/components/SpriteImage";
import {
  formatCurrency,
  minimumQuantity,
  priceForProduct,
  tr,
  type CartItem,
  type Locale,
  type Product,
  type Role,
} from "@/lib/data";

type SellerGroupProps = {
  merchant: string;
  items: Array<{ item: CartItem; product: Product }>;
  role: Role;
  locale: Locale;
  onChangeQuantity: (productId: string, quantity: number) => void;
  onRemove: (productId: string) => void;
  onOpen: (productId: string) => void;
};

export default function SellerGroup({
  merchant,
  items,
  role,
  locale,
  onChangeQuantity,
  onRemove,
  onOpen,
}: SellerGroupProps) {
  const subtotal = items.reduce((sum, { item, product }) => sum + priceForProduct(product, role, item.quantity) * item.quantity, 0);

  return (
    <section className="seller-group" aria-labelledby={`seller-${merchant}`}>
      <div className="seller-group__header">
        <div>
          <span className="eyebrow">{tr(locale, "details.seller")}</span>
          <h2 id={`seller-${merchant}`}>{merchant}</h2>
        </div>
        <span className="seller-group__condition">{tr(locale, "status.delivery")}</span>
      </div>
      <div className="seller-group__items">
        {items.map(({ item, product }) => {
          const unitPrice = priceForProduct(product, role, item.quantity);
          const max = Math.max(product.inventory, item.quantity);
          return (
            <article className="cart-row" key={product.id}>
              <button type="button" className="cart-row__visual" onClick={() => onOpen(product.id)} aria-label={`${tr(locale, "buttons.view")}: ${product.name[locale]}`}>
                <SpriteImage variant={product.sprite} alt={product.name[locale]} />
              </button>
              <div className="cart-row__info">
                <button type="button" className="cart-row__title" onClick={() => onOpen(product.id)}>
                  {product.name[locale]}
                </button>
                <p className="muted">{product.kind === "used" ? tr(locale, "cart.singleItem") : product.summary[locale]}</p>
                <PriceBlock product={product} role={role} locale={locale} quantity={item.quantity} compact />
                <div className="cart-row__controls">
                  {product.kind === "used" ? (
                    <span className="fixed-quantity">1 {product.unit[locale]}</span>
                  ) : (
                    <QuantityStepper
                      value={item.quantity}
                      min={minimumQuantity(product, role)}
                      max={max}
                      locale={locale}
                      onChange={(next) => onChangeQuantity(product.id, next)}
                    />
                  )}
                  <button type="button" className="text-button text-button--danger" onClick={() => onRemove(product.id)}>
                    <Trash2 size={16} aria-hidden="true" />
                    {tr(locale, "buttons.remove")}
                  </button>
                </div>
              </div>
              <strong className="cart-row__total">{formatCurrency(unitPrice * item.quantity, locale)}</strong>
            </article>
          );
        })}
      </div>
      <div className="seller-group__footer">
        <span>{tr(locale, "cart.sellerSubtotal")}</span>
        <strong>{formatCurrency(subtotal, locale)}</strong>
      </div>
    </section>
  );
}
