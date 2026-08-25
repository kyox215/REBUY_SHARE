"use client";

import { Check, ChevronDown } from "lucide-react";
import { useEffect, useId, useRef, useState, type KeyboardEvent } from "react";

export type SelectMenuOption<T extends string> = {
  value: T;
  label: string;
  triggerLabel?: string;
  disabled?: boolean;
};

export type SelectMenuProps<T extends string> = {
  value: T;
  options: Array<SelectMenuOption<T>>;
  onChange: (value: T) => void;
  ariaLabel: string;
  triggerLabel?: string;
  className?: string;
  align?: "start" | "end";
  compact?: boolean;
};

const focusableSelector = [
  "a[href]",
  "area[href]",
  "button:not([disabled])",
  "input:not([disabled]):not([type=hidden])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "iframe",
  "object",
  "embed",
  "[contenteditable=true]",
  "[tabindex]:not([tabindex='-1'])",
].join(",");

function getVisibleFocusableElements() {
  return Array.from(document.querySelectorAll<HTMLElement>(focusableSelector)).filter((element) => {
    const style = window.getComputedStyle(element);
    return style.display !== "none" && style.visibility !== "hidden" && element.getClientRects().length > 0;
  });
}

export default function SelectMenu<T extends string>({
  value,
  options,
  onChange,
  ariaLabel,
  triggerLabel,
  className = "",
  align = "start",
  compact = false,
}: SelectMenuProps<T>) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const menuId = `rebuy-select-menu-${useId().replace(/:/g, "")}`;
  const selectedOption = options.find((option) => option.value === value);
  const displayedTriggerLabel = triggerLabel ?? selectedOption?.triggerLabel ?? selectedOption?.label ?? value;

  useEffect(() => {
    if (!open) return;

    const selectedItem = menuRef.current?.querySelector<HTMLButtonElement>(
      '[role="menuitemradio"][aria-checked="true"]:not([disabled])',
    );
    const firstItem = menuRef.current?.querySelector<HTMLButtonElement>('[role="menuitemradio"]:not([disabled])');
    (selectedItem ?? firstItem ?? menuRef.current)?.focus();
  }, [open]);

  useEffect(() => {
    if (!open) return;

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target;
      if (target instanceof Node && !rootRef.current?.contains(target)) {
        setOpen(false);
      }
    };

    const handleDocumentKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      setOpen(false);
      triggerRef.current?.focus();
    };

    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleDocumentKeyDown);

    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleDocumentKeyDown);
    };
  }, [open]);

  const closeMenu = (restoreFocus = true) => {
    setOpen(false);
    if (restoreFocus) {
      triggerRef.current?.focus();
    }
  };

  const chooseOption = (nextValue: T) => {
    onChange(nextValue);
    closeMenu();
  };

  const handleMenuKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const target = event.target;
    if (!(target instanceof HTMLButtonElement)) return;

    if (event.key === "Tab") {
      event.preventDefault();
      setOpen(false);
      const direction = event.shiftKey ? -1 : 1;
      window.requestAnimationFrame(() => {
        const trigger = triggerRef.current;
        if (!trigger) return;

        const focusableElements = getVisibleFocusableElements();
        const triggerIndex = focusableElements.indexOf(trigger);
        const nextElement = triggerIndex >= 0 ? focusableElements[triggerIndex + direction] : undefined;
        (nextElement ?? trigger).focus();
      });
      return;
    }

    const items = Array.from(menuRef.current?.querySelectorAll<HTMLButtonElement>('[role="menuitemradio"]:not([disabled])') ?? []);
    const currentIndex = items.indexOf(target);

    if (event.key === "ArrowDown" || event.key === "ArrowUp" || event.key === "Home" || event.key === "End") {
      event.preventDefault();
      if (items.length === 0) return;

      const nextIndex = event.key === "Home"
        ? 0
        : event.key === "End"
          ? items.length - 1
          : (currentIndex + (event.key === "ArrowDown" ? 1 : -1) + items.length) % items.length;
      items[nextIndex]?.focus();
      return;
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      const nextValue = target.dataset.selectValue as T | undefined;
      if (nextValue !== undefined) chooseOption(nextValue);
    }
  };

  const handleTriggerKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return;
    event.preventDefault();
    setOpen(true);
  };

  return (
    <div
      ref={rootRef}
      className={`select-menu select-menu--align-${align} ${compact ? "select-menu--compact" : ""} ${className}`.trim()}
    >
      <button
        ref={triggerRef}
        type="button"
        className="select-menu__trigger"
        aria-label={`${ariaLabel}: ${displayedTriggerLabel}`}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={menuId}
        onClick={() => {
          if (open) {
            closeMenu();
          } else {
            setOpen(true);
          }
        }}
        onKeyDown={handleTriggerKeyDown}
      >
        <span className="select-menu__trigger-label">{displayedTriggerLabel}</span>
        <ChevronDown className="select-menu__chevron" size={16} aria-hidden="true" />
      </button>
      {open ? (
        <div
          ref={menuRef}
          id={menuId}
          className="select-menu__menu"
          role="menu"
          aria-label={ariaLabel}
          tabIndex={-1}
          onKeyDown={handleMenuKeyDown}
        >
          {options.map((option) => {
            const selected = option.value === value;
            return (
              <button
                key={option.value}
                type="button"
                className={`select-menu__option ${selected ? "is-selected" : ""}`}
                role="menuitemradio"
                aria-checked={selected}
                aria-label={option.label}
                data-select-value={option.value}
                disabled={option.disabled}
                tabIndex={selected && !option.disabled ? 0 : -1}
                onClick={() => chooseOption(option.value)}
              >
                <span className="select-menu__option-label">{option.label}</span>
                {selected ? <Check size={16} aria-hidden="true" /> : <span className="select-menu__option-placeholder" aria-hidden="true" />}
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
