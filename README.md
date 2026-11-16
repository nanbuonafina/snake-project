# Projeto Snake — Assembly MIPS (MARS)

Jogo da cobrinha (*Snake*) escrito inteiramente em **Assembly MIPS** para o
simulador **MARS 4.5**. A saída é o **Bitmap Display** e a entrada são as teclas
**W, A, S, D**.

- **Arquivo entregue:** [`src/snake.asm`](src/snake.asm).
- **Integrantes do grupo:** Maria Fernanda, Juliana Maria, Vitor Fernandes, Vinicius  Silva, Lucas.

## Descrição

O jogador controla uma cobra que anda pela tela coletando comida. Cada comida
faz a cauda crescer uma célula. A cobra não pode bater nas paredes que cercam
a área nem no próprio corpo.

**Objetivo:** chegar à maior cobra possível e, com isso, à maior pontuação.

## Tecnologias

| Item | Uso |
|---|---|
| Assembly MIPS | Toda a lógica do jogo (`src/snake.asm`) |
| MARS 4.5 | Simulador: montagem, execução e syscalls |
| Bitmap Display (ferramenta do MARS) | Saída gráfica: escrita direta na memória a partir de `0x10010000` |
| Keyboard and Display MMIO Simulator (ferramenta do MARS) | Entrada W, A, S, D lida por *polling* em `0xFFFF0000`/`0xFFFF0004` |
| Bash e Java (apenas em `tools/`) | Executar os testes automáticos. **Não contêm lógica do jogo** |

## Requisitos do ambiente

- Java (JRE 8 ou superior). Testado com OpenJDK 21 no Arch Linux.
- MARS 4.5 (`Mars4_5.jar`).
- Para os testes automáticos (opcional): Bash; e `javac` com sessão gráfica
  apenas para o teste T16.

## Estrutura de diretórios

```
snake-project/
├── README.md                 este arquivo
├── doc/
│   └── projeto_snake-especificacao.pdf   especificação oficial (não editada)
├── src/
│   └── snake.asm             código-fonte do jogo (único arquivo entregue)
├── docs/
│   ├── manual-execucao.md    passo a passo para executar e jogar
│   ├── configuracao-mars.md  configuração detalhada do MARS e problemas comuns
│   ├── arquitetura.md        estruturas de dados, algoritmo e decisões de projeto
├── tests/                    testes automáticos escritos em Assembly MIPS
│   ├── lib/test_lib.asm
│   ├── t_*.asm               um arquivo por grupo de testes
│   ├── e2e_prologue.asm      teste de ponta a ponta
│   └── probe_comer.asm       cenário do teste de renderização T16d/e
└── tools/
    ├── run_tests.sh          executa todos os testes no MARS sem interface
    └── BitmapProbe.java      observa a renderização do Bitmap Display (T16)
```

O `Mars4_5.jar` fica em `tools/`, mas não é versionado (ver §"Como executar").

## Como executar no Arch Linux

```bash
sudo pacman -S jre-openjdk                 # se ainda não houver Java
curl -L -o tools/Mars4_5.jar https://dpetersanderson.github.io/Mars4_5.jar
java -jar tools/Mars4_5.jar                # abre o MARS
```

No MARS:

1. `File → Open ...` → `src/snake.asm`.
2. Configure e conecte o **Bitmap Display** (próxima seção).
3. `Tools → Keyboard and Display MMIO Simulator` → **Connect to MIPS**.
4. `Run → Assemble` (F3) → `Run → Go` (F5).
5. Clique na área **inferior** do MMIO Simulator ("KEYBOARD") e pressione
   W, A, S ou D.

Passo a passo completo: [`docs/manual-execucao.md`](docs/manual-execucao.md).
Configuração detalhada: [`docs/configuracao-mars.md`](docs/configuracao-mars.md).

## Configuração do Bitmap Display

Menu `Tools → Bitmap Display`:

| Campo | Valor | Atenção |
|---|---|---|
| Unit Width in Pixels | **16** | o padrão é 1 (tela parece preta) |
| Unit Height in Pixels | **16** | o padrão é 1 (tela parece preta) |
| Display Width in Pixels | **512** | |
| Display Height in Pixels | **512** | o padrão é 256 (a metade de baixo não aparece) |
| Base address for display | **0x10010000 (static data)** | |

Depois clique em **Connect to MIPS**, sempre **antes** do Go. Os campos voltam ao
padrão cada vez que a ferramenta é aberta. O jogo lembra essa configuração no
console ao iniciar.

