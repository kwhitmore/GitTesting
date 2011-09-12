package liquibase.parser.core.formattedsql;

import liquibase.change.Change;
import liquibase.change.core.EmptyChange;
import liquibase.change.core.RawSQLChange;
import liquibase.changelog.ChangeLogParameters;
import liquibase.changelog.DatabaseChangeLog;
import liquibase.resource.ResourceAccessor;
import liquibase.test.JUnitResourceAccessor;
import liquibase.util.StringUtils;
import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;

import static org.junit.Assert.*;

public class FormattedSqlChangeLogParserTest {
    private static final String VALID_CHANGELOG = "--liquibase formatted sql\n" +
            "\n" +
            "--changeset nvoxland:1\n" +
            "select * from table1;\n" +
            "\n" +
            "--changeset nvoxland:2 (stripComments:false splitStatements:false endDelimiter:X runOnChange:true runAlways:true context:y dbms:mysql runInTransaction:false failOnError:false)\n" +
            "create table table1 (\n" +
            "  id int primary key\n" +
            ");\n" +
            "\n" +
            "--rollback delete from table1;\n"+
            "--rollback drop table table1;\n"+
            "\n" +
            "--ChangeSet nvoxland:3\n" +
            "create table table2 (\n" +
            "  id int primary key\n" +
            ");\n" +
            "create table table3 (\n" +
            "  id int primary key\n" +
            ");\n"+
            "--rollback drop table table2;\n"+
            "--ChangeSet alwyn:4\n" +
            "select (*) from table2;\n" +
            "--rollback not required\n" +
            "--ChangeSet nvoxland:5\n" +
            "select (*) from table2;\n" +
            "--rollback not required\n"
            ;

    private static final String VALID_CHANGELOG2 = "select * from table1";

    private static final String DELIMETER_TEST = "create or replace function return_number return number is\n" +
                                                 "begin\n" +
                                                 " /**\n" +
                                                 "   add comment\n" +
                                                 " */\n" +
                                                 "    return 2;\n" +
                                                 "end;\n" +
                                                 "/";

    @Test
    public void supports() throws Exception {
        assertTrue(new MockFormattedSqlChangeLogParser(VALID_CHANGELOG).supports("asdf.sql", new JUnitResourceAccessor()));
        assertTrue(new MockFormattedSqlChangeLogParser(VALID_CHANGELOG2).supports("asdf.sql", new JUnitResourceAccessor()));
    }

