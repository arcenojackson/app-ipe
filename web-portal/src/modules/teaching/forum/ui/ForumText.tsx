import {linkify} from "../linkify";

// Texto puro com quebras de linha; só http(s) vira link. Nunca HTML.
export default function ForumText({text}: {text: string}) {
  return (
    <p className="whitespace-pre-wrap break-words">
      {linkify(text).map((part, index) =>
        part.type === "link" ? (
          <a
            key={index}
            href={part.value}
            target="_blank"
            rel="noopener noreferrer"
            className="text-secondary underline"
          >
            {part.value}
          </a>
        ) : (
          <span key={index}>{part.value}</span>
        )
      )}
    </p>
  );
}
