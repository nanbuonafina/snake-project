###############################################################################
# movimento, crescimento, fila circular e pontuação.
###############################################################################
.data
n_mid:    .asciiz "T07 10 x direita + 10 x baixo: cabeca em (10,10)"
n_dl:     .asciiz "T07 esquerda: (10,10) -> (10,9)"
n_du:     .asciiz "T07 cima:     (10,9)  -> (9,9)"
n_dr:     .asciiz "T07 direita:  (9,9)   -> (9,10)"
n_dd:     .asciiz "T07 baixo:    (9,10)  -> (10,10)"
n_st5:    .asciiz "T07 5 passos p/ direita: todos com STATUS_OK"
n_h5:     .asciiz "T07 cabeca em (0,5)"
n_len1:   .asciiz "T07 comprimento continua 1 (sem comida)"
n_old:    .asciiz "T07 celula (0,0) apagada (cauda removida)"
n_nsn1:   .asciiz "T07 exatamente 1 celula de cobra na tela"
n_sc5:    .asciiz "T12 5 ticks = 5 pontos"
n_eat:    .asciiz "T08 comer: STATUS_OK"
n_len2:   .asciiz "T08 comer: comprimento 1 -> 2"
n_sc6:    .asciiz "T12 1 tick + 1 comida = 1 + 5 = 6 pontos"
n_tail:   .asciiz "T08 comer: cauda (0,0) permanece (cresce na cauda)"
n_nfood:  .asciiz "T08 comer: nova comida na tela (exatamente 1)"
n_fpos:   .asciiz "T08 comer: nova comida fora da cobra"
n_len6:   .asciiz "T08 apos 5 comidas: comprimento 6"
n_sc30:   .asciiz "T12 5 ticks + 5 comidas = 30 pontos"
n_cyc:    .asciiz "T07/D6 2004 passos em circulo 2x3 (cabeca entra na celula que a cauda libera): todos OK"
n_len6b:  .asciiz "T07 apos 2004 passos: comprimento 6"
n_nsn6:   .asciiz "T07 apos 2004 passos: exatamente 6 celulas de cobra"
n_sc2034: .asciiz "T12 2009 ticks + 5 comidas = 2034 pontos"
n_hidx:   .asciiz "T07 fila circular: head_idx = 2009 mod 1024 = 985"
n_tidx:   .asciiz "T07 fila circular: tail_idx = 2004 mod 1024 = 980"
n_q0:     .asciiz "T07 fila[980] = (0,0) (cauda)"
n_q1:     .asciiz "T07 fila[981] = (0,1)"
n_q2:     .asciiz "T07 fila[982] = (0,2)"
n_q3:     .asciiz "T07 fila[983] = (1,2)"
n_q4:     .asciiz "T07 fila[984] = (1,1)"
n_q5:     .asciiz "T07 fila[985] = (1,0) (cabeca)"
.text
.globl main
main:
    # ---- As 4 direções a partir do meio da grade ---------------------------
    jal   init_game
    jal   remove_food
    li    $s0, 10
dm_r:
    li    $a0, DIR_RIGHT
    jal   move_dir
    addiu $s0, $s0, -1
    bnez  $s0, dm_r
    li    $s0, 10
dm_d:
    li    $a0, DIR_DOWN
    jal   move_dir
    addiu $s0, $s0, -1
    bnez  $s0, dm_d
    jal   head_cell
    CHECK($v0, 330, n_mid)          # 10*32 + 10
    li    $a0, DIR_LEFT
    jal   move_dir
    jal   head_cell
    CHECK($v0, 329, n_dl)
    li    $a0, DIR_UP
    jal   move_dir
    jal   head_cell
    CHECK($v0, 297, n_du)
    li    $a0, DIR_RIGHT
    jal   move_dir
    jal   head_cell
    CHECK($v0, 298, n_dr)
    li    $a0, DIR_DOWN
    jal   move_dir
    jal   head_cell
    CHECK($v0, 330, n_dd)

    # ---- Movimento simples --------------------------------------------------
    jal   init_game
    jal   remove_food
    li    $s0, 5
    li    $s1, 0                    # passos com status diferente de OK
mv_loop:
    li    $a0, DIR_RIGHT
    jal   move_dir
    beqz  $v0, mv_ok
    addiu $s1, $s1, 1
