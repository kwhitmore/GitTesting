package liquibase.ext.changesample;

import liquibase.change.AbstractChange;
import liquibase.database.Database;
import liquibase.database.typeconversion.TypeConverterFactory;
import liquibase.statement.core.CreateTableStatement;
import liquibase.statement.SqlStatement;

public class SampleChange extends AbstractChange {
    public SampleChange() {
        super("sampleChange", "Sample Change", 15);
    }

    public String getConfirmationMessage() {
        return "Sample Change executed";
    }

    public SqlStatement[] generateStatements(Database database) {
        return new SqlStatement[]{
            new CreateTableStatement(null, "samplechange").addColumn("id", TypeConverterFactory.getInstance().findTypeConverter(database).getDataType("int", false))
                    .addColumn("name", TypeConverterFactory.getInstance().findTypeConverter(database).getDataType("varchar(5)", false))
        };
    }
}
