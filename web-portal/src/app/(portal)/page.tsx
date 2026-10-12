"use client";

import {useRouter} from "next/navigation";
import {useEffect} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {defaultLandingPath, portalModules} from "@/core/modules/registry";
import {AccessDenied} from "@/core/ui/AccessDenied";

export default function HomeRedirect() {
  const {state} = useAuth();
  const router = useRouter();
  const target =
    state.status === "signedIn" ? defaultLandingPath(portalModules, state.claims) : null;

  useEffect(() => {
    if (target) router.replace(target);
  }, [target, router]);

  if (state.status === "signedIn" && !target) return <AccessDenied />;
  return null;
}
