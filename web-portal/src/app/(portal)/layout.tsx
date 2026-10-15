import {PortalShell} from "@/core/ui/PortalShell";

export default function PortalLayout({children}: {children: React.ReactNode}) {
  return <PortalShell>{children}</PortalShell>;
}
