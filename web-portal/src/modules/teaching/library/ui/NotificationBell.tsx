"use client";

import Link from "next/link";
import {useEffect, useState} from "react";
import {subscribeNotifications} from "../notifications";

export function NotificationBell({uid}: {uid: string}) {
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    return subscribeNotifications(
      uid,
      (list) => setUnread(list.filter((n) => n.readAt === null).length),
      () => setUnread(0)
    );
  }, [uid]);

  const label = unread > 0 ? `Notificações (${unread} não lidas)` : "Notificações";
  return (
    <Link href="/ensino/notificacoes" aria-label={label} className="relative inline-flex items-center rounded-button px-3 py-2 hover:bg-white/10">
      <span aria-hidden>🔔</span>
      {unread > 0 && (
        <span aria-hidden className="ml-1 rounded-button bg-error/30 px-1.5 text-xs">{unread}</span>
      )}
    </Link>
  );
}
