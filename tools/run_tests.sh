# run_tests.sh — script de teste para o jogo da cobrinha.
# uso: tools/run_tests.sh

set -u
cd "$(dirname "$0")/.."

MARS="tools/Mars4_5.jar"
SRC="${SRC:-src/snake.asm}"   # pode ser trocado (ex.: testes de mutação)
BUILD="tests/build"
MAX_STEPS=300000000         # limite de instruções por teste (evita laço infinito)

[ -f "$MARS" ] || { echo "MARS não encontrado em $MARS (ver docs/configuracao-mars.md)"; exit 1; }
mkdir -p "$BUILD"
failed=0

# Opções do MARS: nc = sem aviso de copyright; ae2/se3 = código de saída 2/3
# em erro de montagem/execução; a = só montar; sm = começar em 'main'.

echo "== T00 montagem de $SRC"
if out=$(java -jar "$MARS" nc ae2 a "$SRC" 2>&1) && [ -z "$out" ]; then
    echo "  ok     monta sem erros nem avisos"
else
    echo "  FALHA  montagem:"; echo "$out"; failed=1
fi

echo "== T00b execução do jogo completo por 300000 instruções (sem teclado: aguarda 1ª tecla)"
out=$(java -jar "$MARS" nc ae2 se3 300000 "$SRC" 2>&1); rc=$?
if [ $rc -eq 0 ] && ! grep -qiE 'error|exception' <<<"$out"; then
    echo "  ok     executa sem erro de execução"
else
    echo "  FALHA  (rc=$rc):"; echo "$out"; failed=1
fi

for t in tests/t_*.asm; do
    name=$(basename "$t")
    build="$BUILD/$name"
    {
        sed '/# ==== BEGIN MAIN ====/,/# ==== END MAIN ====/d' "$SRC"
        cat tests/lib/test_lib.asm
        cat "$t"
    } > "$build"
    echo "== $name"
    out=$(java -jar "$MARS" nc ae2 se3 sm "$MAX_STEPS" "$build" 2>&1); rc=$?
    echo "$out" | sed '/^$/d'
    if [ $rc -ne 0 ] || ! grep -q 'RESULTADO: falhas = 0$' <<<"$out"; then
        echo "  >>> $name FALHOU (rc=$rc)"; failed=1
    fi
done

# Faixas de memória exibidas pelo MARS ao fim da execução:
#   framebuffer 0x10010000-0x10010ffc e variáveis 0x10012000-0x1001201c
#   (head_idx, tail_idx, length, food_idx, dir, next_dir, score, deadline;
#    os endereços de length e score são conferidos em t_grid.asm).
MEMRANGES="0x10010000-0x10010ffc 0x10012000-0x1001201c"

# word <saida> <endereço> -> valor (decimal) da word exibida pelo MARS
word() {
    awk -v want="$2" '/^Mem\[/ { a=strtonum(substr($1,5,10));
        for (i=2;i<=NF;i++) if (a+(i-2)*4==strtonum(want)) print strtonum($i) }' <<<"$1"
}
# frame_summary <saida> -> "fundo cobra comida vermelho outras lista_azuis indice_vermelho"
frame_summary() {
    awk '/^Mem\[/ { a=strtonum(substr($1,5,10)); if (a>=0x10012000) next;
        for (i=2;i<=NF;i++) { idx=(a-0x10010000)/4+(i-2); v=strtonum($i);
          if (v==0) bg++; else if (v==0x0070C0) { sn++; blues=blues idx "," }
          else if (v==0x66A830) fd++; else if (v==0xE02020) { rd++; ridx=idx } else ot++ } }
        END { printf "%d %d %d %d %d %s %s\n", bg, sn, fd, rd, ot, (blues==""?"-":blues), (ridx==""?"-":ridx) }' <<<"$1"
}

