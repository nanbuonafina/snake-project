# Arquitetura — Projeto Snake (Assembly MIPS / MARS)

> **Status: implementado e validado.** `src/snake.asm` passa nas verificações
> automáticas (15/11/2026). Atualize este documento junto com o código.

## 1. Visão geral

Um único arquivo `src/snake.asm` contém o laço principal do jogo e as
sub-rotinas. Entrada pelo MMIO do teclado (polling), saída pelo Bitmap Display
(escrita direta em memória) e pontuação final no console e em diálogo.

```
main
 ├─ init_game        limpa a tela, cria a cobra em (0,0), score = 0,
 │                   semente aleatória, spawn_food
 ├─ wait_first_key   cobra parada até a 1ª tecla válida (D1); inicia o relógio
 └─ game_loop:
      wait_tick      espera 500 ms; durante a espera chama read_input
      step           move ou cresce, soma pontos, detecta colisão
                     → $v0 = STATUS_OK | STATUS_WALL | STATUS_BODY | STATUS_FULL
      se STATUS_OK: volta ao game_loop
 game_over(status)   cabeça em vermelho, relatório no console,
                     diálogo com a pontuação, syscall 10

Auxiliares (recebem o índice da célula, linha*32 + coluna):
            draw_cell(índice, cor)    get_cell(índice) → cor
            clear_screen   spawn_food   read_input
```

## 2. Mapa de memória e estruturas de dados

| Rótulo | Tamanho | Função |
|---|---|---|
| `frame` | 4096 B (1024 words) | **Framebuffer em 0x10010000**, obrigatoriamente o 1º item do `.data`. 1 word = 1 célula. |
| `body` | 4096 B (1024 words) | Fila circular com o índice de cada célula da cobra (`lin*32 + col`). |
| `head_idx`, `tail_idx` | word | Posições da cabeça e da cauda em `body`. |
| `length` | word | Tamanho atual da cobra. |
| `dir`, `next_dir` | word | Direção aplicada no último movimento e direção pedida pelo teclado. |
| `score` | word | Pontuação. |
| `food_idx` | word | Índice da célula da comida. |
| `deadline` | word | Instante (ms) em que termina o tick atual. |
| `dir_drow`, `dir_dcol` | 5 words cada | Deslocamento de linha e coluna por direção. |
| `reason_tbl` | 4 words | Mensagem de cada motivo de fim de jogo. |
| `msg_*` | `.asciiz` | Mensagens do console. |

Endereço de uma célula: `0x10010000 + (lin * 32 + col) * 4`.

O framebuffer também é o **tabuleiro lógico**: a cor de cada word diz o que
ocupa a célula (fundo, cobra ou comida). Assim a colisão e a checagem de
comida custam um `lw`, e não há uma segunda matriz que possa ficar
dessincronizada da tela.

## 3. Entrada (teclado)

- Keyboard and Display MMIO Simulator, lido por **polling**:
  `0xFFFF0000` bit 0 indica tecla disponível; `0xFFFF0004` traz o ASCII.
- `w/W` → cima, `a/A` → esquerda, `s/S` → baixo, `d/D` → direita. Outras
  teclas são ignoradas.
- A tecla só grava `next_dir`. Em `step`, `dir ← next_dir`. Sem tecla nova, a
  direção se mantém (repete o comando anterior).
- A syscall 12 não é usada porque bloqueia o jogo esperando a tecla.
- Códigos de direção no sentido horário (UP=1, RIGHT=2, DOWN=3, LEFT=4).
  Direções opostas diferem em ±2, o que simplifica a regra D2. A tecla é
  comparada com `dir` (a direção já aplicada), e não com `next_dir`: duas
  teclas rápidas no mesmo tick não conseguem inverter a cobra.

## 4. Saída (Bitmap Display)

- Unit 16×16, display 512×512, base 0x10010000 (static data). O MARS pinta a
  unidade de 16×16 px correspondente sempre que o programa grava uma word em
  `frame`; o valor é a cor `0x00RRGGBB`.
- A tela inteira é limpa só no início. A cada tick só mudam a nova cabeça, a
  cauda removida e a comida.

## 5. Temporização (500 ms)

