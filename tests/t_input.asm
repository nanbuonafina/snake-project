###############################################################################
# leitura AWSD pelo MMIO (sem bloqueio) e temporização.
# as teclas são simuladas escrevendo nos registradores do receptor MMIO
# (0xFFFF0000 / 0xFFFF0004) e chamando a rotina real read_input.
###############################################################################
.data
n_nokey:  .asciiz "T05 sem tecla pronta: read_input retorna sem mudar a direcao"
n_other:  .asciiz "T05 tecla 'x' e ignorada"
n_first:  .asciiz "T05 parada (D1): 'a' e aceita como primeira direcao"
n_rev1:   .asciiz "T05 indo p/ direita: 'a' (oposta) e ignorada (D2)"
n_W:      .asciiz "T05 'W' maiusculo vira cima (D3)"
n_s:      .asciiz "T05 indo p/ direita: 's' vira baixo"
n_D:      .asciiz "T05 'D' maiusculo vira direita (D3)"
n_rev2:   .asciiz "T05 indo p/ cima: 's' (oposta) e ignorada"
n_rev3:   .asciiz "T05 indo p/ cima: 'S' (oposta) e ignorada"
n_a:      .asciiz "T05 indo p/ cima: 'a' vira esquerda"
n_rev4:   .asciiz "T05 indo p/ esquerda: 'd' (oposta) e ignorada"
n_rev5:   .asciiz "T05 indo p/ baixo: 'w' (oposta) e ignorada"
n_same:   .asciiz "T05 indo p/ baixo: 's' (mesma direcao) mantem baixo"
n_keep:   .asciiz "T06 sem tecla nova, step repete a direcao anterior"
n_wfk:    .asciiz "T05 wait_first_key retorna apos tecla 'd' (direita)"
n_tick1:  .asciiz "T06 wait_tick: 1 tick dura >= 500 ms"
n_tick1b: .asciiz "T06 wait_tick: 1 tick dura < 600 ms"
n_tick4:  .asciiz "T06 wait_tick: 4 ticks duram >= 2000 ms (sem atraso acumulado)"
n_tick4b: .asciiz "T06 wait_tick: 4 ticks duram < 2100 ms"
n_pause1: .asciiz "T06p apos pausa de 5 s: o 1o tick sai imediatamente (< 100 ms)"
n_pause3: .asciiz "T06p apos pausa de 5 s: os 3 ticks seguintes NAO sao recuperados de uma vez (>= 1000 ms)"
n_pmove:  .asciiz "T06p/T12 apos pausa de 5 s: 1 tick vencido gera so 1 movimento/ponto"
.text
.globl main

# Macro local: define a direção atual (dir) e a pedida (next_dir).
.macro SET_DIR (%d)
    li    $t0, %d
    sw    $t0, dir
    sw    $t0, next_dir
.end_macro

