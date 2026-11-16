// ferramenta de teste para o display do MIPS (validar se os pixels estão sendo se comportando da forma esperada).
// apenas necessária para o caso de teste T16. 

import mars.Globals;
import mars.MIPSprogram;
import mars.mips.hardware.MemoryConfigurations;
import mars.tools.AbstractMarsToolAndApplication;
import mars.tools.BitmapDisplay;

import javax.imageio.ImageIO;
import javax.swing.JComboBox;
import javax.swing.JPanel;
import java.awt.Dimension;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;

public class BitmapProbe {
    static final int CELL = 16;
    static final int BLUE = 0x0070C0, GREEN = 0x66A830, RED = 0xE02020;

    static Field field(Class<?> c, String n) throws Exception {
        Field f = c.getDeclaredField(n);
        f.setAccessible(true);
        return f;
    }

    static Object call(Object o, Class<?> c, String m) throws Exception {
        Method x = c.getDeclaredMethod(m);
        x.setAccessible(true);
        return x.invoke(o);
    }

    static void select(BitmapDisplay bd, String combo, String value) throws Exception {
        ((JComboBox<?>) field(BitmapDisplay.class, combo).get(bd)).setSelectedItem(value);
    }

    public static void main(String[] a) throws Exception {
        String asm = a[0], unit = a[1], width = a[2], height = a[3], png = a[5];
        boolean connect = Boolean.parseBoolean(a[4]);
        int waitMs = Integer.parseInt(a[6]);
        Class<?> tool = AbstractMarsToolAndApplication.class, bdc = BitmapDisplay.class;

        // MARS em modo "linha de comando", configuração de memória padrão.
        Globals.initialize(true);
        MemoryConfigurations.setCurrentConfiguration(MemoryConfigurations.getDefaultConfiguration());

        // Bitmap Display como ferramenta do MARS (a janela nunca é exibida).
        BitmapDisplay bd = new BitmapDisplay();
        field(tool, "isBeingUsedAsAMarsTool").set(bd, true);
        call(bd, bdc, "initializePreGUI");
        call(bd, bdc, "buildMainDisplayArea");
        select(bd, "visualizationUnitPixelWidthSelector", unit);
        select(bd, "visualizationUnitPixelHeightSelector", unit);
        select(bd, "visualizationPixelWidthSelector", width);
        select(bd, "visualizationPixelHeightSelector", height);
        System.out.printf("config: unit=%sx%s display=%sx%s base=0x%08x conectado=%s%n",
                field(bdc, "unitPixelWidth").get(bd), field(bdc, "unitPixelHeight").get(bd),
                field(bdc, "displayAreaWidthInPixels").get(bd), field(bdc, "displayAreaHeightInPixels").get(bd),
                field(bdc, "baseAddress").get(bd), connect);

        // Monta e executa o programa no simulador do MARS.
        MIPSprogram program = new MIPSprogram();
        ArrayList<String> files = new ArrayList<>();
        files.add(asm);
        program.assemble(program.prepareFilesForAssembly(files, asm, null), true, false);
        if (connect) call(bd, bdc, "addAsObserver");          // "Connect to MIPS"
        Thread sim = new Thread(() -> {
            try { program.simulate(-1); } catch (Exception e) { e.printStackTrace(); }
        });
        sim.setDaemon(true);
        sim.start();
        Thread.sleep(waitMs);

        // Desenha o painel do Bitmap Display numa imagem.
        JPanel canvas = (JPanel) field(bdc, "canvas").get(bd);
        Dimension d = canvas.getPreferredSize();
        canvas.setSize(d);
        BufferedImage img = new BufferedImage(d.width, d.height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        canvas.paint(g);
        g.dispose();
        ImageIO.write(img, "png", new File(png));

        // Resumo por células de 16x16: cada célula deve ter uma cor só.
        int lit = 0, blue = 0, green = 0, red = 0, other = 0, mixed = 0;
        StringBuilder blueCells = new StringBuilder(), greenCells = new StringBuilder();
        for (int y = 0; y < d.height; y++)
            for (int x = 0; x < d.width; x++)
                if ((img.getRGB(x, y) & 0xFFFFFF) != 0) lit++;
        for (int r = 0; r < d.height / CELL; r++)
            for (int c = 0; c < d.width / CELL; c++) {
                int first = img.getRGB(c * CELL, r * CELL) & 0xFFFFFF;
                boolean uniform = true;
                for (int y = 0; y < CELL && uniform; y++)
                    for (int x = 0; x < CELL; x++)
                        if ((img.getRGB(c * CELL + x, r * CELL + y) & 0xFFFFFF) != first) { uniform = false; break; }
                if (!uniform) { mixed++; continue; }
                if (first == BLUE) { blue++; blueCells.append("(").append(r).append(",").append(c).append(")"); }
                else if (first == GREEN) { green++; greenCells.append("(").append(r).append(",").append(c).append(")"); }
                else if (first == RED) red++;
                else if (first != 0) other++;
            }
        System.out.printf("imagem %dx%d: pixels_acesos=%d%n", d.width, d.height, lit);
        System.out.printf("celulas16: azul=%d verde=%d vermelho=%d outras=%d mistas=%d azuis=%s verdes=%s%n",
                blue, green, red, other, mixed, blueCells, greenCells);
        System.exit(0);
    }
}