- `deadline ← deadline + 500` e, enquanto a syscall 30 (tempo em ms) for menor
  que `deadline`, `read_input` é chamada.
- Somar ao prazo anterior evita que o atraso de processamento se acumule. Ler o
  teclado durante a espera garante que nenhuma tecla se perca.
- **Ressincronização:** se, ao fim da espera, o atraso for de 1 tick (500 ms)
  ou mais, o prazo passa a ser "agora". Esse atraso acontece com o Pause do
  MARS ou com a velocidade reduzida. Sem a ressincronização, os ticks perdidos
  seriam executados de uma vez (a cobra saltaria várias casas e ganharia
  pontos indevidos). Defeito encontrado e corrigido na revisão de testes:
  `docs/testes.md`, C-01.

## 6. Algoritmo de um tick (`step`)

1. `dir ← next_dir`. Nova cabeça = (lin + dl, col + dc).
2. Fora de 0..31 → **colisão com a parede** (`STATUS_WALL`). Uma comparação
   sem sinal (`bgeu`) cobre −1 e 32 de uma vez.
3. `cor ← get_cell(nova cabeça)`.
4. Se `cor == SNAKE` e a célula **não** for a cauda → **colisão com o corpo**
   (`STATUS_BODY`). Se for a cauda, o movimento é permitido, porque a cauda
   sai neste mesmo tick (D6).
5. `comeu ← (cor == FOOD)`. Se não comeu: remove a cauda da fila e apaga a
   célula.
6. Coloca a nova cabeça na fila e a desenha. Isso vem depois do passo 5, para
   que a célula liberada pela cauda termine pintada como cobra.
7. `score += 1`. Se comeu: `score += 5`, `length += 1`; com a grade cheia,
   `STATUS_FULL`; senão, `spawn_food`.

As verificações (passos 2 a 4) acontecem **antes** de qualquer alteração.
Numa colisão, a fila, o comprimento, a pontuação e a tela ficam exatamente
como estavam antes do movimento fatal.

Fila circular: `head_idx` e `tail_idx` avançam com `(i + 1) & 1023`. O
comprimento nunca passa de 1024 (D8), então a fila nunca transborda e nenhum
segmento se perde.

`spawn_food`: sorteia I e J com a syscall 42 (0 a 31), calcula o índice
I*32 + J e sorteia de novo enquanto a célula não estiver com a cor de fundo.
A semente vem do relógio (syscall 40 com o tempo da syscall 30), então cada
partida é diferente.

## 7. Pontuação

`score += 1` a cada tick concluído (0,5 s) e `score += 5` por comida.

Estado final, em `game_over`:
- **Bitmap Display:** o tabuleiro final continua visível, com a cabeça em
  vermelho.
- **Console Run I/O:** motivo, comprimento final, comidas coletadas,
  movimentos (ticks de 0,5 s) e pontuação final. Os movimentos são
  calculados como pontuação − 5 × comidas.
- **Diálogo** (syscall 56): "GAME OVER! Pontuação final: N".

## 8. Decisões de projeto (não especificadas no PDF)

| ID | Decisão | Justificativa |
|---|---|---|
| D1 | A cobra fica parada até a primeira tecla válida; tempo e pontuação começam no primeiro comando | O PDF não define direção inicial. Começar em (0,0) indo para cima ou para a esquerda bateria na parede no primeiro tick. |
| D2 | Tecla na direção oposta (180°) é ignorada | Evita uma autocolisão instantânea com tamanho ≥ 2. |
| D3 | Aceita maiúsculas e minúsculas | Funciona mesmo com Caps Lock ligado. |
| D4 | Pontuação no console e em diálogo | O diálogo fica mais visível na apresentação. |
| D5 | Cobra azul (0x0070C0), comida verde (0x66A830), fundo preto; cabeça vermelha (0xE02020) no fim do jogo | Segue a figura do PDF; o vermelho mostra onde a cobra morreu. |
| D6 | A cabeça pode entrar na célula que a cauda libera no mesmo tick | Comportamento clássico, resultado da ordem dos passos 4 e 5. |
| D7 | O tick com colisão não soma ponto de tempo | O movimento não foi concluído. |
| D8 | Grade cheia (1024 células) encerra o jogo | Evita um laço infinito em `spawn_food`. |
| D9 | Unit 16×16 no Bitmap Display (em vez de 1×1 com 256 escritas por célula) | Mais simples e mais rápido, e atende igualmente a "célula 16×16 px". |
| D10 | Entrega em arquivo único | O PDF pede "o código fonte .ASM"; evita depender de configuração de vários arquivos no MARS. |

