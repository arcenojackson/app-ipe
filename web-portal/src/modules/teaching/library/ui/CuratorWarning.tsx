"use client";

import {useEffect, useState} from "react";
import {needsCurators} from "../curators";
import {countCurators} from "../repository";

export function CuratorWarning() {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    let active = true;
    countCurators()
      .then((n) => active && setCount(n))
      .catch(() => undefined);
    return () => {
      active = false;
    };
  }, []);

  if (count === null || !needsCurators(count)) return null;
  const quantity = count === 1 ? "1 curador" : `${count} curadores`;
  return (
    <p role="note" className="rounded-card bg-white/10 p-3 text-sm">
      Há apenas {quantity}. São necessários pelo menos 3 para aprovar o envio de
      um curador e para excluir materiais publicados.
    </p>
  );
}
