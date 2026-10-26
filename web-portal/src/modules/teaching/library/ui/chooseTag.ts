import {fireEvent, screen} from "@testing-library/react";

// Teste: marca uma tag abrindo, se preciso, o menu do tipo que a contém.
export function chooseTag(name: string) {
  const find = () => screen.queryByRole("checkbox", {name});
  if (!find()) {
    for (const kind of ["Tipo", "Assunto", "Faixa"]) {
      const button = screen.getByRole("button", {name: new RegExp(`^${kind}`)});
      if (button.getAttribute("aria-expanded") !== "true") fireEvent.click(button);
      if (find()) break;
    }
  }
  fireEvent.click(find()!);
}
