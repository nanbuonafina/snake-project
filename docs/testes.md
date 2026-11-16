# Relatório de testes — Projeto Snake

- **Data da execução:** 15/11/2026
- **Simulador:** MARS 4.5 (`tools/Mars4_5.jar`, SHA-256 `ac340b67…0b7096`)
- **Java:** OpenJDK 21.0.13. **Sistema:** Arch Linux (GNOME/Wayland).
- **Como reproduzir:** `tools/run_tests.sh`. A saída da última execução fica
  em `tests/build/ultimo_resultado.txt`, que não é versionado.

**Resultado da última execução:** 112 verificações automáticas aprovadas, 0
reprovadas. Os testes manuais estão **concluídos**.

## Como os testes automáticos funcionam

- **T00 a T12 e T15:** drivers em Assembly MIPS (`tests/t_*.asm`) montados
  junto com as rotinas reais de `src/snake.asm`, sem o bloco `main`. Rodam no
  MARS sem interface (`nc`), com o código de saída 3 em qualquer erro de
  execução. As teclas são simuladas escrevendo nos registradores MMIO do
  receptor (0xFFFF0000 e 0xFFFF0004) e chamando a rotina real `read_input`.
- **T13 e T14:** o programa **completo**, com o `main` real e a temporização
  real. O MARS imprime o framebuffer (0x10010000–0x10010FFC) e as variáveis
  (0x10012000–0x1001201C) ao fim da execução, e o script confere esses
  valores.
- **T16:** `tools/BitmapProbe.java` instancia a classe real
  `mars.tools.BitmapDisplay`, sem mostrar a janela. Ele configura os campos
  como na interface, "conecta", executa o jogo real e desenha o painel em PNG
  (`tests/build/t16_*.png`).
- **Limite dos testes automáticos:** nenhum deles mostra a janela na tela nem
  usa o Keyboard Simulator de verdade. O T16 exercita o código de desenho do
  MARS, mas não a janela, o gerenciador de janelas nem o teclado real.

## 1. Testes funcionais

