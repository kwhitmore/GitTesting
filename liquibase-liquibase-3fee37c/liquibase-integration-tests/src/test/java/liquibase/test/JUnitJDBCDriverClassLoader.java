package liquibase.test;

import java.io.File;
import java.io.FileFilter;
import java.io.FilenameFilter;
import java.net.URI;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import liquibase.util.SystemUtils;

/**
 * Class Loader for loading JDBC drivers in unit tests.  It was orginally not a singleton, but
 * would instead take the directory of the particular driver you wanted and create a new
 * class loader with just those jar files.  Unfortunatley, the class loaders were never cleaned up by
 * the JVM even though there were no references to them and the permgen space requirements would skyrocket.
 * It was re-implemented as a singleton to solve that problem.  If we ever need to make different unit tests that use
 * the same driver class name but different jars (versions) we will need to re-address the issue.
 */
public class JUnitJDBCDriverClassLoader extends URLClassLoader {

    private static final JUnitJDBCDriverClassLoader instance = new JUnitJDBCDriverClassLoader();

    private JUnitJDBCDriverClassLoader() {
        super(getDriverClasspath());
    }

    public static JUnitJDBCDriverClassLoader getInstance() {
        return instance;
    }

    private static URL[] getDriverClasspath() {
        try {
            List<URL> urls = new ArrayList<URL>();

            addUrlsFromPath(urls,  "jdbc-drivers/all");

            //Add drivers by Java version. Only jars from the biggest matching version are taken
            if(SystemUtils.isJavaVersionAtLeast(1.6f)) {
                addUrlsFromPath(urls,  "jdbc-drivers/byJavaVersion/1.6");
            } else if(SystemUtils.isJavaVersionAtLeast(1.5f)) {
                addUrlsFromPath(urls,  "jdbc-drivers/byJavaVersion/1.5");
            }

            return urls.toArray(new URL[urls.size()]);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static void addUrlsFromPath(List<URL> addTo,String path) throws Exception{
            File thisClassFile = new File(new URI(Thread.currentThread().getContextClassLoader().getResource("liquibase/test/JUnitJDBCDriverClassLoader.class")
                    .toExternalForm()));
            File jdbcLib = new File(thisClassFile.getParentFile().getParentFile().getParentFile(),path);
            if (!jdbcLib.exists()) {
                throw new RuntimeException("JDBC driver directory "+jdbcLib.getAbsolutePath()+" does not exist");
            }
            File[] files = jdbcLib.listFiles(new FileFilter() {
                public boolean accept(File pathname) {
                    return pathname.isDirectory();
                }
            });
            if(files == null) {
                files = new File[]{};
            }
            for (File driverDir : files) {
                File[] driverJars = driverDir.listFiles(new FilenameFilter() {
                    public boolean accept(File dir, String name) {
                        return name.endsWith("jar");
                    }
                });

                for (File jar : driverJars) {
                    addTo.add(jar.toURL());
                }

            }
    }
}
