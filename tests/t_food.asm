###############################################################################
# t_food.asm — T04: geração aleatória da comida.
#   a) 2000 sorteios em tabuleiro vazio: índice em 0..1023, nunca sobre a
#      cobra, e todas as 32 linhas e 32 colunas aparecem (I e J cobrem 0..31).
#   b) Metade superior ocupada pela cobra: 1000 sorteios, nunca sobre ela.
#   c) Só uma célula livre: a comida vai exatamente para ela.
###############################################################################
.data
n_range: .asciiz "T04 2000 sorteios: indice sempre em 0..1023"
n_nosn:  .asciiz "T04 2000 sorteios: nunca sobre a cobra em (0,0)"
n_rows:  .asciiz "T04 todas as linhas I = 0..31 sorteadas (mascara de bits)"
n_cols:  .asciiz "T04 todas as colunas J = 0..31 sorteadas (mascara de bits)"
n_drawn: .asciiz "T04 2000 sorteios: celula sorteada pintada de verde"
n_half:  .asciiz "T04 metade ocupada: 1000 sorteios, nenhum sobre a cobra"
n_one:   .asciiz "T04 uma unica celula livre (777): comida vai para ela"
.text
.globl main
main:
    # ---- a) tabuleiro vazio ------------------------------------------------
    jal   init_game
    li    $s0, 2000                 # repetições
    li    $s1, 0                    # erros de faixa
    li    $s2, 0                    # máscara de linhas sorteadas
    li    $s3, 0                    # máscara de colunas sorteadas
    li    $s4, 0                    # sorteios sobre a cobra
    li    $s5, 0                    # célula sorteada sem a cor de comida
fa_loop:
    jal   remove_food
    jal   spawn_food
    lw    $t0, food_idx
    sltiu $t1, $t0, 1024
    bnez  $t1, fa_inrange
    addiu $s1, $s1, 1
fa_inrange:
    bnez  $t0, fa_notsnake
    addiu $s4, $s4, 1
fa_notsnake:
    srl   $t1, $t0, GRID_SHIFT      # linha
    andi  $t2, $t0, GRID_MASK       # coluna
    li    $t3, 1
    sllv  $t4, $t3, $t1
    or    $s2, $s2, $t4
    sllv  $t4, $t3, $t2
    or    $s3, $s3, $t4
    move  $a0, $t0
    jal   get_cell
    beq   $v0, COLOR_FOOD, fa_drawn
    addiu $s5, $s5, 1
fa_drawn:
    addiu $s0, $s0, -1
    bnez  $s0, fa_loop
    CHECK($s1, 0, n_range)
    CHECK($s4, 0, n_nosn)
    CHECK($s2, 0xFFFFFFFF, n_rows)
    CHECK($s3, 0xFFFFFFFF, n_cols)
    CHECK($s5, 0, n_drawn)

    # ---- b) células 0..511 ocupadas pela cobra ------------------------------
    jal   clear_screen
    li    $s0, 0
fb_fill:
    move  $a0, $s0
    li    $a1, COLOR_SNAKE
    jal   draw_cell
    addiu $s0, $s0, 1
    blt   $s0, 512, fb_fill
    jal   spawn_food
    li    $s0, 1000
    li    $s1, 0
fb_loop:
    jal   remove_food
    jal   spawn_food
    lw    $t0, food_idx
    bge   $t0, 512, fb_ok
    addiu $s1, $s1, 1
fb_ok:
    addiu $s0, $s0, -1
    bnez  $s0, fb_loop
    CHECK($s1, 0, n_half)

    # ---- c) apenas a célula 777 livre ---------------------------------------
    li    $s0, 0
fc_fill:
    move  $a0, $s0
    li    $a1, COLOR_SNAKE
    jal   draw_cell
    addiu $s0, $s0, 1
    blt   $s0, 1024, fc_fill
    li    $a0, 777
    li    $a1, COLOR_BG
    jal   draw_cell
    jal   spawn_food
    lw    $t0, food_idx
    CHECK($t0, 777, n_one)

    jal   finish_tests
