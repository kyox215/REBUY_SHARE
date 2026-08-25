import Image from "next/image";
import type { SpriteVariant } from "@/lib/data";

type SpriteImageProps = {
  variant: SpriteVariant;
  alt: string;
  priority?: boolean;
  className?: string;
};

export default function SpriteImage({
  variant,
  alt,
  priority = false,
  className = "",
}: SpriteImageProps) {
  return (
    <div className={`sprite-frame sprite-frame--${variant} ${className}`}>
      <Image
        src="/product-sprite.png"
        alt={alt}
        width={1254}
        height={1254}
        unoptimized
        loading="eager"
        preload={priority}
        sizes="(max-width: 767px) 46vw, (max-width: 1199px) 30vw, 280px"
      />
    </div>
  );
}
