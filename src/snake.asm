###############################################################################
#  PROJETO SNAKE -- Jogo da cobrinha em Assembly MIPS (simulador MARS 4.5)
#
#  Especificacao: doc/projeto_snake-especificacao.pdf
#
#  Resumo das regras (conforme a especificacao):
#    - Area quadrada de 512x512 pixels, celulas de 16x16 pixels (grade 32x32).
#    - A cobra comeca com tamanho 1 na celula (0,0), canto superior esquerdo.
#    - A comida aparece numa celula (I,J) sorteada aleatoriamente.
#    - A cada 0,5 s a cobra anda uma celula, repetindo a ultima direcao
#      se nenhuma tecla nova foi recebida. Teclas: W cima, A esquerda,
#      S baixo, D direita.
#    - Ao comer, a cobra cresce 1 celula e a comida reaparece em outro lugar.
#    - Bater numa parede ou no proprio corpo encerra o jogo; a pontuacao
#      e apresentada.
#    - Pontuacao: +1 a cada 0,5 s e +5 por comida coletada.
#
#  CONFIGURACAO DO MARS (antes de executar):
#    Settings > Memory Configuration: "Default"
#    Tools > Bitmap Display:
#        Unit Width = 16, Unit Height = 16,
#        Display Width = 512, Display Height = 512,
#        Base address = 0x10010000 (static data)   -> "Connect to MIPS"
#    Tools > Keyboard and Display MMIO Simulator    -> "Connect to MIPS"
#    Run > Assemble (F3) e Run > Go (F5). Digite W/A/S/D na caixa de texto
#    INFERIOR do Keyboard and Display MMIO Simulator.
#
#  ORGANIZACAO DO PROGRAMA
#    1. Constantes (.eqv) e macros
#    2. Dados (.data): framebuffer (1o item, em 0x10010000) e estado do jogo
#    3. Programa principal (main): inicializacao e laco do jogo
#    4. Sub-rotinas: init_game, clear_screen, draw_cell, get_cell,
#       spawn_food, read_input, wait_first_key, wait_tick, step, game_over
#
#  REPRESENTACAO
#    Cada celula da grade e identificada por um indice unico:
#        indice = linha * 32 + coluna      (0 .. 1023)
#    e ocupa uma word do framebuffer, no endereco:
#        0x10010000 + indice * 4
#    O framebuffer e tambem o tabuleiro logico: a cor guardada em cada word
#    indica o que ocupa a celula (fundo, cobra ou comida).
#
#    O corpo da cobra e uma FILA CIRCULAR ("body") de 1024 posicoes com os
#    indices das celulas, da cauda (tail_idx) ate a cabeca (head_idx).
#    A cada movimento entra uma cabeca nova; sem comida, a cauda sai.
#    Como a cobra nunca passa de 1024 celulas, a fila nunca transborda.
#
#  ENTRADA E SAIDA
#    Bitmap Display: o MARS pinta uma unidade de 16x16 px sempre que o
#    programa grava (sw) uma word dentro de frame; o valor gravado e a cor
#    0x00RRGGBB. A tela inteira so e limpa no inicio; a cada movimento sao
#    redesenhadas apenas a nova cabeca, a cauda apagada e, se a cobra comeu,
#    a nova comida.
#    Teclado: o Keyboard and Display MMIO Simulator e lido por polling
#    (0xFFFF0000 bit 0 = tecla pronta; 0xFFFF0004 = codigo ASCII), sem
#    bloquear o jogo. A syscall 12 nao e usada porque espera a tecla.
#    Console (Run I/O) e caixa de dialogo: so no inicio (instrucoes) e no
#    fim (resultado).
#
#  COMENTARIOS
#    Em portugues e SEM ACENTOS (arquivo 100% ASCII), de proposito: o MARS
#    le e grava o .asm com a codificacao padrao do sistema, e acentos em
#    UTF-8 apareceriam corrompidos em outras configuracoes (ex.: Windows).
#
#  CONVENCAO DE REGISTRADORES
#    $a0-$a3 argumentos, $v0-$v1 retorno, $t0-$t9 temporarios.
#    $s0-$s2 e $ra sao salvos na pilha pelas rotinas que os usam.
###############################################################################


###############################################################################
# 1. CONSTANTES
###############################################################################