| ID | Nome | Objetivo | Procedimento | Resultado esperado | Resultado observado | Status |
|---|---|---|---|---|---|---|
| F-01 | Posição inicial | Cobra começa em (0,0) | `t_init`: `init_game`; ler `body[0]`, cor da célula 0, `head_idx`, `tail_idx` | `body[0]=0`, célula 0 azul, índices 0 | Conforme esperado | ✅ |
| F-02 | Comprimento inicial | Tamanho 1 | `t_init`: ler `length` e contar células azuis | `length=1`, 1 célula azul | Conforme esperado | ✅ |
| F-03 | Comida inicial válida | Comida em posição válida | `t_init`: contar células verdes; ler a cor em `food_idx` | 1 célula verde, em `food_idx`; 1022 pretas | Conforme esperado | ✅ |
| F-04 | Faixa do sorteio | I e J em 0..31, com extremos alcançáveis | `t_food`: 2000 sorteios; registrar linhas e colunas sorteadas em máscara de bits | Índices em 0..1023; máscaras = 0xFFFFFFFF | Conforme esperado (todas as 32 linhas e colunas sorteadas) | ✅ |
| F-05 | 4 direções | Cada direção move a cabeça corretamente | `t_move`: ir até (10,10); então esquerda, cima, direita e baixo | 329, 297, 298, 330 | Conforme esperado | ✅ |
| F-06 | Teclas WASD | Mapeamento das teclas e maiúsculas | `t_input`: simular `a`, `W`, `s`, `D`, `x` no MMIO | Direções corretas; `x` ignorada | Conforme esperado | ✅ |
| F-07 | Sem tecla pronta | Leitura não bloqueante | `t_input`: bit de controle = 0; chamar `read_input` | Retorna sem mudar a direção | Conforme esperado | ✅ |
| F-08 | Inversão (D2) | Tecla oposta é ignorada | `t_input`: oposta nas 4 direções | Direção inalterada | Conforme esperado | ✅ |
| F-09 | Continuidade | Sem tecla, repete a direção | `t_input`: direção baixo e 3 `step` sem tecla | Cabeça em (3,0) = 96 | Conforme esperado | ✅ |
| F-10 | Continuidade no jogo real | Movimento contínuo no laço real | T13: tecla `d` uma única vez; jogo completo | Anda até a parede direita (31 movimentos) | 31 movimentos, colisão com a parede | ✅ |
| F-11 | Intervalo de 500 ms | Duração de um tick | `t_input`: medir `wait_tick` com a syscall 30 | 1 tick em [500, 600) ms; 4 ticks em [2000, 2100) ms | Conforme esperado | ✅ |
| F-12 | Ritmo no jogo real | 32 ticks no jogo completo | T13: medir o tempo total | ≥ 16000 ms (+ início do Java) | 16521 ms | ✅ |
| F-13 | Crescimento | +1 célula ao comer, na cauda | `t_move`: comida em (0,1), mover à direita | `length=2`; (0,0) continua azul | Conforme esperado | ✅ |
| F-14 | Reposicionamento | Nova comida após coleta | `t_move`: contar células verdes após comer | 1 comida, fora da cobra | Conforme esperado | ✅ |
| F-15 | Comida nunca sobre a cobra | Rejeição de células ocupadas | `t_food`: metade da grade azul + 1000 sorteios; depois só a célula 777 livre | Nenhum sorteio na metade azul; comida em 777 | Conforme esperado | ✅ |
| F-16 | Parede de cima | Detecção | `t_collide`: de (0,0), cima | `STATUS_WALL` | Conforme esperado | ✅ |
| F-17 | Parede da esquerda | Detecção | `t_collide`: de (0,0), esquerda | `STATUS_WALL` | Conforme esperado | ✅ |
| F-18 | Parede da direita | Detecção | `t_collide`: 31 passos à direita (todos OK) + 1 | `STATUS_WALL` no 32º | Conforme esperado | ✅ |
| F-19 | Parede de baixo | Detecção | `t_collide`: 31 passos para baixo + 1 | `STATUS_WALL` no 32º | Conforme esperado | ✅ |
| F-20 | Colisão com o corpo | Detecção | `t_collide`: cobra de 5 em L; subir sobre (0,3) | `STATUS_BODY` | Conforme esperado | ✅ |
| F-21 | Encerramento | O jogo termina na colisão | T13: programa completo | Relatório impresso; programa encerra | Relatório impresso; MARS encerra | ✅ |
| F-22 | Relatório final no console | Pontuação e estado final | T13: ler a saída do console | Motivo, comprimento, comidas, movimentos e pontuação coerentes | "colisao com a parede", 31 movimentos, 31 pontos | ✅ |
| F-23 | Diálogo final | Caixa com a pontuação (syscall 56) | Só no MARS com interface | Diálogo "GAME OVER! Pontuacao final: N" | — (sem interface: `HeadlessException`, esperado) | ⏸ |
| F-24 | Fim por grade cheia (D8) | Não sortear comida sem célula livre | `t_collide`: `length=1023` artificial + comer | `STATUS_FULL` | Conforme esperado | ✅ |

## 2. Testes de pontuação

| ID | Nome | Objetivo | Procedimento | Resultado esperado | Resultado observado | Status |
|---|---|---|---|---|---|---|
| P-01 | 1 ponto por tick | +1 a cada 0,5 s | `t_move`: 5 passos sem comida | 5 | 5 | ✅ |
| P-02 | +5 por comida | Bônus por comida | `t_move`: 1 passo comendo | 1 + 5 = 6 | 6 | ✅ |
| P-03 | Acumulado longo | Somas corretas | `t_move`: 2009 ticks + 5 comidas | 2034 | 2034 | ✅ |
| P-04 | Colisão não pontua (D7) | Sem ponto no tick fatal | `t_collide`: parede após 31 passos; corpo após 4 comidas + 2 ticks | 31; 26 | 31; 26 | ✅ |
| P-05 | Espera inicial não pontua | Sem pontos antes da 1ª tecla | T14: jogo real sem tecla por 3 milhões de instruções; ler `score` na memória | `score=0`, `length=1`, cobra em (0,0) | Conforme esperado | ✅ |
| P-06 | Pausa não gera pontos extras | Pause no MARS não acumula ticks | `t_input`: prazo 5 s no passado; contar ticks que vencem em 300 ms | 1 tick / 1 ponto; os 3 ticks seguintes levam ≥ 1000 ms | 1 ponto; ≥ 1000 ms (**após a correção C-01**) | ✅ |
| P-07 | Pontuação a cada passo | Pontuação exata em milhares de passos | T15: comparar `score` com ticks + 5 × comidas após cada passo | Sempre igual | 4000 passos sem divergência | ✅ |
| P-08 | Pontuação final real | Relatório = memória = regra | T13: console vs. memória vs. movimentos + 5 × comidas | Iguais | 31 = 31 = 31 + 5 × 0 (numa execução anterior, com comida no caminho: 36 = 31 + 5 × 1) | ✅ |

