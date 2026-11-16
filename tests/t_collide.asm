###############################################################################
# t_collide.asm — T09/T10/T12: colisões com as paredes e com o corpo.
#   Também verifica que a colisão não altera o estado (D7) e o fim por
#   grade cheia (D8).
###############################################################################
.data
n_up:     .asciiz "T09 (0,0) indo p/ cima: STATUS_WALL"
n_up_sc:  .asciiz "T09/D7 colisao nao soma ponto (score = 0)"
n_up_c:   .asciiz "T09 apos colisao a cabeca continua desenhada em (0,0)"
n_up_h:   .asciiz "T09 apos colisao a fila nao mudou (head_idx = 0)"
n_left:   .asciiz "T09 (0,0) indo p/ esquerda: STATUS_WALL"
n_r31:    .asciiz "T09 31 passos p/ direita ate (0,31): todos OK"
n_right:  .asciiz "T09 (0,31) indo p/ direita: STATUS_WALL"
n_r_sc:   .asciiz "T09/D7 score = 31 (o tick da colisao nao conta)"
n_d31:    .asciiz "T09 31 passos p/ baixo ate (31,0): todos OK"
n_down:   .asciiz "T09 (31,0) indo p/ baixo: STATUS_WALL"
n_len5:   .asciiz "T10 cobra montada com comprimento 5"
n_body:   .asciiz "T10 cabeca entra no corpo: STATUS_BODY"
n_b_len:  .asciiz "T10 apos colisao: comprimento continua 5"
n_b_sc:   .asciiz "T10/T12 score = 4 comidas*6 + 2 ticks = 26 (sem ponto da colisao)"
n_b_tail: .asciiz "T10 apos colisao: cauda (0,2) continua desenhada"
n_b_cnt:  .asciiz "T10 apos colisao: exatamente 5 celulas de cobra"
n_full:   .asciiz "D8 comer a ultima celula livre: STATUS_FULL"
.text
.globl main
main:
    # ---- Parede de cima ----------------------------------------------------
    jal   init_game
    jal   remove_food
    li    $a0, DIR_UP
    jal   move_dir
    CHECK($v0, STATUS_WALL, n_up)
    CHECK_VAR(score, 0, n_up_sc)
    li    $a0, 0
    jal   get_cell
    CHECK($v0, COLOR_SNAKE, n_up_c)
    CHECK_VAR(head_idx, 0, n_up_h)

    # ---- Parede da esquerda ------------------------------------------------
    jal   init_game
    jal   remove_food
    li    $a0, DIR_LEFT
    jal   move_dir
    CHECK($v0, STATUS_WALL, n_left)

    # ---- Parede da direita -------------------------------------------------
    jal   init_game
    jal   remove_food
    li    $s0, 31
    li    $s1, 0
r_loop:
    li    $a0, DIR_RIGHT
    jal   move_dir
    or    $s1, $s1, $v0
    addiu $s0, $s0, -1
    bnez  $s0, r_loop
    CHECK($s1, 0, n_r31)
    li    $a0, DIR_RIGHT
    jal   move_dir
    CHECK($v0, STATUS_WALL, n_right)
    CHECK_VAR(score, 31, n_r_sc)

    # ---- Parede de baixo ---------------------------------------------------
    jal   init_game
    jal   remove_food
    li    $s0, 31
    li    $s1, 0
d_loop:
    li    $a0, DIR_DOWN
    jal   move_dir
    or    $s1, $s1, $v0
    addiu $s0, $s0, -1
    bnez  $s0, d_loop
    CHECK($s1, 0, n_d31)
    li    $a0, DIR_DOWN
    jal   move_dir
    CHECK($v0, STATUS_WALL, n_down)

    # ---- Corpo: cobra 0..4 na linha 0; desce, vai p/ esquerda e sobe ------
    jal   init_game
    jal   remove_food
    li    $s0, 1
grow_loop:
    li    $a0, DIR_RIGHT
    move  $a1, $s0
    jal   eat_at
    addiu $s0, $s0, 1
    ble   $s0, 4, grow_loop
    CHECK_VAR(length, 5, n_len5)
    li    $a0, DIR_DOWN             # cabeça (1,4); cobra = 1,2,3,4,36
    jal   move_dir
    li    $a0, DIR_LEFT             # cabeça (1,3); cobra = 2,3,4,36,35
    jal   move_dir
    li    $a0, DIR_UP               # (0,3) é corpo (não é a cauda, que é (0,2))
    jal   move_dir
    CHECK($v0, STATUS_BODY, n_body)
    CHECK_VAR(length, 5, n_b_len)
    CHECK_VAR(score, 26, n_b_sc)
    li    $a0, 2
    jal   get_cell
    CHECK($v0, COLOR_SNAKE, n_b_tail)
    li    $a0, COLOR_SNAKE
    jal   count_color
    CHECK($v0, 5, n_b_cnt)

    # ---- D8: força comprimento 1023 e come -> grade cheia -----------------
    jal   init_game
    jal   remove_food
    li    $t0, 1023                 # GRID_CELLS - 1 (estado artificial)
    sw    $t0, length
    li    $a0, 1
    jal   place_food
    li    $a0, DIR_RIGHT
    jal   move_dir
    CHECK($v0, STATUS_FULL, n_full)

    jal   finish_tests