# --- Grade -------------------------------------------------------------------
.eqv GRID            32      # celulas por linha e por coluna (512 px / 16 px)
.eqv GRID_SHIFT      5       # log2(32): linha = indice >> 5
.eqv GRID_MASK       31      # coluna = indice & 31
.eqv GRID_CELLS      1024    # total de celulas (32 * 32)
.eqv QUEUE_MASK      1023    # (posicao + 1) & 1023 da a volta na fila circular
.eqv START_CELL      0       # celula (0,0): posicao inicial da cobra

# --- Cores (formato 0x00RRGGBB do Bitmap Display) ----------------------------
.eqv COLOR_BG        0x00000000   # fundo: preto
.eqv COLOR_SNAKE     0x000070C0   # cobra: azul (como na figura do PDF)
.eqv COLOR_FOOD      0x0066A830   # comida: verde (como na figura do PDF)
.eqv COLOR_DEAD      0x00E02020   # cabeca no fim do jogo: vermelho

# --- Tempo e pontuacao -------------------------------------------------------
.eqv TICK_MS         500     # intervalo entre movimentos: 0,5 s
.eqv POINTS_PER_TICK 1       # +1 ponto a cada 0,5 s
.eqv POINTS_PER_FOOD 5       # +5 pontos por comida

# --- Teclado (Keyboard and Display MMIO Simulator) ---------------------------
.eqv MMIO_RCV_CTRL   0xFFFF0000   # controle do receptor: bit 0 = tecla pronta
.eqv MMIO_RCV_DATA   4            # deslocamento do dado do receptor (0xFFFF0004)
.eqv MMIO_READY_BIT  1            # mascara do bit "pronto"
.eqv CASE_BIT        0x20         # OR com 0x20 converte 'A'..'Z' em 'a'..'z'
.eqv KEY_W           0x77         # 'w'
.eqv KEY_A           0x61         # 'a'
.eqv KEY_S           0x73         # 's'
.eqv KEY_D           0x64         # 'd'

# --- Direcoes ----------------------------------------------------------------
# Numeradas no sentido horario, de modo que direcoes opostas
# diferem exatamente em 2 (cima/baixo = 1/3, direita/esquerda = 2/4).
.eqv DIR_NONE        0       # parada (antes da primeira tecla)
.eqv DIR_UP          1
.eqv DIR_RIGHT       2
.eqv DIR_DOWN        3
.eqv DIR_LEFT        4
.eqv DIR_OPPOSITE    2       # |nova - atual| == 2  =>  direcao oposta

# --- Resultado de um passo (retorno de step) ---------------------------------
.eqv STATUS_OK       0       # movimento normal, o jogo continua
.eqv STATUS_WALL     1       # colisao com a parede
.eqv STATUS_BODY     2       # colisao com o proprio corpo
.eqv STATUS_FULL     3       # a cobra ocupou a grade inteira

# --- Syscalls do MARS --------------------------------------------------------
.eqv SYS_PRINT_INT   1
.eqv SYS_PRINT_STR   4
.eqv SYS_EXIT        10
.eqv SYS_TIME        30      # $a0 = tempo do sistema em ms (32 bits baixos)
.eqv SYS_SET_SEED    40      # $a0 = id do gerador, $a1 = semente
.eqv SYS_RAND_RANGE  42      # $a0 = id, $a1 = limite -> $a0 em [0, limite)
.eqv SYS_MSG_INT     56      # caixa de dialogo: $a0 = mensagem, $a1 = inteiro
.eqv RNG_ID          0       # id do gerador de numeros aleatorios


###############################################################################
# MACROS DE SAIDA NO CONSOLE (Run I/O)
###############################################################################

# Imprime a string terminada em zero que esta no rotulo %label.
.macro PRINT_STR (%label)
    la   $a0, %label
    li   $v0, SYS_PRINT_STR
    syscall
.end_macro

# Imprime o inteiro contido no registrador %reg.
.macro PRINT_INT (%reg)
    move $a0, %reg
    li   $v0, SYS_PRINT_INT
    syscall
.end_macro


###############################################################################
# 2. DADOS
###############################################################################
.data

# FRAMEBUFFER DO BITMAP DISPLAY.
# OBRIGATORIAMENTE o primeiro item do .data, para ficar exatamente em
# 0x10010000 (endereco-base "static data" do Bitmap Display).
# 1024 celulas * 4 bytes = 4096 bytes. Uma word por celula de 16x16 px.
frame:      .space 4096

