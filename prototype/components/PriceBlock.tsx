import {
  formatCurrency,
  minimumQuantity,
  priceForProduct,
  tr,
  type Locale,
  type Product,
  type Role,
} from "@/lib/data";

type PriceBlockProps = {
  product: Product;
  role: Role;
  locale: Locale;
  quantity?: number;
  compact?: boolean;
};

export default function PriceBlock({
  product,
  role,
  locale,
  quantity = 1,
  compact = false,
}: PriceBlockProps) {
  const wholesale = role === "wholesale";
  const price = priceForProduct(product, role, quantity);
  const minimum = minimumQuantity(product, role);
  const unit = product.unit[locale];

  return (
    <div className={`price-block ${compact ? "price-block--compact" : ""}`}>
      <div className="price-block__main">
        <span className="eyebrow">{tr(locale, wholesale ? "price.wholesale" : "price.retail")}</span>
        <strong>
          {formatCurrency(price, locale)}
          <span className="price-block__unit">/{unit}</span>
        </strong>
      </div>
      {wholesale ? (
        <div className="price-block__conditions">
          <span>
            {tr(locale, "price.minimum")} {minimum} {unit}
          </span>
          {product.wholesaleLadders.length > 0 ? (
            <span>
              {tr(locale, "price.ladder")}: {product.wholesaleLadders.map((tier) => `${tier.minimum} · ${formatCurrency(tier.price, locale)}`).join(" / ")}
            </span>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
