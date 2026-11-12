import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Enumeration;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.commons.ClassRemapper;
import org.objectweb.asm.commons.Remapper;

/**
 * Relocate an upstream ognl jar the way MyBatis shades it into SonarQube:
 * {@code ognl} to {@code org.apache.ibatis.ognl}, and {@code javassist}
 * references to {@code org.apache.ibatis.javassist}.
 *
 * <p>String and path rules follow maven-shade-plugin 3.6 {@code DefaultShader}
 * / {@code SimpleRelocator} (the plugin MyBatis parent 48 uses). Field and
 * method names are left alone, matching shade.
 */
public final class RelocateOgnl {
    private static final Pattern CLASS_DESCRIPTOR = Pattern.compile("(\\[*)?L(.+);");

    private static final String[][] RULES = {
        {"ognl", "org.apache.ibatis.ognl"},
        {"javassist", "org.apache.ibatis.javassist"},
    };

    private RelocateOgnl() {}

    public static void main(String[] args) throws IOException {
        if (args.length != 2) {
            System.err.println("usage: RelocateOgnl <input.jar> <output-dir>");
            System.exit(2);
        }
        Path input = Path.of(args[0]);
        Path output = Path.of(args[1]);
        Files.createDirectories(output);
        int written = 0;
        try (JarFile jar = new JarFile(input.toFile())) {
            Enumeration<JarEntry> entries = jar.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                String name = entry.getName();
                if (entry.isDirectory() || !name.endsWith(".class")) {
                    continue;
                }
                byte[] original = readAll(jar.getInputStream(entry));
                byte[] relocated = relocateClass(original);
                String internal = name.substring(0, name.length() - ".class".length());
                String mapped = map(internal, true, false) + ".class";
                if (mapped.equals(name)) {
                    throw new IOException("class was not relocated: " + name);
                }
                Path dest = output.resolve(mapped);
                Files.createDirectories(dest.getParent());
                try (OutputStream out = Files.newOutputStream(dest)) {
                    out.write(relocated);
                }
                written++;
            }
        }
        if (written == 0) {
            throw new IOException("no classes relocated from " + input);
        }
        System.out.println("relocated " + written + " classes into " + output);
    }

    static byte[] relocateClass(byte[] original) {
        ClassReader reader = new ClassReader(original);
        ClassWriter writer = new ClassWriter(0);
        ClassRemapper remapper = new ClassRemapper(writer, new ShadeRemapper());
        reader.accept(remapper, ClassReader.EXPAND_FRAMES);
        return writer.toByteArray();
    }

    /**
     * @param mapPaths slash names ({@code ognl/Foo})
     * @param mapPackages dotted names ({@code ognl.Foo})
     */
    static String map(String entityName, boolean mapPaths, boolean mapPackages) {
        String prefix = "";
        String suffix = "";
        String name = entityName;
        Matcher matcher = CLASS_DESCRIPTOR.matcher(entityName);
        if (matcher.matches()) {
            prefix = (matcher.group(1) == null ? "" : matcher.group(1)) + "L";
            suffix = ";";
            name = matcher.group(2);
        }
        for (String[] rule : RULES) {
            if (mapPackages && canRelocateClass(rule[0], name)) {
                return prefix + relocateClassName(rule[0], rule[1], name) + suffix;
            }
            if (mapPaths && canRelocatePath(rule[0], name)) {
                return prefix + relocatePath(rule[0], rule[1], name) + suffix;
            }
        }
        return entityName;
    }

    private static boolean canRelocatePath(String pattern, String path) {
        if (path.endsWith(".class")) {
            path = path.substring(0, path.length() - ".class".length());
        }
        if (!path.isEmpty() && path.charAt(0) == '/') {
            path = path.substring(1);
        }
        return path.startsWith(pattern.replace('.', '/'));
    }

    private static boolean canRelocateClass(String pattern, String clazz) {
        return clazz.indexOf('/') < 0 && canRelocatePath(pattern, clazz.replace('.', '/'));
    }

    private static String relocatePath(String pattern, String shaded, String path) {
        String from = pattern.replace('.', '/');
        String to = shaded.replace('.', '/');
        return path.replaceFirst(from, to);
    }

    private static String relocateClassName(String pattern, String shaded, String clazz) {
        return clazz.replaceFirst(pattern, shaded);
    }

    private static byte[] readAll(InputStream in) throws IOException {
        try (InputStream input = in) {
            return input.readAllBytes();
        }
    }

    private static final class ShadeRemapper extends Remapper {
        @Override
        public String map(String internalName) {
            return RelocateOgnl.map(internalName, true, false);
        }

        @Override
        public Object mapValue(Object value) {
            if (value instanceof String name) {
                return RelocateOgnl.map(name, true, true);
            }
            return super.mapValue(value);
        }
    }
}
