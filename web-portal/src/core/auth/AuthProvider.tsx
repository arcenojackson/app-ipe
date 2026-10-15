"use client";

import {onAuthStateChanged, signOut as firebaseSignOut} from "firebase/auth";
import {useCallback, useEffect, useMemo, useRef, useState, type ReactNode} from "react";
import {auth} from "@/core/firebase/client";
import {parseClaims} from "./access";
import {AuthContext, type AuthState} from "./AuthContext";

export function AuthProvider({children}: {children: ReactNode}) {
  const [state, setState] = useState<AuthState>({status: "loading"});
  // Incrementa a cada evento de auth e a cada refresh; descarta respostas obsoletas.
  const requestId = useRef(0);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      const id = ++requestId.current;
      if (!user) {
        setState({status: "signedOut"});
        return;
      }
      const isCurrent = () =>
        mounted.current &&
        requestId.current === id &&
        auth.currentUser?.uid === user.uid;
      try {
        // Força a renovação para pegar claims recém-atribuídas por um admin.
        const token = await user.getIdTokenResult(true);
        if (!isCurrent()) return;
        setState({status: "signedIn", user, claims: parseClaims(token.claims)});
      } catch {
        if (!isCurrent()) return;
        setState({status: "signedIn", user, claims: parseClaims(undefined)});
      }
    });
    return () => {
      mounted.current = false;
      unsubscribe();
    };
  }, []);

  const refreshAccess = useCallback(async () => {
    const user = auth.currentUser;
    if (!user) return;
    const id = ++requestId.current;
    const token = await user.getIdTokenResult(true);
    if (
      !mounted.current ||
      requestId.current !== id ||
      auth.currentUser?.uid !== user.uid
    ) {
      return;
    }
    setState({status: "signedIn", user, claims: parseClaims(token.claims)});
  }, []);

  const signOut = useCallback(() => firebaseSignOut(auth), []);

  const value = useMemo(
    () => ({state, refreshAccess, signOut}),
    [state, refreshAccess, signOut]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