# FILA CIRCULAR COM O CORPO DA COBRA: 1024 words, cada uma com o indice
# (linha*32 + coluna) de uma celula ocupada pela cobra.
body:       .space 4096

head_idx:   .word 0          # posicao da cabeca dentro de body
tail_idx:   .word 0          # posicao da cauda dentro de body
length:     .word 1          # comprimento atual da cobra (em celulas)
food_idx:   .word 0          # indice da celula onde esta a comida
dir:        .word DIR_NONE   # direcao usada no ultimo movimento
next_dir:   .word DIR_NONE   # direcao pedida pelo teclado (vale no proximo tick)
score:      .word 0          # pontuacao
deadline:   .word 0          # instante (ms) em que termina o tick atual

# Deslocamento de linha e de coluna para cada direcao,
# indexado pelo codigo da direcao: NONE, UP, RIGHT, DOWN, LEFT.
dir_drow:   .word 0, -1, 0, 1, 0
dir_dcol:   .word 0, 0, 1, 0, -1

# Mensagens (sem acentos: o console do MARS nao exibe UTF-8 corretamente).
msg_title:  .asciiz "=== SNAKE - Assembly MIPS ===\n"
msg_cfg:    .asciiz "Tools > Bitmap Display deve estar configurado assim:\n   Unit Width in Pixels  = 16   (ATENCAO: o padrao do MARS e 1)\n   Unit Height in Pixels = 16   (ATENCAO: o padrao do MARS e 1)\n   Display Width in Pixels  = 512\n   Display Height in Pixels = 512   (ATENCAO: o padrao do MARS e 256)\n   Base address   = 0x10010000 (static data)\n   e conectado ('Connect to MIPS') ANTES de executar.\nTela preta: confira Unit. Comida ou cobra somem na metade de baixo:\nconfira Display Height. Depois corrija e execute de novo.\n\n"
msg_help:   .asciiz "Clique na caixa inferior do 'Keyboard and Display MMIO Simulator'\ne pressione W (cima), A (esquerda), S (baixo) ou D (direita) para comecar.\n"
msg_over:   .asciiz "\n========== GAME OVER ==========\n"
msg_reason: .asciiz "Motivo: "
msg_wall:   .asciiz "colisao com a parede\n"
msg_body:   .asciiz "colisao com o proprio corpo\n"
msg_full:   .asciiz "a cobra ocupou a grade inteira\n"
msg_len:    .asciiz "Comprimento final: "
msg_food:   .asciiz "Comidas coletadas: "
msg_ticks:  .asciiz "Movimentos (0,5 s cada): "
msg_score:  .asciiz "PONTUACAO FINAL: "
msg_nl:     .asciiz "\n"
msg_dialog: .asciiz "GAME OVER!\nPontuacao final: "

# Tabela com a mensagem de cada motivo de fim de jogo, indexada pelo STATUS.
reason_tbl: .word 0, msg_wall, msg_body, msg_full


###############################################################################
# 3. PROGRAMA PRINCIPAL
###############################################################################
.text

# ==== BEGIN MAIN ====
.globl main
main:
    PRINT_STR(msg_title)
    PRINT_STR(msg_cfg)              # configuracao exigida do Bitmap Display
    PRINT_STR(msg_help)

    jal  init_game            # tela limpa, cobra em (0,0), comida sorteada
    jal  wait_first_key       # parada ate a primeira tecla valida (decisao D1)

game_loop:
    jal  wait_tick            # espera 0,5 s lendo o teclado durante a espera
    jal  step                 # move a cobra e atualiza a pontuacao
    beq  $v0, STATUS_OK, game_loop

    move $a0, $v0             # qualquer outro status encerra o jogo
    jal  game_over            # mostra o resultado e termina (nao retorna)
# ==== END MAIN ====


###############################################################################
# 4. SUB-ROTINAS
###############################################################################
# ==== BEGIN ROUTINES ====

