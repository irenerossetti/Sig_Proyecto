import * as React from "react";
import { cn } from "@/lib/utils";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  rightIcon?: React.ReactNode;
}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, label, error, id, rightIcon, ...props }, ref) => {
    const generatedId = React.useId();
    const inputId = id || generatedId;
    
    return (
      <div className="w-full">
        {label && (
          <label
            htmlFor={inputId}
            className="block text-sm font-medium text-[#202124] dark:text-[#fafafa] mb-1"
          >
            {label}
          </label>
        )}
        <div className="relative">
          <input
            type={type}
            id={inputId}
            className={cn(
              "flex h-11 w-full rounded-2xl border border-[#DADCE0] dark:border-[#404040] bg-white dark:bg-[#262626] px-4 py-2 text-sm text-[#202124] dark:text-[#fafafa] placeholder:text-[#5F6368] dark:placeholder:text-[#737373] focus:outline-none focus:ring-2 focus:ring-[#1E8E3E] dark:focus:ring-[#4ade80] focus:border-transparent disabled:cursor-not-allowed disabled:opacity-50",
              rightIcon && "pr-11",
              error && "border-[#D93025] focus:ring-[#D93025]",
              className
            )}
            ref={ref}
            {...props}
          />
          {rightIcon && (
            <span className="absolute inset-y-0 right-3 flex items-center">
              {rightIcon}
            </span>
          )}
        </div>
        {error && <p className="mt-1 text-sm text-[#D93025] dark:text-[#f87171]">{error}</p>}
      </div>
    );
  }
);
Input.displayName = "Input";

export { Input };
