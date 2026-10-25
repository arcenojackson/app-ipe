import type {BadgeTone} from "../status";

const TONES: Record<BadgeTone, string> = {
  neutral: "bg-white/10",
  info: "bg-secondary/30",
  success: "bg-primary/50",
  warning: "bg-white/20 ring-1 ring-secondary/60",
  danger: "bg-error/20 text-error",
};

export function StatusBadge({badge}: {badge: {label: string; tone: BadgeTone}}) {
  if (!badge.label) return null;
  return (
    <span className={`rounded-button px-2 py-0.5 text-xs ${TONES[badge.tone]}`}>
      {badge.label}
    </span>
  );
}
