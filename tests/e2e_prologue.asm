###############################################################################
# deixa a tecla'd' pendente no receptor MMIO e salta para o main do jogo. Sem o
# Keyboard Simulator conectado o bit "pronto" não é limpo, então o jogo
# lê 'd' (direita) a cada consulta: a cobra anda de (0,0) até bater na
# parede direita, passando pelo laço, temporização e game_over reais.
# Não declara .data, para não deslocar o framebuffer de 0x10010000.
###############################################################################
.text
e2e_start:
    li    $t0, 0xFFFF0000           # controle do receptor MMIO
    li    $t1, 'd'
    sw    $t1, 4($t0)               # dado do receptor = 'd'
    li    $t1, 1
    sw    $t1, 0($t0)               # bit "pronto" = 1
    j     main                      # executa o jogo real
