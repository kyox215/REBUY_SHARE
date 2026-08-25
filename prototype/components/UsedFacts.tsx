import { BatteryMedium, CircleAlert, ShieldCheck, Sparkles } from "lucide-react";
import { tr, type Locale, type Product } from "@/lib/data";

type UsedFactsProps = {
  product: Product;
  locale: Locale;
  compact?: boolean;
};

export default function UsedFacts({ product, locale, compact = false }: UsedFactsProps) {
  if (!product.usedFacts) return null;
  const facts = product.usedFacts;
  const entries = [
    { key: "used.condition", icon: Sparkles, value: facts.condition[locale] },
    { key: "used.defect", icon: CircleAlert, value: facts.defect[locale] },
    { key: "used.battery", icon: BatteryMedium, value: facts.battery[locale] },
    { key: "used.warranty", icon: ShieldCheck, value: facts.warranty[locale] },
  ];
  const visibleEntries = entries.filter(
    ({ key }) => !compact || key === "used.condition" || key === "used.battery",
  );

  return (
    <section
      className={`used-facts ${compact ? "used-facts--compact" : ""}`}
      aria-labelledby={!compact ? "used-facts-title" : undefined}
      aria-label={compact ? tr(locale, "used.title") : undefined}
    >
      {!compact ? <h2 id="used-facts-title">{tr(locale, "used.title")}</h2> : null}
      <dl className="fact-grid">
        {visibleEntries.map(({ key, icon: Icon, value }) => (
          <div className="fact" key={key}>
            <dt>
              <Icon size={16} aria-hidden="true" />
              {tr(locale, key)}
            </dt>
            <dd>{value}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