echo "== T13 ponta a ponta: main real, tecla 'd' simulada, até bater na parede direita"
# Java em modo headless: a caixa de diálogo final (syscall 56) gera
# HeadlessException, esperado apenas neste modo; o relatório do console
# e as faixas de memória são impressos mesmo assim.
e2e="$BUILD/e2e.asm"
cat tests/e2e_prologue.asm "$SRC" > "$e2e"
t0=$(date +%s%N)
out=$(timeout 60 java -Djava.awt.headless=true -jar "$MARS" nc ae2 se3 "$e2e" $MEMRANGES 2>&1)
t1=$(date +%s%N)
ms=$(( (t1 - t0) / 1000000 ))
echo "$out" | grep -E 'Motivo|Comprimento|Comidas|Movimentos|PONTUACAO' | sed 's/^/         /'
food=$(sed -n 's/^Comidas coletadas: //p' <<<"$out")
moves=$(sed -n 's/^Movimentos (0,5 s cada): //p' <<<"$out")
score=$(sed -n 's/^PONTUACAO FINAL: //p' <<<"$out")
mlen=$(word "$out" 0x10012008); mscore=$(word "$out" 0x10012018)
echo "  info   tempo total: ${ms} ms (32 ticks de 500 ms = 16000 ms + inicialização do Java)"
if grep -q 'Motivo: colisao com a parede' <<<"$out" && [ "$moves" = 31 ] \
   && [ -n "$score" ] && [ "$score" -eq $(( moves + 5 * food )) ] && [ "$score" = "$mscore" ] \
   && [ "$ms" -ge 16000 ] && [ "$ms" -lt 22000 ]; then
    echo "  ok     T13 parede direita após 31 movimentos; pontuação = movimentos + 5*comidas = memória; tempo coerente"
else
    echo "  FALHA  T13 relatório/tempo"; echo "$out" | grep -v '^Mem' | head -20; failed=1
fi
# Tabuleiro final: cabeça vermelha em (0,31); corpo azul contíguo na linha 0
# imediatamente à esquerda; 1 comida; resto preto; nenhuma outra cor.
read -r bg sn fd rd ot blues ridx <<<"$(frame_summary "$out")"
exp_blues=""; for ((i=32-mlen; i<31; i++)); do exp_blues="$exp_blues$i,"; done; [ -z "$exp_blues" ] && exp_blues="-"
echo "  info   tela final: fundo=$bg cobra=$sn comida=$fd vermelho=$rd outras=$ot azuis=[$blues] vermelho_em=$ridx length=$mlen"
if [ "$rd" = 1 ] && [ "$ridx" = 31 ] && [ "$sn" = $((mlen - 1)) ] && [ "$blues" = "$exp_blues" ] \
   && [ "$fd" = 1 ] && [ "$ot" = 0 ] && [ "$bg" = $((1024 - mlen - 1)) ]; then
    echo "  ok     T13 tela final consistente: sem rastros, cabeça vermelha em (0,31), 1 comida"
else
    echo "  FALHA  T13 tela final"; failed=1
fi

echo "== T14 sem tecla: o jogo real aguarda a 1ª tecla sem mover nem pontuar (3 milhões de instruções)"
idle="$BUILD/idle.asm"
printf '.text\n    j main      # sem tecla pendente no MMIO\n' | cat - "$SRC" > "$idle"
out=$(java -jar "$MARS" nc ae2 se3 3000000 "$idle" $MEMRANGES 2>&1)
read -r bg sn fd rd ot blues ridx <<<"$(frame_summary "$out")"
iscore=$(word "$out" 0x10012018); ilen=$(word "$out" 0x10012008); inext=$(word "$out" 0x10012014)
echo "  info   score=$iscore length=$ilen next_dir=$inext tela: cobra=[$blues] comida=$fd fundo=$bg"
if [ "$iscore" = 0 ] && [ "$ilen" = 1 ] && [ "$inext" = 0 ] && [ "$blues" = "0," ] \
   && [ "$fd" = 1 ] && [ "$bg" = 1022 ] && grep -q 'maximum step limit 3000000' <<<"$out"; then
    echo "  ok     T14 parada em (0,0), pontuação 0, 1 comida, sem erro"
else
    echo "  FALHA  T14"; echo "$out" | grep -v '^Mem' | head; failed=1
fi

echo "== T16 renderização no Bitmap Display real do MARS (tools/BitmapProbe.java)"
# Usa a classe mars.tools.BitmapDisplay sem abrir janela; precisa de DISPLAY.
if [ -z "${DISPLAY:-}" ] || ! command -v javac >/dev/null; then
    echo "  info   T16 não executado (sem DISPLAY ou sem javac)"