mv_ok:
    addiu $s0, $s0, -1
    bnez  $s0, mv_loop
    CHECK($s1, 0, n_st5)
    lw    $t0, head_idx
    sll   $t0, $t0, 2
    lw    $t1, body($t0)
    CHECK($t1, 5, n_h5)
    CHECK_VAR(length, 1, n_len1)
    li    $a0, 0
    jal   get_cell
    CHECK($v0, COLOR_BG, n_old)
    li    $a0, COLOR_SNAKE
    jal   count_color
    CHECK($v0, 1, n_nsn1)
    CHECK_VAR(score, 5, n_sc5)

    # ---- Comer: comida em (0,1) ---------------------------------------------
    jal   init_game
    jal   remove_food
    li    $a0, 1
    jal   place_food
    li    $a0, DIR_RIGHT
    jal   move_dir
    CHECK($v0, STATUS_OK, n_eat)
    CHECK_VAR(length, 2, n_len2)
    CHECK_VAR(score, 6, n_sc6)
    li    $a0, 0
    jal   get_cell
    CHECK($v0, COLOR_SNAKE, n_tail)
    li    $a0, COLOR_FOOD
    jal   count_color
    CHECK($v0, 1, n_nfood)
    lw    $a0, food_idx
    jal   get_cell
    CHECK($v0, COLOR_FOOD, n_fpos)
    jal   remove_food

    # ---- Cresce até 6 ocupando o retângulo 2x3 (0,0)-(1,2) -----------------
    # Cobra atual: (0,0),(0,1). Come em (0,2), (1,2), (1,1), (1,0).
    li    $a0, DIR_RIGHT
    li    $a1, 2                    # (0,2)
    jal   eat_at
    li    $a0, DIR_DOWN
    li    $a1, 34                   # (1,2)
    jal   eat_at
    li    $a0, DIR_LEFT
    li    $a1, 33                   # (1,1)
    jal   eat_at
    li    $a0, DIR_LEFT
    li    $a1, 32                   # (1,0)
    jal   eat_at
    CHECK_VAR(length, 6, n_len6)
    CHECK_VAR(score, 30, n_sc30)

    # ---- 2004 passos em círculo pelo retângulo 2x3: a cada passo a cabeça
    #      entra na célula que a cauda acaba de liberar (decisão D6).
    #      O período (6) NÃO divide 1024, então posições antigas da fila
    #      não coincidem com as novas: um erro na volta da fila circular
    #      aparece nas verificações abaixo.
    li    $s0, 334                  # 334 voltas de 6 passos = 2004 passos
    li    $s1, 0
cyc_loop:
    li    $a0, DIR_UP
    jal   move_dir
    or    $s1, $s1, $v0
    li    $a0, DIR_RIGHT
    jal   move_dir
    or    $s1, $s1, $v0
    li    $a0, DIR_RIGHT
    jal   move_dir
    or    $s1, $s1, $v0
    li    $a0, DIR_DOWN
    jal   move_dir
    or    $s1, $s1, $v0
    li    $a0, DIR_LEFT
    jal   move_dir
    or    $s1, $s1, $v0
    li    $a0, DIR_LEFT
    jal   move_dir
    or    $s1, $s1, $v0
    addiu $s0, $s0, -1
    bnez  $s0, cyc_loop
    CHECK($s1, 0, n_cyc)
    CHECK_VAR(length, 6, n_len6b)
    li    $a0, COLOR_SNAKE
    jal   count_color
    CHECK($v0, 6, n_nsn6)
    CHECK_VAR(score, 2034, n_sc2034)
    CHECK_VAR(head_idx, 985, n_hidx)
    CHECK_VAR(tail_idx, 980, n_tidx)

    # Conteúdo da fila, da cauda à cabeça: (0,0),(0,1),(0,2),(1,2),(1,1),(1,0).
    li    $t0, 980
    sll   $t0, $t0, 2
    lw    $s2, body($t0)
    CHECK($s2, 0, n_q0)
    lw    $s2, body+4($t0)
    CHECK($s2, 1, n_q1)
    lw    $s2, body+8($t0)
    CHECK($s2, 2, n_q2)
    lw    $s2, body+12($t0)
    CHECK($s2, 34, n_q3)
    lw    $s2, body+16($t0)
    CHECK($s2, 33, n_q4)
    lw    $s2, body+20($t0)
    CHECK($s2, 32, n_q5)

    jal   finish_tests
