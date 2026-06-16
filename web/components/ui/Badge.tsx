import * as React from "react";
import { cn } from "@/lib/utils";

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: "default" | "success" | "warning" | "danger" | "info";
}

const Badge = React.forwardRef<HTMLSpanElement, BadgeProps>(
  ({ className, variant = "default", ...props }, ref) => {
    const variants = {
      default: "bg-[#E8EAED] dark:bg-[#262626] text-[#5F6368] dark:text-[#a3a3a3]",
      success: "bg-[#DCF5E3] dark:bg-[#22c55e]/15 text-[#0D5425] dark:text-[#4ade80]",
      warning: "bg-[#FEF7E0] dark:bg-[#eab308]/15 text-[#B06000] dark:text-[#facc15]",
      danger: "bg-[#FCE8E6] dark:bg-[#ef4444]/15 text-[#C5221F] dark:text-[#f87171]",
      info: "bg-[#E8F0FE] dark:bg-[#3b82f6]/15 text-[#1A73E8] dark:text-[#60a5fa]",
    };

    return (
      <span
        ref={ref}
        className={cn(
          "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
          variants[variant],
          className
        )}
        {...props}
      />
    );
  }
);
Badge.displayName = "Badge";

export { Badge };