## Controles

| Tecla | Direção |
|---|---|
| `W` | cima |
| `A` | esquerda |
| `S` | baixo |
| `D` | direita |

Maiúsculas e minúsculas funcionam. As teclas devem ser digitadas na área
"KEYBOARD" do Keyboard and Display MMIO Simulator. Pausar: `Run → Pause` (F9);
continuar: `Run → Go` (F5).

## Regras de funcionamento

- Área quadrada de 512×512 px, dividida em células de 16×16 px (grade 32×32).
- A cobra começa com tamanho 1 na célula (0,0), no canto superior esquerdo.
- A comida ocupa 1 célula, numa posição (I,J) sorteada, nunca sobre a cobra.
- A cada 0,5 s a cobra anda uma célula. Sem tecla nova, repete a última direção.
- Ao comer, a cobra cresce uma célula na cauda e a comida é recolocada numa
  nova posição livre.

**Decisões de projeto** (o PDF não define; detalhes em
[`docs/arquitetura.md`](docs/arquitetura.md) §8):
- a cobra espera parada até a primeira tecla, e só então o tempo e a pontuação contam;
- a tecla na direção oposta à atual é ignorada;
- a cabeça pode entrar na célula que a cauda está deixando;
- se a cobra ocupar a grade inteira, o jogo termina.

## Sistema de pontuação

| Evento | Pontos |
|---|---|
| Cada movimento (a cada 0,5 s) | **+1** |
| Cada comida coletada | **+5** |

O movimento que causa a colisão não soma ponto. Portanto, pontuação final =
movimentos + 5 × comidas.

## Encerramento do jogo

O jogo termina quando a cabeça **bate numa parede** ou **no próprio corpo**:

- **Bitmap Display:** o tabuleiro final permanece, com a cabeça em **vermelho**.
- **Console *Run I/O*:** motivo, comprimento final, comidas coletadas,
  movimentos e **PONTUACAO FINAL**.
- **Caixa de diálogo:** "GAME OVER! Pontuacao final: N".

Para jogar de novo: `Run → Reset` (F12) e `Run → Go` (F5).

## Testes

```bash
tools/run_tests.sh
```

- **Automáticos:** **112 verificações aprovadas, 0 falhas** (última execução:
  15/11/2026). Rodam no MARS sem interface; os testes são escritos em Assembly
  MIPS e chamam as rotinas do próprio `src/snake.asm`. Incluem:
  - estado inicial, entrada, movimento, crescimento, comida e colisões;
  - pontuação e temporização com relógio real;
  - um teste de ponta a ponta com o `main` real;
  - 4000 passos de um jogador automático com 13 invariantes;
  - renderização pela classe do próprio Bitmap Display do MARS (T16).
- **Mutação:** 14 execuções com defeitos introduzidos de propósito; todos
  detectados.
- **Manuais no MARS com interface:** imagem, teclado, ritmo, comida, colisões,
  diálogo e Pause/Go. Executados e aprovados pelo usuário em 15/11/2026.

Relatório completo: [`docs/testes.md`](docs/testes.md).

## Limitações conhecidas

- O Bitmap Display **precisa ser configurado à mão** a cada abertura. Os padrões
  do MARS (Unit 1, Height 256) deixam a tela preta ou cortada. O programa não tem
  como ler essa configuração.
- O Bitmap Display deve ser conectado **antes** do Go: o MARS só desenha o que
  for escrito depois da conexão.
- As teclas só chegam ao jogo quando digitadas na área "KEYBOARD" do MMIO
  Simulator, com foco.
- O jogo lê uma tecla por vez. Se várias forem pressionadas no mesmo intervalo
  de 0,5 s, vale a última válida.
- O tempo vem do relógio do sistema (syscall 30). Depois de uma pausa, o jogo
  retoma o ritmo sem "recuperar" os movimentos perdidos.
- A velocidade é fixa (0,5 s por movimento); não há níveis.
- Os comentários do `.asm` estão em português **sem acentos**, de propósito: o
  MARS lê o arquivo com a codificação do sistema, e acentos poderiam aparecer
  corrompidos em outras máquinas.

## Documentação

- [Manual de execução](docs/manual-execucao.md)
- [Configuração do MARS](docs/configuracao-mars.md)
- [Arquitetura](docs/arquitetura.md)
- [Relatório de testes](docs/testes.md)
