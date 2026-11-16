# Manual de execução — Projeto Snake

Passo a passo para executar e jogar no MARS 4.5. Os detalhes de cada
configuração e a solução de problemas estão em
[`configuracao-mars.md`](configuracao-mars.md).

## 1. Preparar (uma vez)

```bash
sudo pacman -S jre-openjdk            # Java, se ainda não houver (java -version)
cd snake-project
curl -L -o tools/Mars4_5.jar https://dpetersanderson.github.io/Mars4_5.jar
sha256sum tools/Mars4_5.jar           # ac340b67...7096 (hash completo em configuracao-mars.md)
```

## 2. Executar (a cada partida)

1. Abra o MARS: `java -jar tools/Mars4_5.jar`.
2. `File → Open ...` → `src/snake.asm`.
3. `Tools → Bitmap Display`:
   - Unit Width in Pixels = **16**
   - Unit Height in Pixels = **16**
   - Display Width in Pixels = **512**
   - Display Height in Pixels = **512**
   - Base address for display = **0x10010000 (static data)**
   - clique em **Connect to MIPS**.
4. `Tools → Keyboard and Display MMIO Simulator` → **Connect to MIPS**.
5. `Run → Assemble` (F3) e `Run → Go` (F5).
6. O console *Run I/O* mostra o título, a configuração exigida e as instruções.
   No Bitmap Display aparecem um quadrado azul (a cobra) no canto superior
   esquerdo e um verde (a comida).
7. Clique na área **inferior** do MMIO Simulator ("KEYBOARD") e pressione
   **W**, **A**, **S** ou **D**. A cobra começa a andar.

## 3. Jogar

| Tecla | Direção |
|---|---|
| W | cima |
| A | esquerda |
| S | baixo |
| D | direita |

- A cobra anda uma célula a cada 0,5 s e mantém a última direção enquanto
  nenhuma tecla nova é pressionada.
- A tecla na direção oposta à do movimento é ignorada.
- Comer (passar a cabeça pela comida verde): a cobra cresce uma célula e outra
  comida aparece numa posição livre.
- **Pontuação:** +1 a cada movimento (0,5 s) e +5 por comida.

## 4. Fim de jogo

A partida termina quando a cabeça bate numa parede (sai da grade) ou no
próprio corpo. Então:

- **Bitmap Display:** o tabuleiro final fica na tela, com a cabeça em vermelho.
- **Console *Run I/O*:**
  - motivo;
  - comprimento final;
  - comidas coletadas;
  - movimentos;
  - **PONTUACAO FINAL**.
- **Caixa de diálogo:** "GAME OVER! Pontuacao final: N". Clique em OK para
  encerrar.

Para jogar de novo: `Run → Reset` (F12) e `Run → Go` (F5). As ferramentas
continuam conectadas.

## 5. Pausar

`Run → Pause` (F9) congela o jogo; `Run → Go` (F5) continua. Ao continuar, a
cobra anda uma casa e retoma o ritmo normal, sem saltos. Depois, clique de novo
na área "KEYBOARD" para voltar a usar as teclas.

## 6. Se algo der errado

| Sintoma | Verifique |
|---|---|
| Tela preta, mas o jogo responde | Unit Width/Height = 16 |
| Comida ou cobra somem na metade de baixo | Display Height = 512 |
| Nada aparece | Bitmap Display conectado **antes** do Go |
| A cobra não reage | Foco na área "KEYBOARD" e MMIO conectado |

Tabela completa, com imagens de referência: [`configuracao-mars.md` §6](configuracao-mars.md#6-problemas-comuns).

## 7. Testes automáticos (opcional)

```bash
tools/run_tests.sh    # MARS sem interface; resultado esperado: "TODOS OS TESTES PASSARAM"
```

O teste T16 (renderização) precisa de `javac` e de uma sessão gráfica (`DISPLAY`).
Sem eles, o T16 é pulado com aviso. Relatório completo: [`testes.md`](testes.md).
