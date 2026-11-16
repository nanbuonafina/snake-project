###############################################################################
# t_grid.asm — T01/T02: framebuffer em 0x10010000 e endereçamento das células.
###############################################################################
.data
n_base:  .asciiz "T01 frame esta em 0x10010000 (base do Bitmap Display)"
n_c0:    .asciiz "T02 celula (0,0)   -> 0x10010000"
n_c31:   .asciiz "T02 celula (0,31)  -> 0x1001007C"
n_c992:  .asciiz "T02 celula (31,0)  -> 0x10010F80"
n_c1023: .asciiz "T02 celula (31,31) -> 0x10010FFC"
n_mid:   .asciiz "T02 celula (10,20) -> get_cell le o que draw_cell escreveu"
n_vars:  .asciiz "T02 score em 0x10012018 (endereco lido pelo teste T14)"
n_vlen:  .asciiz "T02 length em 0x10012008 (endereco lido pelos testes T13/T14)"
n_clear: .asciiz "T02 clear_screen deixa as 1024 celulas com a cor de fundo"
.text
.globl main
main:
    la    $t0, frame
    CHECK($t0, 0x10010000, n_base)

    # Cada canto: desenha com cor 0x123456 e lê o endereço físico esperado.
    li    $a0, 0
    li    $a1, 0x123456
    jal   draw_cell
    lw    $t0, 0x10010000
    CHECK($t0, 0x123456, n_c0)

    li    $a0, 31
    li    $a1, 0x123456
    jal   draw_cell
    lw    $t0, 0x1001007C
    CHECK($t0, 0x123456, n_c31)

    li    $a0, 992                  # 31*32 + 0
    li    $a1, 0x123456
    jal   draw_cell
    lw    $t0, 0x10010F80
    CHECK($t0, 0x123456, n_c992)

    li    $a0, 1023                 # 31*32 + 31
    li    $a1, 0x123456
    jal   draw_cell
    lw    $t0, 0x10010FFC
    CHECK($t0, 0x123456, n_c1023)

    li    $a0, 340                  # 10*32 + 20
    li    $a1, 0xABCDEF
    jal   draw_cell
    li    $a0, 340
    jal   get_cell
    CHECK($v0, 0xABCDEF, n_mid)

    la    $t0, score
    CHECK($t0, 0x10012018, n_vars)
    la    $t0, length
    CHECK($t0, 0x10012008, n_vlen)

    jal   clear_screen
    li    $a0, COLOR_BG
    jal   count_color
    CHECK($v0, 1024, n_clear)

    jal   finish_tests
