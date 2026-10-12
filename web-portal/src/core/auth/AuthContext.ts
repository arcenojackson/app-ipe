import type {User} from "firebase/auth";
import {createContext, useContext} from "react";
import type {AccessClaims} from "./access";

export type AuthState =
  | {status: "loading"}
  | {status: "signedOut"}
  | {status: "signedIn"; user: User; claims: AccessClaims};

export interface AuthContextValue {
  state: AuthState;
  /** Renova o token e relê as claims (use depois que um admin mudar o papel). */
  refreshAccess: () => Promise<void>;
  signOut: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | null>(null);

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth deve ser usado dentro de AuthProvider");
  return value;
}
