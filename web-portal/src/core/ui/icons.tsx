import type {SVGProps} from "react";

// Ícones de traço (24x24) usados no menu e nas barras. `currentColor`, então
// herdam a cor do texto.
const PATHS = {
  search: "M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm10 2-4.3-4.3",
  bell: "M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9Zm4.3 13a1.9 1.9 0 0 0 3.4 0",
  library: "M4 4h4v16H4zM10 4h4v16h-4zM16.5 5.5l3.8-1 3.2 14.5-3.8 1z",
  plan: "M5 3h14a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Zm3 5h8M8 12h8M8 16h5",
  review: "M12 16V4m0 0 4 4m-4-4L8 8M4 14v5a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-5",
  forum: "M21 12a8 8 0 0 1-11.7 7.1L4 20l1-4.6A8 8 0 1 1 21 12Z",
  admin: "M16 11a4 4 0 1 0-8 0 4 4 0 0 0 8 0ZM4 21a8 8 0 0 1 16 0",
  list: "M4 6h16M4 12h16M4 18h16",
  grid: "M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z",
  plus: "M12 5v14M5 12h14",
} as const;

export type IconName = keyof typeof PATHS;

export function Icon({name, className = "h-5 w-5", ...props}: {name: IconName} & SVGProps<SVGSVGElement>) {
  return (
    <svg
      aria-hidden
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      {...props}
    >
      <path d={PATHS[name]} />
    </svg>
  );
}
