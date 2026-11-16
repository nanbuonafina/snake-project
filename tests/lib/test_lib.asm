###############################################################################
# test_lib.asm — rotinas de apoio aos testes automatizados (Assembly MIPS).
#
# Este arquivo NÃO faz parte do jogo. tools/run_tests.sh monta cada teste
# juntando: src/snake.asm sem o bloco MAIN + este arquivo + tests/t_*.asm.
# Assim, os testes chamam as MESMAS rotinas do jogo entregue.
###############################################################################

.data
tl_fails:   .word 0
tl_ok:      .asciiz "  ok     "
tl_fail:    .asciiz "  FALHA  "
tl_got:     .asciiz "   (obtido "
tl_exp:     .asciiz ", esperado "
tl_close:   .asciiz ")"
tl_nl:      .asciiz "\n"
tl_summary: .asciiz "RESULTADO: falhas = "

.text

#------------------------------------------------------------------------------
# CHECK — compara um registrador com um valor imediato e registra o resultado.
# CHECK_REG — compara dois registradores.
#   Não use $a0-$a2 como "esperado" (CHECK_REG), pois eles são sobrescritos.
#------------------------------------------------------------------------------
.macro CHECK (%actual, %expected, %name)
    move $a0, %actual
    li   $a1, %expected
    la   $a2, %name
    jal  assert_eq
.end_macro

.macro CHECK_REG (%actual, %expected, %name)
    move $a0, %actual
    move $a1, %expected
    la   $a2, %name
    jal  assert_eq
.end_macro

# Carrega a word do rótulo %label em %reg e compara com %expected.
.macro CHECK_VAR (%label, %expected, %name)
    lw   $a0, %label
    li   $a1, %expected
    la   $a2, %name
    jal  assert_eq
.end_macro

#------------------------------------------------------------------------------
# assert_eq — $a0 = obtido, $a1 = esperado, $a2 = nome do caso.
#   Imprime "ok" ou "FALHA (obtido X, esperado Y)". Conta as falhas.
#------------------------------------------------------------------------------
assert_eq:
    move  $t7, $a0
    move  $t8, $a1
    move  $t9, $a2
    beq   $t7, $t8, ae_ok
    la    $a0, tl_fail
    li    $v0, 4
    syscall
    move  $a0, $t9
    syscall
    la    $a0, tl_got
    syscall
    move  $a0, $t7
    li    $v0, 1
    syscall
    la    $a0, tl_exp
    li    $v0, 4
    syscall
    move  $a0, $t8
    li    $v0, 1
    syscall
    la    $a0, tl_close
    li    $v0, 4
    syscall
    lw    $t0, tl_fails
    addiu $t0, $t0, 1
    sw    $t0, tl_fails
    j     ae_end
ae_ok:
    la    $a0, tl_ok
    li    $v0, 4
    syscall
    move  $a0, $t9
    syscall
ae_end:
    la    $a0, tl_nl
    li    $v0, 4
    syscall
    jr    $ra

#------------------------------------------------------------------------------
# finish_tests — imprime o total de falhas e encerra.
#------------------------------------------------------------------------------
finish_tests:
    la    $a0, tl_summary
    li    $v0, 4
    syscall
    lw    $a0, tl_fails
    li    $v0, 1
    syscall
    la    $a0, tl_nl
    li    $v0, 4
    syscall
    li    $v0, 10
    syscall

#------------------------------------------------------------------------------
# count_color — $a0 = cor -> $v0 = quantas células do framebuffer têm a cor.
#------------------------------------------------------------------------------
count_color:
    li    $v0, 0
    li    $t0, 0
    li    $t2, 4096
cc_loop:
    lw    $t1, frame($t0)
    bne   $t1, $a0, cc_next
    addiu $v0, $v0, 1
cc_next:
    addiu $t0, $t0, 4
    bne   $t0, $t2, cc_loop
    jr    $ra

#------------------------------------------------------------------------------
# press_key — simula uma tecla no Keyboard MMIO: $a0 = código ASCII.
#   Escreve o dado em 0xFFFF0004 e liga o bit "pronto" em 0xFFFF0000,
#   e então chama read_input (a rotina real do jogo).
#------------------------------------------------------------------------------
press_key:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    li    $t0, MMIO_RCV_CTRL
    sw    $a0, MMIO_RCV_DATA($t0)
    li    $t1, 1
    sw    $t1, 0($t0)
    jal   read_input
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

#------------------------------------------------------------------------------
# remove_food — apaga a comida sorteada (deixa o tabuleiro determinístico).
#------------------------------------------------------------------------------
remove_food:
    lw    $t0, food_idx
    sll   $t0, $t0, 2
    li    $t1, COLOR_BG
    sw    $t1, frame($t0)
    jr    $ra

#------------------------------------------------------------------------------
# place_food — põe comida na célula $a0 (posição controlada pelo teste).
#------------------------------------------------------------------------------
place_food:
    sw    $a0, food_idx
    sll   $t0, $a0, 2
    li    $t1, COLOR_FOOD
    sw    $t1, frame($t0)
    jr    $ra

#------------------------------------------------------------------------------
# move_dir — define next_dir = $a0 e executa um step. Retorna o status em $v0.
#------------------------------------------------------------------------------
move_dir:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    sw    $a0, next_dir
    jal   step
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

#------------------------------------------------------------------------------
# eat_at — põe comida na célula $a1, anda na direção $a0 (deve comer) e
#   apaga a nova comida sorteada. Retorna o status do step em $v0.
#------------------------------------------------------------------------------
eat_at:
    addiu $sp, $sp, -12
    sw    $ra, 8($sp)
    sw    $a0, 4($sp)
    move  $a0, $a1
    jal   place_food
    lw    $a0, 4($sp)
    jal   move_dir
    sw    $v0, 0($sp)
    jal   remove_food
    lw    $v0, 0($sp)
    lw    $ra, 8($sp)
    addiu $sp, $sp, 12
    jr    $ra

#------------------------------------------------------------------------------
# head_cell — $v0 = índice da célula onde está a cabeça.
#------------------------------------------------------------------------------
head_cell:
    lw    $t0, head_idx
    sll   $t0, $t0, 2
    lw    $v0, body($t0)
    jr    $ra
