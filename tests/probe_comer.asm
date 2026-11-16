###############################################################################
# probe_comer.asm — cenário de T16d/T16e (executado pelo tools/BitmapProbe).
# NÃO é um t_*.asm: não roda no laço dos testes de linha de comando.
#
# Põe a comida na célula (0,2), anda 2x para a direita (come) e deixa a
# rotina real spawn_food sortear a NOVA comida. Imprime "comida=<índice>"
# e fica parado, para que o probe capture a tela do Bitmap Display.
# Montado como: "j main" + src/snake.asm sem MAIN + test_lib + este arquivo.
###############################################################################
.data
pc_food: .asciiz "comida="
pc_nl:   .asciiz "\n"

.text
.globl main
main:
    jal  init_game
    jal  remove_food
    li   $a0, 2                     # comida em (0,2)
    jal  place_food
    li   $a0, DIR_RIGHT
    jal  move_dir                   # cabeça em (0,1)
    li   $a0, DIR_RIGHT
    jal  move_dir                   # cabeça em (0,2): come e sorteia nova comida
    la   $a0, pc_food
    li   $v0, 4
    syscall
    lw   $a0, food_idx
    li   $v0, 1
    syscall
    la   $a0, pc_nl
    li   $v0, 4
    syscall
pc_hang:
    j    pc_hang                    # mantém o programa vivo para a captura