#------------------------------------------------------------------------------
# init_game -- prepara uma partida nova.
#   Limpa a tela, cria a cobra de tamanho 1 na celula (0,0), zera a
#   pontuacao, deixa a cobra parada, semeia o gerador aleatorio e
#   sorteia a primeira comida.
#   Entrada: nenhuma.   Saida: nenhuma.   Altera: $t0-$t2, $a0, $a1, $v0.
#------------------------------------------------------------------------------
init_game:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)

    jal   clear_screen

    # Fila com um unico segmento: cabeca e cauda na mesma posicao (0).
    sw    $zero, head_idx
    sw    $zero, tail_idx
    li    $t0, START_CELL
    sw    $t0, body                 # body[0] = celula (0,0)
    li    $t0, 1
    sw    $t0, length               # tamanho inicial = 1 (so a cabeca)

    li    $t0, DIR_NONE
    sw    $t0, dir                  # parada ate a primeira tecla
    sw    $t0, next_dir
    sw    $zero, score

    # Desenha a cabeca em (0,0).
    li    $a0, START_CELL
    li    $a1, COLOR_SNAKE
    jal   draw_cell

    # Semente do gerador aleatorio = hora atual em ms,
    # para que cada partida tenha comidas em posicoes diferentes.
    li    $v0, SYS_TIME
    syscall                         # $a0 = tempo em ms
    move  $a1, $a0
    li    $a0, RNG_ID
    li    $v0, SYS_SET_SEED
    syscall

    jal   spawn_food                # primeira comida em (I,J) aleatorio

    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

#------------------------------------------------------------------------------
# clear_screen -- pinta todas as 1024 celulas com a cor de fundo.
#   Entrada: nenhuma.   Saida: nenhuma.   Altera: $t0-$t2.
#------------------------------------------------------------------------------
clear_screen:
    li    $t0, 0                    # deslocamento em bytes dentro de frame
    li    $t1, COLOR_BG
    li    $t2, 4096                 # GRID_CELLS * 4 bytes
cs_loop:
    sw    $t1, frame($t0)
    addiu $t0, $t0, 4
    bne   $t0, $t2, cs_loop
    jr    $ra

#------------------------------------------------------------------------------
# draw_cell -- pinta uma celula da grade no Bitmap Display.
#   Entrada: $a0 = indice da celula (linha*32 + coluna), $a1 = cor.
#   Saida: nenhuma.   Altera: $t0.
#------------------------------------------------------------------------------
draw_cell:
    sll   $t0, $a0, 2               # cada celula ocupa 4 bytes
    sw    $a1, frame($t0)           # 0x10010000 + indice*4 <- cor
    jr    $ra

#------------------------------------------------------------------------------
# get_cell -- le a cor (o conteudo) de uma celula da grade.
#   Entrada: $a0 = indice da celula.
#   Saida: $v0 = cor (COLOR_BG, COLOR_SNAKE ou COLOR_FOOD).   Altera: $t0.
#------------------------------------------------------------------------------
get_cell:
    sll   $t0, $a0, 2
    lw    $v0, frame($t0)
    jr    $ra

#------------------------------------------------------------------------------
# spawn_food -- coloca a comida numa celula (I,J) aleatoria e livre.
#   Sorteia a linha I e a coluna J em [0, 31]. Se a celula estiver
#   ocupada pela cobra, sorteia de novo. Sempre existe celula livre,
#   porque o jogo termina quando a cobra ocupa a grade inteira.
#   Entrada: nenhuma.   Saida: food_idx atualizado e comida desenhada.
#   Altera: $t0-$t2, $a0, $a1, $v0.
#------------------------------------------------------------------------------
spawn_food:
sf_retry:
    li    $a0, RNG_ID
    li    $a1, GRID
    li    $v0, SYS_RAND_RANGE
    syscall                         # $a0 = I (linha) em [0, 31]
    move  $t0, $a0

    li    $a0, RNG_ID
    li    $a1, GRID
    li    $v0, SYS_RAND_RANGE
    syscall                         # $a0 = J (coluna) em [0, 31]

    sll   $t0, $t0, GRID_SHIFT      # indice = I*32 + J
    or    $t0, $t0, $a0

    sll   $t1, $t0, 2               # celula livre?
    lw    $t2, frame($t1)
    bne   $t2, COLOR_BG, sf_retry   # ocupada: sorteia outra posicao

    sw    $t0, food_idx
    li    $t2, COLOR_FOOD
    sw    $t2, frame($t1)           # desenha a comida
    jr    $ra

