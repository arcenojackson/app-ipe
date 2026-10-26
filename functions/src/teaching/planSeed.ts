/* eslint-disable max-len -- dados da planilha, uma linha por aula */
export interface PlanSeedRow {
  id: string;
  lesson: number;
  theme: string;
  leader?: string;
  knowledge?: string;
  skills?: string;
  essentials?: string;
  notes?: string;
}

// [tema, objetos de conhecimento, habilidades necessárias, aprendizagens essenciais]
type Cells = [string, string, string, string];

// Planilha "Planejamento_Pedagógico_UPA" (aba Planejamento_Anual), na ordem.
const ROWS: Cells[] = [
  ["O que é ser cristão?", "Evangelho, fé, discipulado e identidade cristã", "Diferenciar cristianismo bíblico de uma identidade apenas cultural", "Compreender que ser cristão envolve conhecer e seguir Cristo"],
  ["A Bíblia: Palavra de Deus", "Inspiração, autoridade e suficiência das Escrituras", "Localizar, ler e interpretar textos bíblicos", "Reconhecer a Bíblia como autoridade para fé e vida"],
  ["Como interpretar a Bíblia?", "Contexto, gênero literário, interpretação e aplicação", "Fazer perguntas ao texto e observar contexto", "Entender que a Bíblia deve ser interpretada considerando contexto e conjunto das Escrituras"],
  ["As grandes histórias da Bíblia", "Criação, queda, redenção e consumação", "Identificar conexões entre diferentes partes da Bíblia", "Perceber a unidade da história da redenção"],
  ["O que é uma cosmovisão?", "Cosmovisão cristã e cosmovisões contemporâneas", "Comparar pressupostos e ideias", "Compreender que todos interpretamos a realidade a partir de determinadas crenças"],
  ["Os cinco Solas", "Sola Scriptura, Sola Gratia, Sola Fide, Solus Christus e Soli Deo Gloria", "Relacionar os princípios da Reforma ao evangelho", "Compreender os princípios fundamentais da Reforma Protestante"],
  ["Deus existe?", "Existência de Deus, revelação geral e especial", "Formular e analisar argumentos", "Entender que a fé cristã não é irracional e que Deus se revela"],
  ["Quem é Deus?", "Atributos de Deus", "Ler textos descritivos sobre Deus", "Conhecer atributos como santidade, justiça, amor, eternidade e onipotência"],
  ["A Trindade", "Pai, Filho e Espírito Santo", "Relacionar diferentes textos bíblicos", "Compreender a doutrina de um só Deus em três pessoas"],
  ["Deus é soberano", "Providência, governo e soberania divina", "Relacionar soberania e acontecimentos da vida", "Compreender que Deus governa todas as coisas"],
  ["Se Deus é bom, por que existe sofrimento?", "Problema do mal, providência e queda", "Argumentar diante de questões difíceis", "Desenvolver uma resposta cristã ao sofrimento sem negar sua realidade"],
  ["Conhecer Deus e adorá-lo", "Conhecimento de Deus, culto e reverência", "Relacionar doutrina e prática", "Entender que conhecer Deus deve produzir adoração"],
  ["Deus criou todas as coisas", "Criação e providência", "Relacionar Gênesis com a cosmovisão cristã", "Reconhecer Deus como Criador e a criação como boa"],
  ["O ser humano foi criado à imagem de Deus", "Imago Dei, dignidade humana", "Aplicar o conceito a questões contemporâneas", "Compreender a dignidade de toda pessoa humana"],
  ["O que deu errado?", "Queda e pecado original", "Identificar consequências da queda", "Entender a entrada do pecado e sua abrangência"],
  ["O pecado no coração humano", "Corrupção, idolatria e depravação", "Identificar manifestações do pecado", "Compreender que o pecado afeta todas as áreas da vida"],
  ["Ídolos modernos", "Idolatria, cultura, dinheiro, aprovação, sexualidade, poder", "Analisar situações cotidianas à luz da Bíblia", "Reconhecer ídolos contemporâneos e a necessidade de adoração a Deus"],
  ["Quem é Jesus?", "Pessoa de Cristo, divindade e humanidade", "Analisar textos cristológicos", "Confessar Jesus como verdadeiro Deus e verdadeiro homem"],
  ["A encarnação", "Nascimento e missão de Cristo", "Relacionar profecias e Evangelhos", "Compreender por que o Filho de Deus se tornou homem"],
  ["A vida perfeita de Cristo", "Obediência ativa e passiva", "Relacionar vida de Cristo e salvação", "Entender Cristo como representante perfeito de seu povo"],
  ["A cruz", "Expiação, substituição, propiciação e reconciliação", "Explicar diferentes aspectos da cruz", "Compreender a centralidade da morte de Cristo"],
  ["A ressurreição", "Ressurreição corporal e vitória sobre a morte", "Analisar evidências e textos bíblicos", "Reconhecer a ressurreição como fundamento da fé cristã"],
  ["Ascensão e senhorio de Cristo", "Ascensão, reinado e intercessão", "Relacionar a ascensão à vida cristã", "Entender que Cristo reina atualmente"],
  ["Cristo é suficiente", "União com Cristo e centralidade do evangelho", "Avaliar falsas formas de \"completar\" o evangelho", "Compreender que a salvação está fundamentada na obra de Cristo"],
  ["O que é salvação?", "Pecado, morte, graça e redenção", "Explicar a necessidade da salvação", "Compreender por que o ser humano precisa de um Salvador"],
  ["Eleição e graça", "Eleição, predestinação e soberania", "Ler Romanos 8–9 e Efésios 1 com orientação", "Compreender a iniciativa soberana de Deus na salvação"],
  ["Chamado eficaz e novo nascimento", "Regeneração e conversão", "Diferenciar conversão exterior e transformação interior", "Entender a necessidade do novo nascimento"],
  ["Justificação pela fé", "Justificação, fé e obras", "Distinguir justificação e santificação", "Compreender que somos justificados pela fé, não por méritos"],
  ["Adoção: filhos de Deus", "Adoção e identidade cristã", "Relacionar doutrina e identidade", "Compreender a nova identidade do cristão"],
  ["Santificação", "Santificação, boas obras e mortificação do pecado", "Aplicar princípios bíblicos à vida", "Entender que a graça produz transformação"],
  ["Perseverança dos santos", "Segurança da salvação e perseverança", "Avaliar dúvidas e falsas compreensões", "Compreender a fidelidade de Deus na preservação dos seus filhos"],
  ["Quem é o Espírito Santo?", "Pessoa e divindade do Espírito", "Identificar sua atuação bíblica", "Compreender o Espírito como Deus e pessoa"],
  ["O Espírito e a conversão", "Regeneração, habitação e selo", "Relacionar Espírito e salvação", "Entender sua atuação na vida do crente"],
  ["Fruto do Espírito", "Gálatas 5:22–23", "Avaliar atitudes e comportamentos", "Compreender o caráter cristão como fruto da ação do Espírito"],
  ["Dons espirituais", "Dons, serviço e edificação", "Identificar diferentes formas de servir", "Compreender dons como instrumentos para edificação da igreja"],
  ["Como o cristão cresce?", "Palavra, oração, comunhão e santificação", "Construir práticas espirituais", "Compreender os meios pelos quais Deus promove nosso crescimento"],
  ["Por que existe Igreja?", "Igreja visível e invisível", "Compreender pertencimento comunitário", "Reconhecer que o cristianismo não é uma experiência individual isolada"],
  ["A Igreja e sua missão", "Grande Comissão, evangelização e discipulado", "Pensar em formas de testemunho", "Compreender a missão da Igreja"],
  ["Pregação e Palavra", "Palavra como meio de graça", "Ouvir, interpretar e aplicar uma pregação", "Valorizar a exposição fiel das Escrituras"],
  ["Batismo", "Sacramento, significado e prática reformada", "Comparar compreensões cristãs", "Compreender o significado do batismo na tradição reformada"],
  ["Ceia do Senhor", "Sacramento, presença de Cristo e comunhão", "Interpretar 1 Coríntios 11", "Compreender a Ceia como meio de graça e comunhão"],
  ["O adolescente na Igreja", "Serviço, comunhão, liderança e pertencimento", "Identificar possibilidades de participação", "Compreender que adolescentes também são membros ativos do corpo de Cristo"],
  ["Como saber o que é certo?", "Lei de Deus, consciência e princípios bíblicos", "Aplicar princípios a situações concretas", "Compreender a Bíblia como referência para a vida"],
  ["Cristão e redes sociais", "Testemunho, verdade, exposição, comparação e vaidade", "Analisar comportamentos digitais", "Desenvolver uma postura cristã no ambiente digital"],
  ["Amizade, namoro, relacionamento e sexualidade", "Santidade, corpo, relacionamentos e casamento", "Refletir biblicamente sobre relacionamentos", "Compreender sexualidade e relacionamentos dentro da perspectiva cristã"],
  ["Trabalho, estudo e vocação", "Vocação, serviço e mordomia", "Relacionar fé e vida cotidiana", "Entender que estudar e trabalhar também podem ser formas de servir a Deus"],
  ["Dinheiro, sucesso e contentamento", "Mordomia, materialismo e generosidade", "Avaliar valores culturais", "Desenvolver uma visão cristã sobre bens, sucesso e consumo"],
  ["O que acontece depois da morte?", "Morte, estado intermediário e ressurreição", "Organizar a compreensão bíblica da vida futura", "Compreender a esperança cristã"],
  ["A volta de Cristo", "Segunda vinda e juízo", "Interpretar textos escatológicos", "Reconhecer a certeza da volta de Cristo"],
  ["Novos céus e nova terra", "Consumação, ressurreição e Reino", "Relacionar esperança futura e vida presente", "Compreender que a esperança cristã é a restauração da criação"],
  ["O que eu creio?", "Síntese da teologia cristã reformada", "Organizar e explicar a própria compreensão", "Ser capaz de apresentar os principais fundamentos da fé cristã"],
  ["Minha vida diante de Deus", "Cosmovisão, discipulado, vocação e missão", "Integrar conhecimento e prática", "Compreender que teologia deve conduzir à adoração e à vida transformada"],
];

// Orientador responsável (só nas aulas em que a planilha preenche) e observações.
const LEADERS: Record<number, string> = {
  6: "Yara", 12: "Lyla", 25: "Karen", 30: "Felipe", 34: "Állan", 44: "Guilherme", 45: "Guilherme",
};
const NOTES: Record<number, string> = {
  2: "Talvez aqui seja interessante discutir sobre formação do Cânon Bíblico e a história secular que a permeia",
};

export const PLAN_SEED: PlanSeedRow[] = ROWS.map(
  ([theme, knowledge, skills, essentials], index) => {
    const lesson = index + 1;
    return {
      id: `aula-${String(lesson).padStart(2, "0")}`,
      lesson,
      theme,
      ...(LEADERS[lesson] ? {leader: LEADERS[lesson]} : {}),
      knowledge,
      skills,
      essentials,
      ...(NOTES[lesson] ? {notes: NOTES[lesson]} : {}),
    };
  }
);