## 9. Testes

Execute `tools/run_tests.sh`, que roda o MARS sem interface gráfica. Para cada
`tests/t_*.asm`, o script monta um arquivo com: `src/snake.asm` sem o bloco
entre `# ==== BEGIN MAIN ====` e `# ==== END MAIN ====`, mais
`tests/lib/test_lib.asm` e o driver. Os drivers são escritos em MIPS e chamam
as mesmas rotinas do jogo. As teclas são simuladas escrevendo nos
registradores do receptor MMIO.

| ID | Arquivo | Verifica |
|---|---|---|
| T00 | script | `snake.asm` monta sem erros nem avisos; o jogo completo roda 300 mil instruções sem erro |
| T01/T02 | `t_grid.asm` | `frame` em 0x10010000; endereços dos 4 cantos; `draw_cell`/`get_cell`; `clear_screen` |
| T03 | `t_init.asm` | Estado inicial: tamanho 1 em (0,0), parada, score 0, 1 comida, resto em fundo |
| T04 | `t_food.asm` | 2000 sorteios em 0..1023, nunca sobre a cobra, todas as linhas e colunas 0..31 alcançadas; tabuleiro meio cheio; única célula livre |
| T05/T06 | `t_input.asm` | WASD, maiúsculas, tecla inválida, sem tecla, inversão ignorada, repetição da direção, `wait_first_key`; 1 tick entre 500 e 600 ms; 4 ticks entre 2000 e 2100 ms |
| T07/T08/T12 | `t_move.asm` | Movimento, crescimento na cauda, nova comida, pontuação; 2004 passos num circuito 2×3 com a cabeça entrando na célula da cauda (D6) e a fila dando a volta, com o conteúdo conferido |
| T09/T10/D7/D8 | `t_collide.asm` | 4 paredes, colisão com o corpo, estado inalterado e sem ponto no tick fatal, grade cheia |
| T13 | script + `e2e_prologue.asm` | Ponta a ponta: `main` real com a tecla 'd' simulada; parede após 31 movimentos; pontuação = movimentos + 5 × comidas; ~16 s de duração real |
| T06p | `t_input.asm` | Após uma pausa de 5 s: só 1 tick vence de imediato e o ritmo de 500 ms volta |
| T14 | script | Jogo real sem tecla: parado em (0,0), pontuação 0 (memória inspecionada) |
| T16 | `tools/BitmapProbe.java` | Renderização com a classe real `mars.tools.BitmapDisplay`, sem janela: com Unit 16 a cobra e a comida aparecem como células uniformes de 16×16; com Unit 1 ou sem conexão, a tela fica preta; a comida sorteada depois de comer aparece onde `food_idx` indica (T16d); com altura 256 a metade de baixo some (T16e) |
| T15 | `t_invariants.asm` | 4000 passos de um jogador automático (teclas pelo `read_input` real), com 13 invariantes checadas após cada passo: fila, adjacência, ausência de repetição, tela = fila (sem rastros), 1 comida, pontuação exata, estado intacto após colisão |

T13 também confere o framebuffer final (cabeça vermelha em (0,31), corpo
contíguo, nenhuma outra cor), lido da memória ao fim da execução.

**Eficácia dos testes (mutação):** 14 defeitos injetados de propósito, todos
detectados. A lista completa está em `docs/testes.md` §5.

**Manuais** (MARS com interface, `docs/testes.md` §6): tela inteira, teclado
real, ritmo, comer e crescer, colisão com parede e corpo, cabeça vermelha,
diálogo e Pause/Go. Executados e aprovados pelo usuário em 15/11/2026.

Relatório completo dos testes (procedimento, esperado, observado, status): `docs/testes.md`.
