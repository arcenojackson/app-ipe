"use client";

import Link from "next/link";
import {useEffect, useState} from "react";
import {Icon} from "@/core/ui/icons";
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
    <Link href="/ensino/notificacoes" aria-label={label} className="relative inline-flex h-10 items-center rounded-full bg-surface-elevated px-3 hover:brightness-125">
      <Icon name="bell" />
      {unread > 0 && (
        <span aria-hidden className="ml-1.5 rounded-full bg-error px-1.5 text-xs">{unread}</span>
      )}
    </Link>
  );
}
