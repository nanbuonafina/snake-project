###############################################################################
# teste de propriedades (memória, algoritmo e tela).
#
# um "jogador automático" escrito em MIPS joga milhares de passos:
#   - normalmente vai na direção da comida, evitando paredes e o corpo;
#   - em 1 de cada 16 passos aperta uma tecla aleatória (W/A/S/D), o que
#     provoca colisões com a parede e com o corpo.
# as teclas passam pela rotina real read_input (press_key), então a regra de
# inversão (D2) vale como no jogo. após uma colisão, uma partida nova começa.
#
# Após CADA passo, check_inv verifica:
#   1  1 <= length <= 1024
#   2  (head_idx - tail_idx) mod 1024 == length - 1
#   3  head_idx e tail_idx dentro de 0..1023
#   4  toda célula da fila está em 0..1023 (sem acesso fora da grade)
#   5  toda célula da fila está pintada com a cor da cobra
#   6  segmentos consecutivos são adjacentes (distância de Manhattan 1)
#   7  nenhuma célula aparece duas vezes na fila
#   8  células azuis na tela == length (sem rastros nem segmentos perdidos)
#   9  exatamente 1 comida na tela, na posição food_idx
#  10  as demais células têm a cor de fundo (nenhuma outra cor)
#  11  pontuação == ticks + 5 * comidas (contados pelo próprio teste)
#  20  colisão não altera o comprimento
#  21  status inesperado (STATUS_FULL não pode ocorrer aqui)
###############################################################################
.data
            .align 2                       # inv_marks é limpo com sw
inv_marks:  .space 1024                    # 1 byte por célula (detecção de repetição)
keytab:     .byte 0, 'w', 'd', 's', 'a'    # tecla de cada código de direção
ck_r:       .word 0                        # linha da cabeça
ck_c:       .word 0                        # coluna da cabeça
ck_fr:      .word 0                        # linha da comida
ck_fc:      .word 0                        # coluna da comida
cur_status: .word 0
err_step:   .word 0                        # passo restante quando ocorreu o 1º erro
n_inv:   .asciiz "T15 invariantes verificadas apos cada passo (codigo do 1o erro; 0 = nenhum)"
n_maxl:  .asciiz "T15 cobra chegou a comprimento >= 20 (varias celulas exercitadas)"
n_wall:  .asciiz "T15 houve colisoes com parede (>= 1)"
n_body:  .asciiz "T15 houve colisoes com o corpo (>= 1)"
s_stats: .asciiz "  info   passos=4000  partidas="
s_maxl:  .asciiz "  comprimento max="
s_food:  .asciiz "  comidas="
s_wall:  .asciiz "  paredes="
s_body:  .asciiz "  corpo="
s_nl:    .asciiz "\n"
.text
.globl main
main:
    li    $s0, 4000                 # passos a executar
    li    $s3, 0                    # maior comprimento observado
    li    $s4, 0                    # código do 1º erro
    li    $s5, 0                    # colisões com parede
    li    $s6, 0                    # colisões com corpo
    li    $s7, 0                    # comidas coletadas (todas as partidas)
    sw    $zero, cur_status         # usado como contador de partidas abaixo
    li    $t0, 0
    sw    $t0, err_step
    move  $fp, $zero                # partidas jogadas
new_game:
    addiu $fp, $fp, 1
    jal   init_game
    li    $s1, 0                    # pontuação esperada nesta partida
    move  $a0, $s1
    jal   check_inv
    jal   record_err
play:
    beqz  $s0, done
    addiu $s0, $s0, -1
    jal   choose_key
    move  $a0, $v0
    jal   press_key                 # passa pela rotina real read_input
    lw    $s2, length               # comprimento antes do passo
    jal   step
    sw    $v0, cur_status
    bnez  $v0, collided

    addiu $s1, $s1, POINTS_PER_TICK # +1 pelo tick
    lw    $t0, length
    beq   $t0, $s2, no_eat
    addiu $s1, $s1, POINTS_PER_FOOD # +5 pela comida
    addiu $s7, $s7, 1
no_eat:
    ble   $t0, $s3, no_max
    move  $s3, $t0
no_max:
    move  $a0, $s1
    jal   check_inv
    jal   record_err
    j     play

collided:
    lw    $t0, cur_status
    bne   $t0, STATUS_WALL, c_body
    addiu $s5, $s5, 1
    j     c_check
c_body:
    li    $v0, 21
    bne   $t0, STATUS_BODY, c_err
    addiu $s6, $s6, 1