else
    probe="$BUILD/probe"; mkdir -p "$probe"
    javac -cp "$MARS" -d "$probe" tools/BitmapProbe.java 2>&1 | grep -v '^Note' || true
    pg="$BUILD/probe_game.asm"
    cat tests/e2e_prologue.asm "$SRC" > "$pg"
    probe_run() { java -cp "$MARS:$probe" BitmapProbe "$pg" "$1" 512 512 "$2" "$BUILD/$3" 3200 2>&1 | grep -E '^(config|imagem|celulas16)'; }

    out=$(probe_run 16 true t16_correto.png); echo "$out" | sed 's/^/         /'
    lit=$(sed -n 's/.*pixels_acesos=\([0-9]*\).*/\1/p' <<<"$out")
    az=$(sed -n 's/.*azul=\([0-9]*\).*/\1/p' <<<"$out"); vd=$(sed -n 's/.*verde=\([0-9]*\).*/\1/p' <<<"$out")
    if grep -q 'unit=16x16 display=512x512 base=0x10010000' <<<"$out" && grep -q 'outras=0 mistas=0' <<<"$out" \
       && [ "$vd" = 1 ] && [ "$az" -ge 1 ] && [ "$lit" -eq $(( 256 * (az + vd) )) ] \
       && ! grep -oE 'azuis=\S*' <<<"$out" | grep -qE '\([1-9][0-9]*,'; then
        echo "  ok     T16a config correta: cobra e comida visíveis em células 16x16 (cobra na linha 0, indo p/ direita)"
    else
        echo "  FALHA  T16a"; failed=1
    fi

    out=$(probe_run 1 true t16_unit1.png); echo "$out" | sed 's/^/         /'
    lit=$(sed -n 's/.*pixels_acesos=\([0-9]*\).*/\1/p' <<<"$out")
    # Com Unit = 1 o display cobre 1 MB a partir de 0x10010000: além das
    # 1024 words do jogo (2 linhas de pixels), aparecem como pontos quase
    # pretos a fila body, as variáveis e as strings. Nenhuma célula 16x16.
    if [ -n "$lit" ] && [ "$lit" -lt 100 ] && grep -q 'azul=0 verde=0' <<<"$out"; then
        echo "  ok     T16b sintoma documentado: com Unit = 1 (padrão do MARS) só $lit de 262144 pixels acendem (tela 'preta')"
    else
        echo "  FALHA  T16b"; failed=1
    fi

    out=$(probe_run 16 false t16_desconectado.png); echo "$out" | sed 's/^/         /'
    if grep -q 'pixels_acesos=0$' <<<"$out"; then
        echo "  ok     T16c sintoma documentado: sem 'Connect to MIPS' nada é desenhado"
    else
        echo "  FALHA  T16c"; failed=1
    fi

    # T16d/T16e: a comida sorteada DEPOIS de comer (relato do usuário: "depois
    # da 1ª comida não aparece mais nenhuma"). O índice da nova comida é
    # aleatório; o teste confere que ela aparece exatamente onde a memória diz.
    pe="$BUILD/probe_comer.asm"
    { printf '.text\n    j main\n'
      sed '/# ==== BEGIN MAIN ====/,/# ==== END MAIN ====/d' "$SRC"
      cat tests/lib/test_lib.asm tests/probe_comer.asm; } > "$pe"
    eat_run() { java -cp "$MARS:$probe" BitmapProbe "$pe" 16 512 "$1" true "$BUILD/$2" 2500 2>&1 | grep -E '^(config|comida|imagem|celulas16)'; }

    out=$(eat_run 512 t16_comer_512.png); echo "$out" | sed 's/^/         /'
    fi=$(sed -n 's/^comida=\([0-9]*\).*/\1/p' <<<"$out")
    if [ -n "$fi" ] && grep -q "azul=2 verde=1 vermelho=0 outras=0 mistas=0 azuis=(0,1)(0,2) verdes=($((fi / 32)),$((fi % 32)))$" <<<"$out"; then
        echo "  ok     T16d altura 512: depois de comer, a nova comida aparece em ($((fi / 32)),$((fi % 32))), a posição gravada na memória"
    else
        echo "  FALHA  T16d"; failed=1
    fi

    out=$(eat_run 256 t16_comer_256.png); echo "$out" | sed 's/^/         /'
    fi=$(sed -n 's/^comida=\([0-9]*\).*/\1/p' <<<"$out")
    # Com Display Height = 256 (padrão do MARS) só as linhas 0-15 aparecem.
    if [ -n "$fi" ] && [ "$fi" -ge 512 ]; then want="verde=0"; else want="verde=1"; fi
    if [ -n "$fi" ] && grep -q 'imagem 512x256' <<<"$out" && grep -q "$want" <<<"$out"; then
        echo "  ok     T16e sintoma documentado: com altura 256 só as linhas 0-15 aparecem (comida na linha $((fi / 32)): $want)"
    else
        echo "  FALHA  T16e"; failed=1
    fi
fi

echo
if [ $failed -eq 0 ]; then echo "TODOS OS TESTES PASSARAM"; else echo "HÁ TESTES FALHANDO"; fi
exit $failed
