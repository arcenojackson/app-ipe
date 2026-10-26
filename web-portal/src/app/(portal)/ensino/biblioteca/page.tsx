import {redirect} from "next/navigation";
import {libraryUrl} from "@/modules/teaching/library/url";

// Endereço antigo da biblioteca (links de push e notificações): a Início é a biblioteca.
export default async function Page({searchParams}: {searchParams: Promise<{item?: string | string[]}>}) {
  const {item} = await searchParams;
  redirect(libraryUrl({item: Array.isArray(item) ? item[0] : item}));
}