main:
    jal   init_game

    # Nenhuma tecla pronta (bit 0 do controle = 0).
    li    $t0, MMIO_RCV_CTRL
    sw    $zero, 0($t0)
    jal   read_input
    CHECK_VAR(next_dir, DIR_NONE, n_nokey)

    li    $a0, 'x'
    jal   press_key
    CHECK_VAR(next_dir, DIR_NONE, n_other)

    li    $a0, 'a'
    jal   press_key
    CHECK_VAR(next_dir, DIR_LEFT, n_first)

    SET_DIR(DIR_RIGHT)
    li    $a0, 'a'
    jal   press_key
    CHECK_VAR(next_dir, DIR_RIGHT, n_rev1)
    li    $a0, 'W'
    jal   press_key
    CHECK_VAR(next_dir, DIR_UP, n_W)
    li    $a0, 's'
    jal   press_key
    CHECK_VAR(next_dir, DIR_DOWN, n_s)
    li    $a0, 'D'
    jal   press_key
    CHECK_VAR(next_dir, DIR_RIGHT, n_D)

    SET_DIR(DIR_UP)
    li    $a0, 's'
    jal   press_key
    CHECK_VAR(next_dir, DIR_UP, n_rev2)
    li    $a0, 'S'
    jal   press_key
    CHECK_VAR(next_dir, DIR_UP, n_rev3)
    li    $a0, 'a'
    jal   press_key
    CHECK_VAR(next_dir, DIR_LEFT, n_a)

    SET_DIR(DIR_LEFT)
    li    $a0, 'd'
    jal   press_key
    CHECK_VAR(next_dir, DIR_LEFT, n_rev4)

    SET_DIR(DIR_DOWN)
    li    $a0, 'w'
    jal   press_key
    CHECK_VAR(next_dir, DIR_DOWN, n_rev5)
    li    $a0, 's'
    jal   press_key
    CHECK_VAR(next_dir, DIR_DOWN, n_same)

    # Repetição da direção: cobra em (0,0) indo para baixo, 3 steps sem
    # nenhuma tecla -> cabeça em (3,0) = célula 96.
    jal   init_game
    jal   remove_food
    SET_DIR(DIR_DOWN)
    jal   step
    jal   step
    jal   step
    lw    $t0, head_idx
    sll   $t0, $t0, 2
    lw    $t1, body($t0)
    CHECK($t1, 96, n_keep)

    # wait_first_key com uma tecla 'd' pendente no MMIO.
    jal   init_game
    li    $t0, MMIO_RCV_CTRL
    li    $t1, 'd'
    sw    $t1, MMIO_RCV_DATA($t0)
    li    $t1, 1
    sw    $t1, 0($t0)
    jal   wait_first_key
    CHECK_VAR(next_dir, DIR_RIGHT, n_wfk)

    # Temporização real (relógio do sistema via syscall 30).
    li    $t0, MMIO_RCV_CTRL
    sw    $zero, 0($t0)             # sem teclas durante a medição
    li    $v0, SYS_TIME
    syscall
    sw    $a0, deadline
    move  $s0, $a0                  # início
    jal   wait_tick
    li    $v0, SYS_TIME
    syscall
    subu  $s1, $a0, $s0             # duração de 1 tick
    sge   $t0, $s1, 500
    CHECK($t0, 1, n_tick1)
    slti  $t0, $s1, 600
    CHECK($t0, 1, n_tick1b)

    li    $v0, SYS_TIME
    syscall
    sw    $a0, deadline
    move  $s0, $a0
    jal   wait_tick
    jal   wait_tick
    jal   wait_tick
    jal   wait_tick
    li    $v0, SYS_TIME
    syscall
    subu  $s1, $a0, $s0             # duração de 4 ticks
    sge   $t0, $s1, 2000
    CHECK($t0, 1, n_tick4)
    slti  $t0, $s1, 2100
    CHECK($t0, 1, n_tick4b)

    # ---- Pausa: simula o MARS pausado por 5 s (prazo 5 s no passado) -------
    # Esperado: no máximo 1 tick "atrasado" sai na hora; depois o ritmo volta
    # a ser 500 ms. Sem isso, a cobra andaria 10 casas instantaneamente e
    # ganharia 10 pontos indevidos.
    li    $v0, SYS_TIME
    syscall
    move  $s0, $a0
    addiu $t0, $a0, -5000
    sw    $t0, deadline             # último tick foi há 5 s
    jal   wait_tick                 # 1º tick: vencido, sai na hora
    li    $v0, SYS_TIME
    syscall
    subu  $s1, $a0, $s0
    slti  $t0, $s1, 100
    CHECK($t0, 1, n_pause1)
    jal   wait_tick
    jal   wait_tick
    jal   wait_tick
    li    $v0, SYS_TIME
    syscall
    subu  $s1, $a0, $s0
    sge   $t0, $s1, 1000
    CHECK($t0, 1, n_pause3)

    # Mesmo cenário pelo laço do jogo: conta quantos ticks vencem (e quantos
    # steps acontecem) nos 300 ms seguintes a uma pausa de 5 s (deve ser 1).
    jal   init_game
    jal   remove_food
    SET_DIR(DIR_DOWN)
    li    $v0, SYS_TIME
    syscall
    addiu $s3, $a0, 300             # janela de observação: 300 ms
    addiu $t0, $a0, -5000
    sw    $t0, deadline
pm_loop:
    jal   wait_tick                 # conta só os ticks que vencem dentro
    li    $v0, SYS_TIME             # da janela de 300 ms
    syscall
    subu  $t0, $a0, $s3
    bgez  $t0, pm_end
    jal   step
    j     pm_loop
pm_end:
    CHECK_VAR(score, 1, n_pmove)

    jal   finish_tests
