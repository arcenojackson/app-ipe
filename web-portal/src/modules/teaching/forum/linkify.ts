export interface TextPart {
  type: "text" | "link";
  value: string;
}

const URL_PATTERN = /https?:\/\/[^\s<>"']+/g;
const TRAILING = /[.,;:!?)\]]+$/;

// Só http(s) vira link; todo o resto continua texto (nunca HTML).
export function linkify(text: string): TextPart[] {
  const parts: TextPart[] = [];
  let last = 0;
  for (const match of text.matchAll(URL_PATTERN)) {
    const start = match.index ?? 0;
    const url = match[0].replace(TRAILING, "");
    if (start > last) parts.push({type: "text", value: text.slice(last, start)});
    parts.push({type: "link", value: url});
    last = start + url.length;
  }
  if (last < text.length) parts.push({type: "text", value: text.slice(last)});
  return parts;
}
