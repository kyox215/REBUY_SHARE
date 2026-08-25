import { Minus, Plus } from "lucide-react";
import { tr, type Locale } from "@/lib/data";

type QuantityStepperProps = {
  value: number;
  min: number;
  max: number;
  locale: Locale;
  onChange: (next: number) => void;
};

export default function QuantityStepper({ value, min, max, locale, onChange }: QuantityStepperProps) {
  return (
    <div className="quantity-stepper" aria-label={`${tr(locale, "cart.quantity")}: ${value}`}>
      <button
        type="button"
        className="icon-button icon-button--small"
        onClick={() => onChange(Math.max(min, value - 1))}
        disabled={value <= min}
        aria-label={tr(locale, "buttons.decrease")}
        title={tr(locale, "buttons.decrease")}
      >
        <Minus size={17} aria-hidden="true" />
      </button>
      <span aria-live="polite">{value}</span>
      <button
        type="button"
        className="icon-button icon-button--small"
        onClick={() => onChange(Math.min(max, value + 1))}
        disabled={value >= max}
        aria-label={tr(locale, "buttons.increase")}
        title={tr(locale, "buttons.increase")}
      >
        <Plus size={17} aria-hidden="true" />
      </button>
    </div>
  );
}
