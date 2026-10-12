"use client";

import {onAuthStateChanged, signOut as firebaseSignOut} from "firebase/auth";
import {useCallback, useEffect, useMemo, useState, type ReactNode} from "react";
import {auth} from "@/core/firebase/client";
import {parseClaims} from "./access";
import {AuthContext, type AuthState} from "./AuthContext";

export function AuthProvider({children}: {children: ReactNode}) {
  const [state, setState] = useState<AuthState>({status: "loading"});

  useEffect(() => {
    return onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setState({status: "signedOut"});
        return;
      }
      try {
        // Força a renovação para pegar claims recém-atribuídas por um admin.
        const token = await user.getIdTokenResult(true);
        setState({status: "signedIn", user, claims: parseClaims(token.claims)});
      } catch {
        setState({status: "signedIn", user, claims: parseClaims(undefined)});
      }
    });
  }, []);

  const refreshAccess = useCallback(async () => {
    const user = auth.currentUser;
    if (!user) return;
    const token = await user.getIdTokenResult(true);
    setState({status: "signedIn", user, claims: parseClaims(token.claims)});
  }, []);

  const signOut = useCallback(() => firebaseSignOut(auth), []);

  const value = useMemo(
    () => ({state, refreshAccess, signOut}),
    [state, refreshAccess, signOut]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