#------------------------------------------------------------------------------
# read_input -- le o teclado SEM BLOQUEAR (polling no MMIO).
#   Se houver tecla pronta e ela for W, A, S ou D (maiuscula ou minuscula),
#   grava a nova direcao em next_dir. Ela passa a valer no proximo tick.
#   Sem tecla, ou com outra tecla, nada muda: a cobra continua na
#   direcao anterior.
#   Uma tecla na direcao oposta a atual e ignorada (decisao D2), pois
#   faria a cabeca voltar sobre o corpo.
#   Entrada: nenhuma.   Saida: next_dir possivelmente atualizado.
#   Altera: $t0-$t5.
#------------------------------------------------------------------------------
read_input:
    li    $t0, MMIO_RCV_CTRL
    lw    $t1, 0($t0)               # registrador de controle do receptor
    andi  $t1, $t1, MMIO_READY_BIT
    beqz  $t1, ri_done              # nenhuma tecla: retorna imediatamente

    lw    $t2, MMIO_RCV_DATA($t0)   # le o ASCII (a leitura limpa o bit "pronto")
    ori   $t2, $t2, CASE_BIT        # 'W' -> 'w' etc.: aceita maiusculas

    # Converte a tecla num codigo de direcao ($t3).
    li    $t3, DIR_UP
    beq   $t2, KEY_W, ri_validate
    li    $t3, DIR_LEFT
    beq   $t2, KEY_A, ri_validate
    li    $t3, DIR_DOWN
    beq   $t2, KEY_S, ri_validate
    li    $t3, DIR_RIGHT
    beq   $t2, KEY_D, ri_validate
    j     ri_done                   # outra tecla: ignorada

ri_validate:
    # Compara com a direcao usada no ultimo movimento (dir), e nao com
    # next_dir. Assim, duas teclas rapidas no mesmo tick nao conseguem
    # fazer a cobra voltar sobre si mesma.
    lw    $t4, dir
    beq   $t4, DIR_NONE, ri_accept  # parada: qualquer direcao vale
    subu  $t5, $t3, $t4             # direcoes opostas diferem em +-2
    beq   $t5, DIR_OPPOSITE, ri_done
    beq   $t5, -DIR_OPPOSITE, ri_done
ri_accept:
    sw    $t3, next_dir
ri_done:
    jr    $ra

#------------------------------------------------------------------------------
# wait_first_key -- mantem a cobra parada ate a primeira tecla valida
#   (decisao D1). Depois inicia o relogio dos ticks de 0,5 s.
#   Entrada: nenhuma.   Saida: next_dir != DIR_NONE e deadline = agora.
#   Altera: $t0-$t5, $a0, $a1, $v0 ($a1 tambem e escrito pela syscall 30).
#------------------------------------------------------------------------------
wait_first_key:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
wfk_loop:
    jal   read_input
    lw    $t0, next_dir
    beq   $t0, DIR_NONE, wfk_loop   # ainda sem direcao: continua esperando

    li    $v0, SYS_TIME
    syscall
    sw    $a0, deadline             # referencia de tempo do primeiro tick

    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

#------------------------------------------------------------------------------
# wait_tick -- espera ate completar 0,5 s desde o tick anterior,
#   lendo o teclado o tempo todo (a espera nao bloqueia a entrada).
#   O prazo e somado ao anterior (deadline += 500), e nao medido a partir
#   de "agora", para que o tempo gasto no processamento nao se acumule.
#   Excecao: com atraso de 1 tick ou mais, o prazo e ressincronizado.
#   A diferenca (agora - prazo) e avaliada com sinal, o que continua
#   correto mesmo quando o contador de 32 bits da a volta.
#   Entrada: nenhuma.   Saida: nenhuma.
#   Altera: $t0-$t5, $a0, $a1, $v0 ($a1 tambem e escrito pela syscall 30).
#------------------------------------------------------------------------------
wait_tick:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)

    lw    $t0, deadline
    addiu $t0, $t0, TICK_MS
    sw    $t0, deadline             # novo prazo = prazo anterior + 500 ms
wt_loop:
    jal   read_input                # le o teclado enquanto espera
    li    $v0, SYS_TIME
    syscall                         # $a0 = agora (ms)
    lw    $t0, deadline
    subu  $t1, $a0, $t0
    bltz  $t1, wt_loop              # agora < prazo: continua esperando

    # $t1 = atraso em relacao ao prazo. Se for de 1 tick ou mais (execucao
    # pausada no MARS ou velocidade reduzida), os ticks perdidos NAO sao
    # recuperados: o prazo passa a ser "agora". Sem isso, a cobra andaria
    # varias casas de uma vez e ganharia pontos que nao correspondem a
    # intervalos de 0,5 s de jogo.
    blt   $t1, TICK_MS, wt_done
    sw    $a0, deadline             # ressincroniza com o relogio
