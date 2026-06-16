import * as React from "react";
import { cn } from "@/lib/utils";

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "default" | "destructive" | "outline" | "secondary" | "ghost" | "link";
  size?: "default" | "sm" | "lg" | "icon";
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "default", size = "default", ...props }, ref) => {
    const baseStyles =
      "inline-flex items-center justify-center whitespace-nowrap rounded-full text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50";

    const variants = {
      default: "bg-[#1E8E3E] text-white hover:bg-[#167D34] focus-visible:ring-[#1E8E3E]",
      destructive: "bg-[#D93025] text-white hover:bg-[#C12B20] focus-visible:ring-[#D93025]",
      outline: "border border-[#DADCE0] dark:border-[#404040] bg-white dark:bg-[#262626] hover:bg-[#F8F9FA] dark:hover:bg-[#333333] text-[#202124] dark:text-white focus-visible:ring-[#1E8E3E]",
      secondary: "bg-[#DCF5E3] dark:bg-[#22c55e]/15 text-[#0D5425] dark:text-[#4ade80] hover:bg-[#C9EED5] dark:hover:bg-[#22c55e]/25 focus-visible:ring-[#1E8E3E]",
      ghost: "hover:bg-[#F8F9FA] dark:hover:bg-[#262626] text-[#202124] dark:text-[#a3a3a3] focus-visible:ring-[#1E8E3E]",
      link: "text-[#1E8E3E] dark:text-[#4ade80] underline-offset-4 hover:underline",
    };

    const sizes = {
      default: "h-11 px-6 py-2",
      sm: "h-9 rounded-full px-4",
      lg: "h-12 rounded-full px-8",
      icon: "h-10 w-10",
    };

    return (
      <button
        className={cn(baseStyles, variants[variant], sizes[size], className)}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

export { Button };
