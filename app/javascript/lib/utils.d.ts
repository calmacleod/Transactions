import type { ClassValue } from "clsx"

export type WithElementRef<T, U extends HTMLElement = HTMLElement> = T & { ref?: U | null }
export type WithoutChildrenOrChild<T> = Omit<T, "children" | "child">

export function cn(...inputs: ClassValue[]): string