wt_done:
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

#------------------------------------------------------------------------------
# step -- executa um movimento da cobra (um tick).
#   1. Aplica a direcao pedida (next_dir -> dir).
#   2. Calcula a nova posicao da cabeca.
#   3. Parede: se sair da grade, retorna STATUS_WALL.
#   4. Corpo: se a nova celula tiver cobra, retorna STATUS_BODY. Excecao:
#      a celula da cauda, que e desocupada neste mesmo movimento (D6).
#   5. Sem comida: remove a cauda (apaga a celula).
#      Com comida: a cauda fica, e a cobra cresce 1 celula.
#   6. Insere a nova cabeca na fila e a desenha.
#   7. Pontuacao: +1 pelo tick; +5 se comeu (e sorteia nova comida).
#   As verificacoes dos passos 3 e 4 acontecem ANTES de qualquer
#   alteracao. Assim, numa colisao, a tela e a fila mostram exatamente o
#   estado anterior ao movimento fatal.
#
#   Entrada: nenhuma.
#   Saida:   $v0 = STATUS_OK, STATUS_WALL, STATUS_BODY ou STATUS_FULL.
#   Usa:     $s0 = indice da nova cabeca, $s1 = conteudo da celula de
#            destino, $s2 = 1 se comeu ($s0-$s2 e $ra sao preservados).
#   Altera:  $t0-$t6, $a0, $a1, $v0.
#------------------------------------------------------------------------------
step:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0, 8($sp)
    sw    $s1, 4($sp)
    sw    $s2, 0($sp)

    # --- 1. Aplica a direcao pedida ----------------------------------------
    lw    $t0, next_dir
    sw    $t0, dir

    # --- 2. Nova posicao da cabeca -----------------------------------------
    lw    $t1, head_idx
    sll   $t1, $t1, 2
    lw    $t2, body($t1)            # indice da cabeca atual
    srl   $t3, $t2, GRID_SHIFT      # linha  = indice / 32
    andi  $t4, $t2, GRID_MASK       # coluna = indice % 32

    sll   $t0, $t0, 2               # direcao * 4: posicao nas tabelas
    lw    $t5, dir_drow($t0)
    lw    $t6, dir_dcol($t0)
    addu  $t3, $t3, $t5             # nova linha
    addu  $t4, $t4, $t6             # nova coluna

    # --- 3. Colisao com a parede -------------------------------------------
    # Uma comparacao sem sinal cobre os dois lados: -1 vira 0xFFFFFFFF,
    # que e >= 32, igual a qualquer valor que passe de 31.
    li    $v0, STATUS_WALL
    bgeu  $t3, GRID, step_return
    bgeu  $t4, GRID, step_return

    sll   $s0, $t3, GRID_SHIFT      # indice da nova cabeca = linha*32 + coluna
    or    $s0, $s0, $t4

    # --- 4. Colisao com o corpo --------------------------------------------
    move  $a0, $s0
    jal   get_cell
    move  $s1, $v0                  # conteudo da celula de destino
    bne   $s1, COLOR_SNAKE, step_move

    # A celula tem cobra. So e permitido entrar se for a cauda, que sai
    # neste mesmo movimento (nao ha comida la, entao a cauda vai andar).
    lw    $t1, tail_idx
    sll   $t1, $t1, 2
    lw    $t2, body($t1)            # indice da celula da cauda
    li    $v0, STATUS_BODY
    bne   $s0, $t2, step_return     # nao e a cauda: colisao com o corpo

step_move:
    # --- 5. Comeu? Se nao, remove a cauda ----------------------------------
    seq   $s2, $s1, COLOR_FOOD      # $s2 = 1 se a cabeca chegou na comida
    bnez  $s2, step_push_head       # comeu: a cauda fica (cresce 1 celula)

    lw    $t1, tail_idx
    sll   $t2, $t1, 2
    lw    $a0, body($t2)            # celula da cauda, que vai ser liberada
    addiu $t1, $t1, 1
    andi  $t1, $t1, QUEUE_MASK      # avanca a cauda na fila circular
    sw    $t1, tail_idx
    li    $a1, COLOR_BG
    jal   draw_cell                 # apaga a cauda da tela