    @Test
    public void delimeter() throws Exception {
        DatabaseChangeLog changeLog = new MockFormattedSqlChangeLogParser(DELIMETER_TEST).parse("C:/projects/MEISTER/branches/0.01_AZ4B6/SQL/CUSTOMER/Table/temp_table.tbl", new ChangeLogParameters(), new JUnitResourceAccessor(),"1895",null);

        assertEquals("C:/projects/MEISTER/branches/0.01_AZ4B6/SQL/CUSTOMER/Table/temp_table.tbl", changeLog.getLogicalFilePath());
        assertEquals(1, changeLog.getChangeSets().size());
        assertEquals("kwhitmore", changeLog.getChangeSets().get(0).getAuthor());
        assertEquals("1895", changeLog.getChangeSets().get(0).getId());

        System.out.println("SQL: " + ((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).getSql());

        assertEquals("create or replace function return_number return number is\n" +
                     "begin\n" +
                     " /**\n" +
                     "   add comment\n" +
                     " */\n" +
                     "    return 2;\n" +
                     "end;", ((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).getSql());

        assertNull(((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).getEndDelimiter());
        assertTrue(((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).isSplittingStatements());
        assertFalse(((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).isStrippingComments());
        assertFalse(changeLog.getChangeSets().get(0).isAlwaysRun());
        assertFalse(changeLog.getChangeSets().get(0).isRunOnChange());
        assertTrue(changeLog.getChangeSets().get(0).isRunInTransaction());
        assertNull(changeLog.getChangeSets().get(0).getContexts());
        assertNull(changeLog.getChangeSets().get(0).getDbmsSet());
    };

    @Test
    public void parse() throws Exception {
        DatabaseChangeLog changeLog = new MockFormattedSqlChangeLogParser(VALID_CHANGELOG).parse("asdf.sql", new ChangeLogParameters(), new JUnitResourceAccessor(),"",false);

        assertEquals("asdf.sql", changeLog.getLogicalFilePath());

        assertEquals(5, changeLog.getChangeSets().size());

        assertEquals("nvoxland", changeLog.getChangeSets().get(0).getAuthor());
        assertEquals("1", changeLog.getChangeSets().get(0).getId());
        assertEquals(1, changeLog.getChangeSets().get(0).getChanges().size());
        assertEquals("select * from table1;", ((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).getSql());
        assertNull(((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).getEndDelimiter());
     //   assertFalse(((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).isSplittingStatements());
        assertFalse(((RawSQLChange) changeLog.getChangeSets().get(0).getChanges().get(0)).isStrippingComments());
        assertFalse(changeLog.getChangeSets().get(0).isAlwaysRun());
        assertFalse(changeLog.getChangeSets().get(0).isRunOnChange());
        assertTrue(changeLog.getChangeSets().get(0).isRunInTransaction());
        assertNull(changeLog.getChangeSets().get(0).getContexts());
        assertNull(changeLog.getChangeSets().get(0).getDbmsSet());


        assertEquals("nvoxland", changeLog.getChangeSets().get(1).getAuthor());
        assertEquals("2", changeLog.getChangeSets().get(1).getId());
        assertEquals(1, changeLog.getChangeSets().get(1).getChanges().size());
        assertEquals("create table table1 (\n" +
                "  id int primary key\n" +
                ");", ((RawSQLChange) changeLog.getChangeSets().get(1).getChanges().get(0)).getSql());
        assertEquals("X", ((RawSQLChange) changeLog.getChangeSets().get(1).getChanges().get(0)).getEndDelimiter());
    //    assertFalse(((RawSQLChange) changeLog.getChangeSets().get(1).getChanges().get(0)).isSplittingStatements());
        assertFalse(((RawSQLChange) changeLog.getChangeSets().get(1).getChanges().get(0)).isStrippingComments());
        assertEquals("X", ((RawSQLChange) changeLog.getChangeSets().get(1).getChanges().get(0)).getEndDelimiter());
    //    assertFalse(((RawSQLChange) changeLog.getChangeSets().get(1).getChanges().get(0)).isSplittingStatements());
        assertFalse(((RawSQLChange) changeLog.getChangeSets().get(1).getChanges().get(0)).isStrippingComments());
        assertTrue(changeLog.getChangeSets().get(1).isAlwaysRun());
        assertTrue(changeLog.getChangeSets().get(1).isRunOnChange());
        assertFalse(changeLog.getChangeSets().get(1).isRunInTransaction());
        assertEquals("y", StringUtils.join(changeLog.getChangeSets().get(1).getContexts(), ","));
        assertEquals("mysql", StringUtils.join(changeLog.getChangeSets().get(1).getDbmsSet(), ","));
        assertEquals(1, changeLog.getChangeSets().get(1).getRollBackChanges().length);
        assertEquals("delete from table1;\n" +
                "drop table table1;", ((RawSQLChange) changeLog.getChangeSets().get(1).getRollBackChanges()[0]).getSql());


        assertEquals("nvoxland", changeLog.getChangeSets().get(2).getAuthor());
        assertEquals("3", changeLog.getChangeSets().get(2).getId());
        assertEquals(1, changeLog.getChangeSets().get(2).getChanges().size());
        assertEquals("create table table2 (\n" +
                "  id int primary key\n" +
                ");\n" +
                "create table table3 (\n" +
                "  id int primary key\n" +
                ");", ((RawSQLChange) changeLog.getChangeSets().get(2).getChanges().get(0)).getSql());
        assertNull(((RawSQLChange) changeLog.getChangeSets().get(2).getChanges().get(0)).getEndDelimiter());
    //    assertFalse(((RawSQLChange) changeLog.getChangeSets().get(2).getChanges().get(0)).isSplittingStatements());
        assertFalse(((RawSQLChange) changeLog.getChangeSets().get(2).getChanges().get(0)).isStrippingComments());
        assertEquals(1, changeLog.getChangeSets().get(2).getRollBackChanges().length);
        assertTrue(changeLog.getChangeSets().get(2).getRollBackChanges()[0] instanceof RawSQLChange);
        assertEquals("drop table table2;", ((RawSQLChange) changeLog.getChangeSets().get(2).getRollBackChanges()[0]).getSql());

        assertEquals("alwyn", changeLog.getChangeSets().get(3).getAuthor());
        assertEquals("4", changeLog.getChangeSets().get(3).getId());
        assertEquals(1, changeLog.getChangeSets().get(3).getRollBackChanges().length);
        assertTrue(changeLog.getChangeSets().get(3).getRollBackChanges()[0] instanceof EmptyChange);
        
        assertEquals("nvoxland", changeLog.getChangeSets().get(4).getAuthor());
        assertEquals("5", changeLog.getChangeSets().get(4).getId());
        assertEquals(1, changeLog.getChangeSets().get(4).getRollBackChanges().length);
        assertTrue(changeLog.getChangeSets().get(4).getRollBackChanges()[0] instanceof EmptyChange);
    }

    private static class MockFormattedSqlChangeLogParser extends FormattedSqlChangeLogParser {
        private String changeLog;

        public MockFormattedSqlChangeLogParser(String changeLog) {
            this.changeLog = changeLog;
        }

        @Override
        protected InputStream openChangeLogFile(String physicalChangeLogLocation, ResourceAccessor resourceAccessor) throws IOException {
            return new ByteArrayInputStream(changeLog.getBytes());
        }
    }
}
