###############################################################################
# estado inicial (cobra de tamanho 1 em (0,0), comida, score).
###############################################################################
.data
n_len:   .asciiz "T03 comprimento inicial = 1"
n_head:  .asciiz "T03 head_idx = 0"
n_tail:  .asciiz "T03 tail_idx = 0"
n_body:  .asciiz "T03 body[0] = celula (0,0)"
n_dir:   .asciiz "T03 dir = parada (D1)"
n_next:  .asciiz "T03 next_dir = parada (D1)"
n_score: .asciiz "T03 pontuacao inicial = 0"
n_c0:    .asciiz "T03 celula (0,0) pintada com a cor da cobra"
n_nsn:   .asciiz "T03 exatamente 1 celula de cobra na tela"
n_nfd:   .asciiz "T03 exatamente 1 celula de comida na tela"
n_fpos:  .asciiz "T03 food_idx aponta para a celula de comida"
n_nbg:   .asciiz "T03 demais 1022 celulas com a cor de fundo"
.text
.globl main
main:
    jal   init_game
    CHECK_VAR(length, 1, n_len)
    CHECK_VAR(head_idx, 0, n_head)
    CHECK_VAR(tail_idx, 0, n_tail)
    CHECK_VAR(body, START_CELL, n_body)
    CHECK_VAR(dir, DIR_NONE, n_dir)
    CHECK_VAR(next_dir, DIR_NONE, n_next)
    CHECK_VAR(score, 0, n_score)

    li    $a0, 0
    jal   get_cell
    CHECK($v0, COLOR_SNAKE, n_c0)

    li    $a0, COLOR_SNAKE
    jal   count_color
    CHECK($v0, 1, n_nsn)
    li    $a0, COLOR_FOOD
    jal   count_color
    CHECK($v0, 1, n_nfd)
    lw    $a0, food_idx
    jal   get_cell
    CHECK($v0, COLOR_FOOD, n_fpos)
    li    $a0, COLOR_BG
    jal   count_color
    CHECK($v0, 1022, n_nbg)

    jal   finish_tests