step_push_head:
    # --- 6. Insere e desenha a nova cabeca ---------------------------------
    # Feito depois de apagar a cauda: se a cabeca entrar na celula que a
    # cauda acabou de liberar, a celula termina pintada como cobra.
    lw    $t1, head_idx
    addiu $t1, $t1, 1
    andi  $t1, $t1, QUEUE_MASK      # avanca a cabeca na fila circular
    sw    $t1, head_idx
    sll   $t1, $t1, 2
    sw    $s0, body($t1)            # body[head_idx] = nova cabeca
    move  $a0, $s0
    li    $a1, COLOR_SNAKE
    jal   draw_cell

    # --- 7. Pontuacao ------------------------------------------------------
    lw    $t0, score
    addiu $t0, $t0, POINTS_PER_TICK # +1 pelo tick de 0,5 s
    sw    $t0, score

    li    $v0, STATUS_OK
    beqz  $s2, step_return          # nao comeu: fim do passo

    addiu $t0, $t0, POINTS_PER_FOOD # +5 pela comida
    sw    $t0, score
    lw    $t1, length
    addiu $t1, $t1, 1               # cresceu uma celula
    sw    $t1, length

    li    $v0, STATUS_FULL          # grade cheia: nao ha onde por comida (D8)
    beq   $t1, GRID_CELLS, step_return

    jal   spawn_food                # nova comida em posicao livre
    li    $v0, STATUS_OK

step_return:
    lw    $s2, 0($sp)
    lw    $s1, 4($sp)
    lw    $s0, 8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra

#------------------------------------------------------------------------------
# game_over -- mostra o estado final e a pontuacao e encerra o programa.
#   No Bitmap Display, o tabuleiro final fica visivel e a cabeca e pintada
#   de vermelho (exceto quando a grade foi completada).
#   No console (Run I/O): motivo, comprimento, comidas, movimentos e
#   pontuacao. Tambem abre uma caixa de dialogo com a pontuacao.
#   Entrada: $a0 = status que encerrou o jogo (STATUS_WALL/BODY/FULL).
#   Saida: nao retorna (syscall 10).
#   Usa: $s0 = status, $s1 = comprimento e depois comidas, $s2 = pontuacao
#        (sem salvar na pilha, pois a rotina nunca retorna).
#------------------------------------------------------------------------------
game_over:
    move  $s0, $a0                  # nao retorna, entao nao precisa salvar $s0

    # Marca a cabeca em vermelho para indicar onde a cobra morreu.
    beq   $s0, STATUS_FULL, go_report
    lw    $t1, head_idx
    sll   $t1, $t1, 2
    lw    $a0, body($t1)
    li    $a1, COLOR_DEAD
    jal   draw_cell

go_report:
    PRINT_STR(msg_over)

    # Motivo: reason_tbl[status].
    PRINT_STR(msg_reason)
    sll   $t0, $s0, 2
    lw    $a0, reason_tbl($t0)
    li    $v0, SYS_PRINT_STR
    syscall

    # Comprimento final.
    PRINT_STR(msg_len)
    lw    $s1, length
    PRINT_INT($s1)
    PRINT_STR(msg_nl)

    # Comidas coletadas = comprimento - 1 (cada comida aumentou 1 celula).
    PRINT_STR(msg_food)
    addiu $s1, $s1, -1
    PRINT_INT($s1)
    PRINT_STR(msg_nl)

    # Movimentos = pontuacao - 5 * comidas (cada movimento valeu 1 ponto).
    PRINT_STR(msg_ticks)
    lw    $s2, score
    li    $t0, POINTS_PER_FOOD
    mul   $t0, $t0, $s1
    subu  $t0, $s2, $t0
    PRINT_INT($t0)
    PRINT_STR(msg_nl)

    # Pontuacao final.
    PRINT_STR(msg_score)
    PRINT_INT($s2)
    PRINT_STR(msg_nl)

    # Caixa de dialogo com a pontuacao.
    la    $a0, msg_dialog
    move  $a1, $s2
    li    $v0, SYS_MSG_INT
    syscall

    li    $v0, SYS_EXIT
    syscall

# ==== END ROUTINES ====
