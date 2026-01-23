/// Remove acentos de uma string para comparação alfabética
String removeAccents(String text) {
  const accents = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÇçÑñÝýÿ';
  const without = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy';
  
  String result = text;
  for (int i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], without[i]);
  }
  return result;
}

/// Compara duas strings ignorando acentos e case
int compareNamesIgnoreAccents(String a, String b) {
  return removeAccents(a.toLowerCase()).compareTo(removeAccents(b.toLowerCase()));
}

/// Compara duas strings (títulos, nomes, etc) ignorando acentos e case
int compareStringsIgnoreAccents(String a, String b) {
  return removeAccents(a.toLowerCase()).compareTo(removeAccents(b.toLowerCase()));
}