## 3. Testes de memória e algoritmo

| ID | Nome | Objetivo | Procedimento | Resultado esperado | Resultado observado | Status |
|---|---|---|---|---|---|---|
| M-01 | Atualização de todos os segmentos | O corpo segue a cabeça | T15: após cada passo, percorrer a fila e checar se segmentos consecutivos são adjacentes | Sempre adjacentes | 4000 passos, 0 violações | ✅ |
| M-02 | Crescimento sem perda | Nenhum segmento some ou se repete | T15: fila sem repetição; azuis na tela = `length` | Sempre | 0 violações; comprimento máximo de 27 e de 34 em duas execuções | ✅ |
| M-03 | Fila circular dando a volta | Índices `& 1023` corretos | `t_move`: 2009 inserções num circuito 2×3 (período 6, que não divide 1024); conferir `head_idx`, `tail_idx` e o conteúdo da fila | 985, 980 e as células (0,0)…(1,0) em ordem | Conforme esperado | ✅ |
| M-04 | Acessos inválidos | Nenhum acesso desalinhado ou fora de segmento | Todos os testes rodam com `se3` (qualquer exceção de execução reprova); T15 checa índices em 0..1023 | Nenhuma exceção | Nenhuma exceção no código do jogo | ✅ |
| M-05 | Limites da grade | −1 e 32 detectados | F-16 a F-19; comparação sem sinal (`bgeu`) | `STATUS_WALL` nos 4 lados | Conforme esperado | ✅ |
| M-06 | Cobra com várias células | Comportamento com cobra longa | T15: jogo automático até comprimento ≥ 20, com colisões de parede e de corpo | Comprimento ≥ 20; ambas as colisões ocorrem; invariantes OK | Comprimento máximo 27; 9 colisões com parede e 5 com o corpo (última execução) | ✅ |
| M-07 | Entrar na célula da cauda (D6) | A cabeça pode ocupar a célula que a cauda libera | `t_move`: 2004 passos num circuito 2×3 com cobra de 6, em que a cabeça entra sempre na célula da cauda | Todos `STATUS_OK` | Conforme esperado | ✅ |
| M-08 | Estado intacto após colisão | A colisão não altera fila nem tela | `t_collide` + T15: comprimento, `head_idx`, pontuação e tela depois da colisão | Iguais ao estado anterior | Conforme esperado | ✅ |
| M-09 | Eficácia dos testes (mutação) | Os testes detectam defeitos | 14 defeitos injetados de propósito (§5) | Todos detectados | 14/14 detectados | ✅ |

## 4. Testes de interface