c_check:
    lw    $t0, length
    li    $v0, 20
    bne   $t0, $s2, c_err           # colisão não pode mudar o comprimento
    move  $a0, $s1                  # nem a pontuação (D7) nem a tela
    jal   check_inv
c_err:
    jal   record_err
    j     new_game

done:
    CHECK($s4, 0, n_inv)
    sge   $t0, $s3, 20
    CHECK($t0, 1, n_maxl)
    sgt   $t0, $s5, 0
    CHECK($t0, 1, n_wall)
    sgt   $t0, $s6, 0
    CHECK($t0, 1, n_body)
    la    $a0, s_stats
    li    $v0, 4
    syscall
    move  $a0, $fp
    li    $v0, 1
    syscall
    la    $a0, s_maxl
    li    $v0, 4
    syscall
    move  $a0, $s3
    li    $v0, 1
    syscall
    la    $a0, s_food
    li    $v0, 4
    syscall
    move  $a0, $s7
    li    $v0, 1
    syscall
    la    $a0, s_wall
    li    $v0, 4
    syscall
    move  $a0, $s5
    li    $v0, 1
    syscall
    la    $a0, s_body
    li    $v0, 4
    syscall
    move  $a0, $s6
    li    $v0, 1
    syscall
    la    $a0, s_nl
    li    $v0, 4
    syscall
    jal   finish_tests

#------------------------------------------------------------------------------
# record_err — guarda em $s4 o primeiro código de erro ($v0 != 0).
#------------------------------------------------------------------------------
record_err:
    beqz  $v0, re_done
    bnez  $s4, re_done
    move  $s4, $v0
    sw    $s0, err_step
re_done:
    jr    $ra

#------------------------------------------------------------------------------
# choose_key — escolhe a próxima tecla ($v0 = ASCII).
#------------------------------------------------------------------------------
choose_key:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    li    $a0, 1                    # gerador 1 (independente do da comida)
    li    $a1, 16
    li    $v0, SYS_RAND_RANGE
    syscall
    bnez  $a0, ck_greedy
    li    $a0, 1                    # 1 em 16: direção aleatória 1..4
    li    $a1, 4
    li    $v0, SYS_RAND_RANGE
    syscall
    addiu $a0, $a0, 1
    j     ck_ret
ck_greedy:
    lw    $t0, head_idx
    sll   $t0, $t0, 2
    lw    $t1, body($t0)
    srl   $t2, $t1, GRID_SHIFT
    sw    $t2, ck_r
    andi  $t2, $t1, GRID_MASK
    sw    $t2, ck_c
    lw    $t1, food_idx
    srl   $t2, $t1, GRID_SHIFT
    sw    $t2, ck_fr
    andi  $t2, $t1, GRID_MASK
    sw    $t2, ck_fc
    # Direções que aproximam da comida, se forem seguras.
    lw    $t0, ck_fr
    lw    $t1, ck_r
    bge   $t0, $t1, ck_1
    li    $a0, DIR_UP
    jal   try_dir
    bnez  $v0, ck_ret
ck_1:
    lw    $t0, ck_fr
    lw    $t1, ck_r
    ble   $t0, $t1, ck_2
    li    $a0, DIR_DOWN
    jal   try_dir
    bnez  $v0, ck_ret
ck_2:
    lw    $t0, ck_fc
    lw    $t1, ck_c
    bge   $t0, $t1, ck_3
    li    $a0, DIR_LEFT
    jal   try_dir
    bnez  $v0, ck_ret
ck_3:
    lw    $t0, ck_fc
    lw    $t1, ck_c
    ble   $t0, $t1, ck_4
    li    $a0, DIR_RIGHT
    jal   try_dir
    bnez  $v0, ck_ret
ck_4:
    # Qualquer direção segura.
    li    $t0, DIR_UP
    sw    $t0, 0($sp)
ck_any:
    lw    $a0, 0($sp)
    jal   try_dir
    bnez  $v0, ck_ret
    lw    $t0, 0($sp)
    addiu $t0, $t0, 1
    sw    $t0, 0($sp)
    ble   $t0, DIR_LEFT, ck_any
    # Nenhuma segura: mantém a direção (vai colidir).
    lw    $a0, dir
    bnez  $a0, ck_ret
    li    $a0, DIR_UP
ck_ret:
    lb    $v0, keytab($a0)          # $a0 = código da direção escolhida
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

#------------------------------------------------------------------------------
# try_dir — $a0 = direção; $v0 = 1 se for segura (não oposta, dentro da
#   grade e sem cobra na célula de destino). Preserva $a0.
#------------------------------------------------------------------------------
try_dir:
    li    $v0, 0
    lw    $t0, dir
    beq   $t0, DIR_NONE, td_pos
    subu  $t1, $a0, $t0
    beq   $t1, 2, td_ret
    beq   $t1, -2, td_ret
