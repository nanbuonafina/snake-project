# Configuração do MARS

Versão usada e verificada: **MARS 4.5** (`Mars4_5.jar`). Os nomes de menus,
campos e botões abaixo foram conferidos no próprio `Mars4_5.jar` e usados pelo
usuário numa execução completa do jogo (15/11/2026).

## 1. Obter e abrir o MARS no Arch Linux

Requisito: Java (JRE ≥ 8). No Arch: `sudo pacman -S jre-openjdk`. Confira com
`java -version`; o projeto foi testado com OpenJDK 21.

Escolha **uma** opção:

| Opção | Comando | Observação |
|---|---|---|
| A. Jar local no projeto (recomendada) | `curl -L -o tools/Mars4_5.jar https://dpetersanderson.github.io/Mars4_5.jar` | Não instala nada no sistema. O jar não é versionado (`.gitignore`) |
| B. Pacote AUR | `yay -S mars-mips` (ou `mars-mips-bin`) | Instala no sistema e cria o comando `mars-mips` |

SHA-256 do jar oficial 4.5:
`ac340b676ba2b62246b9df77e62f81ad4447bcfd329ab539716bcd09950b7096`

```bash
sha256sum tools/Mars4_5.jar                     # conferir o hash
java -jar tools/Mars4_5.jar                     # abrir a interface gráfica
java -jar tools/Mars4_5.jar nc a src/snake.asm  # só montar (sem interface)
```

**Wayland/GNOME/HiDPI:** o MARS (Java Swing) roda via XWayland. Se a janela
aparecer em branco ou muito pequena:

```bash
_JAVA_AWT_WM_NONREPARENTING=1 java -jar tools/Mars4_5.jar
java -Dsun.java2d.uiScale=2 -jar tools/Mars4_5.jar
```

## 2. Memória

`Settings → Memory Configuration...` → selecione **Default** → **Apply and Close**.

Default já é a configuração inicial do MARS. Com ela, o `.data` começa em
`0x10010000`, onde fica o framebuffer do jogo.

## 3. Bitmap Display (saída)

Menu `Tools → Bitmap Display`. Ajuste os cinco campos:

| Campo na janela | Valor | Padrão do MARS |
|---|---|---|
| Unit Width in Pixels | **16** | 1 (**altere**) |
| Unit Height in Pixels | **16** | 1 (**altere**) |
| Display Width in Pixels | **512** | 512 |
| Display Height in Pixels | **512** | 256 (**altere**) |
| Base address for display | **0x10010000 (static data)** | 0x10010000 (static data) |

Depois clique em **Connect to MIPS**. O botão passa a mostrar
**Disconnect from MIPS**.

- **Resultado:** a área de desenho fica quadrada (512×512). Cada word de
  memória vira uma célula de 16×16 px, numa grade de 32×32 células.
- **Os campos não são salvos.** Toda vez que a ferramenta é aberta, eles voltam
  ao padrão. Confira-os sempre antes de executar.
- O jogo também imprime essa configuração no console *Run I/O* ao iniciar.

## 4. Teclado (entrada W, A, S, D)

Menu `Tools → Keyboard and Display MMIO Simulator` → **Connect to MIPS**.

A janela tem duas áreas de texto:

| Área | Título na janela | Uso no jogo |
|---|---|---|
| Superior | `DISPLAY: Store to Transmitter Data ...` | Não usada |
| **Inferior** | `KEYBOARD: Characters typed here are stored to Receiver Data ...` | **Digite W, A, S, D aqui** |

- Clique na área **inferior** antes de jogar: ela precisa estar com o foco. Teclas
  digitadas em outra janela não chegam ao programa.
- Maiúsculas e minúsculas funcionam (decisão D3).
- **Registradores lidos pelo jogo:**
  - controle do receptor `0xFFFF0000`: bit 0 = 1 quando há tecla;
  - dado do receptor `0xFFFF0004`: código ASCII.
  - A leitura do dado zera o bit "pronto", conforme a ajuda da própria ferramenta.

## 5. Execução

1. `File → Open ...` → `src/snake.asm`.
2. Configure e conecte as duas ferramentas (§3 e §4) **antes** de executar.
3. `Run → Assemble` (**F3**).
4. `Run → Go` (**F5**).
5. Clique na área inferior do MMIO Simulator e pressione W, A, S ou D. A cobra
   começa a andar na primeira tecla válida.
6. Deixe o controle **Run speed** no máximo: "Run speed at max (no
   interaction)", que é o padrão.

| Ação | Menu | Atalho |
|---|---|---|
| Montar | `Run → Assemble` | F3 |
| Executar / continuar após pausa | `Run → Go` | F5 |
| Pausar | `Run → Pause` | F9 |
| Parar | `Run → Stop` | F11 |
| Reiniciar (jogar de novo) | `Run → Reset` | F12 |

- **Jogar de novo:** `Run → Reset` (ou Assemble), depois Go. As ferramentas
  continuam conectadas.
- **Pausa:** ao continuar, a cobra anda uma casa e retoma o ritmo de 0,5 s, sem
  saltos.

## 6. Problemas comuns

| Sintoma | Causa | Solução |
|---|---|---|
| O jogo responde às teclas e mostra o game over e a pontuação, mas **a tela fica preta** | **Unit Width/Height em 1** (padrão). Cada célula vira 1 pixel, e o jogo inteiro ocupa as 2 primeiras linhas de pixels | Unit Width = Unit Height = **16**, depois Reset e Go |
| A cobra e a 1ª comida aparecem, mas **depois de comer nenhuma comida nova aparece** (ou a cobra some ao descer) | **Display Height em 256** (padrão). Só as linhas 0–15 aparecem | Display Height = **512**, depois Reset e Go. A área deve ser quadrada |
| Tela totalmente preta, sem nenhum ponto | Bitmap Display não conectado (o botão ainda diz "Connect to MIPS") | Clicar em **Connect to MIPS** e executar de novo |
| Só parte do jogo aparece (por exemplo, a comida inicial) | Display conectado ou reconfigurado **depois** do Go. O MARS só desenha o que é escrito após a conexão | Configurar e conectar antes; depois Reset e Go |
| A cobra não reage às teclas | Teclas digitadas fora da área inferior do MMIO Simulator, ou MMIO não conectado | Clicar na área "KEYBOARD" e conectar |

Como a tela deve ficar. As imagens foram geradas pela classe real do Bitmap
Display do MARS, com o jogo em execução, pelo teste T16:

| Configuração correta (Unit 16) | Unit = 1 (padrão): parece preta | Ampliação 4× das 4 linhas de cima com Unit = 1 |
|---|---|---|
| ![correto](img/bitmap-correto.png) | ![unit 1](img/bitmap-unit1.png) | ![zoom](img/bitmap-unit1-zoom.png) |