| ID | Nome | Objetivo | Procedimento | Resultado esperado | Resultado observado | Status |
|---|---|---|---|---|---|---|
| I-01 | Endereço-base | `frame` em 0x10010000 | `t_grid`: `la frame` | 0x10010000 | 0x10010000 | ✅ |
| I-02 | Coordenadas → endereços | Célula (l,c) → 0x10010000 + (32l+c)·4 | `t_grid`: escrever nas células (0,0), (0,31), (31,0), (31,31) e ler o endereço físico | 0x…0000, 0x…007C, 0x…0F80, 0x…0FFC | Conforme esperado | ✅ |
| I-03 | Endereços → pixels no MARS | Confirmar o mapeamento do Bitmap Display | Análise do bytecode de `mars.tools.BitmapDisplay` (`javap -c`): `createNewGrid` e `updateColorForAddress` | colunas = 512/16 = 32; linhas = 512/16 = 32; word k → linha k/32, coluna k%32; unidade de 16×16 px | Confirmado: `offset=(end−base)/4`, `linha=offset/colunas`, `coluna=offset%colunas`; 16 e 512 estão entre as opções | ✅ (análise estática) |
| I-04 | Limpeza da tela | `clear_screen` pinta as 1024 células | `t_grid`: contar células pretas | 1024 | 1024 | ✅ |
| I-05 | Sem rastros (memória) | A tela reflete só a cobra e a comida | T15 (após cada passo) e T13 (tela final) | Azuis = `length`; 1 verde; resto preto; nenhuma outra cor | Conforme esperado | ✅ |
| I-06 | Tela final | Cabeça vermelha onde a cobra morreu | T13: framebuffer final | 1 célula vermelha em (0,31) | Vermelha em (0,31) | ✅ |
| I-07 | Dimensões e célula na tela | 512×512 px e células de 16×16 visíveis | Manual (§6, MAN-01) | Grade 32×32 ocupando o display | Usuário: a tela inteira aparece (MAN-01) | ✅ |
| I-08 | Renderização pelo Bitmap Display do MARS | O que o MARS desenha com a configuração correta | T16a: Unit 16, 512×512, conectado; jogo real com 'd'; após 3,2 s, desenhar o painel em PNG e analisar em blocos de 16×16 | Imagem de 512×512; 1 célula verde; células azuis na linha 0; todas as células com cor uniforme; pixels acesos = 256 × células | 512×512; azul em (0,6), verde em (29,13); 512 pixels = 2 × 256; 0 células mistas | ✅ |
| I-09 | Sintoma com Unit = 1 | Documentar a tela "preta" relatada | T16b: Unit 1 (padrão do MARS), 512×512, conectado | Nenhuma célula 16×16; quase nenhum pixel aceso | 16 de 262.144 pixels acesos; nenhuma célula 16×16 | ✅ |
| I-10 | Sintoma sem conexão | Documentar a tela preta | T16c: Unit 16, sem "Connect to MIPS" | 0 pixels acesos | 0 | ✅ |
| I-11 | Comida nova depois de comer | Conferir que a comida sorteada após comer aparece na tela (relato C-03) | T16d: `tests/probe_comer.asm` põe a comida em (0,2), anda 2× para a direita (come), e a rotina real `spawn_food` sorteia a nova comida. Unit 16, 512×512 | 2 células azuis (0,1)(0,2); 1 verde exatamente na posição de `food_idx` | Ex.: comida=290 → verde em (9,2). 0 células mistas | ✅ |
| I-12 | Sintoma com Display Height = 256 | Documentar a comida "sumida" | T16e: o mesmo cenário com altura 256 (padrão do MARS); repetido 5× à mão | Só as linhas 0–15 aparecem; comida na linha ≥ 16 fica invisível | Imagem 512×256. Comidas 594 (18,18), 994 (31,2) e 545 (17,1): **invisíveis**; 5 (0,5) e 24 (0,24): visíveis | ✅ |

## 5. Testes de mutação (eficácia da suíte)

Cada defeito foi injetado numa cópia de `src/snake.asm` e a suíte (ou o teste
relevante) foi executada contra ela. **Todos foram detectados.**

| Defeito injetado | Detectado por |
|---|---|
| Sem a exceção da cauda (D6) | `t_move` (6 falhas) |
| +4 por comida em vez de +5 | `t_move`, `t_collide` (5 falhas) |
| Sem bloqueio de inversão | `t_input` (3 falhas) |
| Parede com comparação com sinal | `t_collide` (5 falhas) |
| Cabeça da fila sem `& 1023` | `t_move` (6 falhas), T15 (código 2) |
| Cauda da fila sem `& 1023` | `t_move` (6 falhas) |
| Comida aceita sobre a cobra | `t_food`, `t_collide`, T15 (código 5) |
| Sorteio em 0..30 em vez de 0..31 | `t_food` (máscaras incompletas) |
| Tick de 400 ms | `t_input` (3 falhas) |
| Cauda não apagada (rastro) | T15 (código 8) |
| Ponto contado antes da checagem de colisão | T15 (código 11) |
| Sem ressincronização após pausa (código anterior à C-01) | `t_input` T06p (2 falhas) |
| Primeira versão do teste da fila (circuito 2×2) | **Não detectava** a falta da volta da fila. Substituído pelo circuito 2×3 (ver P-T1) |