td_pos:
    lw    $t2, ck_r
    lw    $t3, ck_c
    sll   $t4, $a0, 2
    lw    $t5, dir_drow($t4)
    lw    $t6, dir_dcol($t4)
    addu  $t2, $t2, $t5
    addu  $t3, $t3, $t6
    bgeu  $t2, GRID, td_ret
    bgeu  $t3, GRID, td_ret
    sll   $t2, $t2, GRID_SHIFT
    or    $t2, $t2, $t3
    sll   $t2, $t2, 2
    lw    $t5, frame($t2)
    beq   $t5, COLOR_SNAKE, td_ret
    li    $v0, 1
td_ret:
    jr    $ra

#------------------------------------------------------------------------------
# check_inv — $a0 = pontuação esperada; $v0 = 0 ou o código da invariante
#   violada (ver cabeçalho).
#------------------------------------------------------------------------------
check_inv:
    move  $t9, $a0
    lw    $t0, length
    li    $v0, 1
    blez  $t0, ci_ret
    bgt   $t0, 1024, ci_ret
    lw    $t1, head_idx
    lw    $t2, tail_idx
    li    $v0, 3
    bgeu  $t1, 1024, ci_ret
    bgeu  $t2, 1024, ci_ret
    subu  $t3, $t1, $t2
    andi  $t3, $t3, QUEUE_MASK
    addiu $t4, $t0, -1
    li    $v0, 2
    bne   $t3, $t4, ci_ret
    # Limpa as marcas.
    li    $t3, 0
ci_clear:
    sw    $zero, inv_marks($t3)
    addiu $t3, $t3, 4
    blt   $t3, 1024, ci_clear
    # Percorre a fila da cauda até a cabeça.
    li    $t5, -1                   # célula anterior (-1 = nenhuma)
    move  $t3, $t0                  # segmentos restantes
ci_walk:
    sll   $t4, $t2, 2
    lw    $t6, body($t4)            # célula do segmento
    li    $v0, 4
    bgeu  $t6, 1024, ci_ret
    sll   $t4, $t6, 2
    lw    $t7, frame($t4)
    li    $v0, 5
    bne   $t7, COLOR_SNAKE, ci_ret
    lb    $t7, inv_marks($t6)
    li    $v0, 7
    bnez  $t7, ci_ret
    li    $t7, 1
    sb    $t7, inv_marks($t6)
    bltz  $t5, ci_first
    srl   $t7, $t6, GRID_SHIFT      # |dlinha| + |dcoluna| == 1
    srl   $t8, $t5, GRID_SHIFT
    subu  $t7, $t7, $t8
    abs   $t7, $t7
    andi  $t4, $t6, GRID_MASK
    andi  $t8, $t5, GRID_MASK
    subu  $t4, $t4, $t8
    abs   $t4, $t4
    addu  $t7, $t7, $t4
    li    $v0, 6
    bne   $t7, 1, ci_ret
ci_first:
    move  $t5, $t6
    addiu $t2, $t2, 1
    andi  $t2, $t2, QUEUE_MASK
    addiu $t3, $t3, -1
    bnez  $t3, ci_walk
    # Conta as cores da tela.
    li    $t1, 0                    # cobra
    li    $t2, 0                    # comida
    li    $t3, 0                    # fundo
    li    $t4, 0
ci_count:
    lw    $t5, frame($t4)
    bne   $t5, COLOR_SNAKE, ci_c1
    addiu $t1, $t1, 1
    j     ci_cn
ci_c1:
    bne   $t5, COLOR_FOOD, ci_c2
    addiu $t2, $t2, 1
    j     ci_cn
ci_c2:
    bne   $t5, COLOR_BG, ci_cn
    addiu $t3, $t3, 1
ci_cn:
    addiu $t4, $t4, 4
    blt   $t4, 4096, ci_count
    li    $v0, 8
    bne   $t1, $t0, ci_ret
    li    $v0, 9
    bne   $t2, 1, ci_ret
    lw    $t5, food_idx
    sll   $t5, $t5, 2
    lw    $t6, frame($t5)
    bne   $t6, COLOR_FOOD, ci_ret
    li    $t6, 1023
    subu  $t6, $t6, $t0
    li    $v0, 10
    bne   $t3, $t6, ci_ret
    lw    $t5, score
    li    $v0, 11
    bne   $t5, $t9, ci_ret
    li    $v0, 0
ci_ret:
    jr    $ra
