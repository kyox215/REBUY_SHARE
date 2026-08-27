import { useId } from "react";

type BrandMarkProps = {
  compact?: boolean;
};

/**
 * Local, deliberately simple brand primitive for the buyer prototype.
 * The mark is an abstract R rather than a copy of the reference artwork.
 */
export default function BrandMark({ compact = false }: BrandMarkProps) {
  const gradientId = `rebuy-brand-gradient-${useId().replace(/:/g, "")}`;

  return (
    <span className={`brand-lockup${compact ? " brand-lockup--compact" : ""}`} role="img" aria-label="Rebuy">
      <svg className="brand-lockup__mark" viewBox="0 0 32 32" aria-hidden="true" focusable="false">
        <defs>
          <linearGradient id={gradientId} x1="5" y1="4" x2="27" y2="28" gradientUnits="userSpaceOnUse">
            <stop stopColor="#087F72" />
            <stop offset="1" stopColor="#34B7A3" />
          </linearGradient>
        </defs>
        <path
          d="M8 6.5h8.25c4.7 0 7.75 2.45 7.75 6.25 0 2.7-1.55 4.7-4.1 5.6L25.5 25H20l-4.8-6.05H13V25H8V6.5Zm5 4v4.45h3.05c1.95 0 3-.72 3-2.2 0-1.5-1.05-2.25-3-2.25H13Z"
          fill={`url(#${gradientId})`}
        />
        <path d="m18.5 17.65 6.8 7.35h-5.6l-4.35-5.5 3.15-1.85Z" fill="#18A28F" opacity=".72" />
      </svg>
      {!compact ? <span className="brand-lockup__wordmark">Rebuy</span> : null}
    </span>
  );
}