(As linhas de 1 a 12 contam como 14 mutações porque "comida sobre a cobra" e
"cabeça sem `& 1023`" foram executadas duas vezes, contra a suíte inteira e
contra o T15.)

## 6. Testes manuais (MARS com interface gráfica)

Esses testes dependem de abrir o MARS, conectar as ferramentas e observar a
tela. Só podem ser executados pelo usuário; os resultados abaixo são relatos dele. Roteiro detalhado no `README.md`.

| ID | Nome | Procedimento | Resultado esperado | Resultado observado | Status |
|---|---|---|---|---|---|
| MAN-01 | Aparência inicial | Configurar o Bitmap Display (16/16/512/512/0x10010000), conectar as duas ferramentas, Assemble, Go | Fundo preto, quadrado azul de 16×16 no canto superior esquerdo, 1 quadrado verde; a cobra parada | 3ª execução pelo usuário (15/11), com 16/16/512/512: "a tela inteira aparece" | ✅ |
| MAN-02 | Teclado real | Clicar na caixa inferior do MMIO e pressionar D, S, A, W e as maiúsculas | A cobra muda de direção; a oposta é ignorada | Relatos do usuário: jogou com W, A, S, D; a cobra muda de direção, come e colide conforme o comando. Maiúsculas e a tecla oposta não foram relatadas à parte (cobertas por T05) | ✅ |
| MAN-03 | Ritmo visual | Observar 20 movimentos sem teclas | ~1 casa a cada 0,5 s (~10 s no total) | Usuário (15/11): "o ritmo acredito que esteja correto". Observação visual, **sem cronometragem**; a medição de tempo é do T06/T13 | ✅ (visual) |
| MAN-04 | Comer e crescer na tela | Guiar a cobra até 3 comidas | Cresce 1 casa por comida; comida reaparece fora do corpo; sem rastros | 3ª execução (15/11), com Display Height 512: "as comidas aparecem normalmente após comer" e a cobra cresce. Confirma a causa do C-03 | ✅ |
| MAN-05 | Game over na parede | Bater numa parede | Cabeça vermelha; relatório no Run I/O; diálogo com a mesma pontuação | Usuário (15/11): "ao colidir a cabeça fica vermelha e abre uma caixa de diálogo com a pontuação" | ✅ |
| MAN-06 | Game over no corpo | Com tamanho ≥ 5, virar sobre o corpo | Idem MAN-05, com motivo "proprio corpo" | Usuário (15/11): "ao colidir com o próprio corpo também perde" | ✅ |
| MAN-07 | Pause/Continue | Com a cobra andando, `Run → Pause` (F9), esperar ~5 s e continuar com `Run → Go` (F5) | A cobra anda **uma** casa e retoma o ritmo normal, sem salto | Usuário (15/11): "validei o jogo e todos os comportamentos estão ok, incluindo o pause e GO" | ✅ |
| MAN-08 | Ordem de conexão | Executar com o Bitmap Display conectado **antes** do Go | Tudo aparece. Se conectado depois, células já desenhadas não aparecem até serem reescritas (comportamento do MARS, ver README) | Ordem correta (conectar antes do Go) usada em todas as execuções aprovadas. A ordem inversa não foi relatada especificamente; o efeito está documentado como limitação do MARS | ✅ (ordem correta) |

## 7. Problemas encontrados e correções

