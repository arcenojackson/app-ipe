export const formatDate = (millis: number): string =>
  millis ? new Date(millis).toLocaleDateString("pt-BR") : "";
