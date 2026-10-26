import type {LibraryItem} from "../types";

const KINDS: Record<string, {label: string; tone: string}> = {
  pdf: {label: "PDF", tone: "bg-[#5b1f2b] text-[#ff8da1]"},
  doc: {label: "DOC", tone: "bg-[#1f3a5b] text-[#8dbcff]"},
  ppt: {label: "PPT", tone: "bg-[#5b3d1f] text-[#ffc58d]"},
  xls: {label: "XLS", tone: "bg-[#1f4a2a] text-[#8de0a0]"},
  img: {label: "IMG", tone: "bg-[#3d2f5b] text-[#c3a8ff]"},
  link: {label: "LINK", tone: "bg-[#1f4a3f] text-[#7fe0c3]"},
  file: {label: "ARQ", tone: "bg-white/10 text-white/70"},
};

const BY_EXTENSION: Record<string, keyof typeof KINDS> = {
  pdf: "pdf", doc: "doc", docx: "doc", odt: "doc", rtf: "doc", txt: "doc",
  ppt: "ppt", pptx: "ppt", odp: "ppt", xls: "xls", xlsx: "xls", csv: "xls",
  png: "img", jpg: "img", jpeg: "img", gif: "img", webp: "img", svg: "img",
};

export function fileKind(item: Pick<LibraryItem, "type" | "fileName" | "name">): {label: string; tone: string} {
  if (item.type === "link") return KINDS.link;
  const ext = (item.fileName ?? item.name).split(".").pop()?.toLowerCase() ?? "";
  return KINDS[BY_EXTENSION[ext] ?? "file"];
}

// Selo colorido do tipo do material (substitui os emojis).
export function FileTypeIcon({item, large = false}: {item: Pick<LibraryItem, "type" | "fileName" | "name">; large?: boolean}) {
  const {label, tone} = fileKind(item);
  return (
    <span
      aria-hidden
      className={`inline-grid shrink-0 place-items-center font-extrabold ${tone} ${
        large ? "h-24 w-24 rounded-3xl text-xl" : "h-9 w-9 rounded-[10px] text-[11px]"
      }`}
    >
      {label}
    </span>
  );
}