| ID | Tipo | Problema | Causa | Correção | Reteste |
|---|---|---|---|---|---|
| **C-01** | **Defeito no jogo** | Após uma pausa de 5 s (Pause do MARS ou velocidade reduzida), a cobra fazia **11 movimentos e ganhava 11 pontos em 300 ms** | `wait_tick` sempre fazia `prazo += 500`. Com atraso maior que um tick, todos os prazos seguintes já estavam vencidos | Em `wait_tick`, se o atraso for ≥ 500 ms, o prazo vira "agora" (ressincroniza). Atrasos menores continuam compensados | T06p aprovado; o código antigo reprova o T06p (mutação); T06, T13 e a suíte completa aprovados |
| **C-02** | **Configuração / usabilidade** (relato do usuário) | Na 1ª execução manual, o jogo respondia às teclas e mostrava o game over e a pontuação, mas a **tela do Bitmap Display ficava preta** | Os campos Unit Width/Height ficaram em **1, o padrão do MARS** (confirmado no bytecode: índice 0 = "1"). Com isso, cada célula vira 1 pixel e o jogo ocupa 2 linhas de pixels. A documentação dizia "16", mas não alertava sobre o padrão. O jogo não tinha defeito | (1) O jogo imprime no console, ao iniciar, a configuração exigida com o alerta "o padrão do MARS é 1"; (2) seção "Problemas comuns" com imagens em `docs/configuracao-mars.md`; (3) teste T16 com a classe real do Bitmap Display | T16a/b/c aprovados: com Unit 16 o jogo aparece; com Unit 1 ou sem conexão, reproduz a tela preta. Suíte completa na época: 110/110. Na 2ª execução do usuário, a cobra apareceu (Unit corrigido) |
| **C-03** | **Configuração / usabilidade** (relato do usuário) | Na 2ª execução manual, a cobra e a 1ª comida apareciam; a cobra comia e crescia, mas **nenhuma comida nova aparecia** | **Não reproduzido com a configuração correta:** com 512×512, a nova comida aparece onde `food_idx` indica (T16d). **Reproduzido com Display Height = 256, o padrão do MARS** (bytecode: índice 2 = "256"): o display mostra só as linhas 0–15, e a comida sorteada nas linhas 16–31 fica fora da tela (T16e, 3 de 5 sorteios invisíveis). O aviso anterior destacava só Unit | (1) Mensagem inicial com "Display Height = 512 (ATENCAO: o padrao do MARS e 256)" e dica do sintoma; (2) linha nova em "Problemas comuns"; (3) T16d e T16e | T16d/e aprovados. Suíte: 112/112. **Confirmado pelo usuário:** com Display Height = 512, as comidas novas aparecem (MAN-04 ✅) |
| **C-04** | **Portabilidade dos comentários** (auditoria, 15/11) | `src/snake.asm` tinha 180 linhas com caracteres não ASCII (acentos e "—") nos comentários | O MARS 4.5 lê e grava o `.asm` com `FileReader`/`FileWriter` (codificação padrão do sistema; conferido no bytecode). Em Java < 18 no Windows (Cp1252), "direção" seria exibido como "direÃ§Ã£o", e salvar pelo editor do MARS poderia corromper o arquivo. Não reproduzido numa interface gráfica: análise do bytecode + conversão demonstrada com `iconv` | Comentários transliterados para ASCII (`iconv //TRANSLIT`); "Altera:" acrescentado nos cabeçalhos de `init_game`, `wait_first_key`, `wait_tick` e `step` | Código fora dos comentários idêntico (diff); `.text` montado idêntico byte a byte (dump do MARS antes/depois); 0 caracteres não ASCII; suíte 112/112 |
| P-T4 | Falha de teste | O primeiro T16b esperava ≤ 8 pixels acesos e obteve 16 | Com Unit 1, o display cobre 1 MB e também mostra `body`, variáveis e strings como pixels quase pretos | Critério: nenhuma célula 16×16 e < 100 pixels | Aprovado |
| P-T1 | Falha de teste | O teste da fila circular (circuito 2×2) não detectava a falta de `& 1023` | O período 4 divide 1024: as posições antigas da fila tinham por coincidência as mesmas células | Circuito 2×3 (período 6) e conferência do conteúdo da fila | A mutação passou a ser detectada |
| P-T2 | Falha de teste | O primeiro T06p contava 2 movimentos mesmo com o código corrigido | O laço dava mais um passo antes de checar o fim da janela | O tempo é conferido antes de cada passo | Aprovado com a correção; reprovado sem ela |
| P-T3 | Falha de teste | T15 abortava com "store address not aligned" | `inv_marks` (`.space`, no driver de teste) começava num endereço não alinhado | `.align 2` antes de `inv_marks` | Aprovado |
