package liquibase.sqlgenerator.core;

import liquibase.database.Database;
import liquibase.database.core.PostgresDatabase;
import liquibase.exception.ValidationErrors;
import liquibase.sql.Sql;
import liquibase.sql.UnparsedSql;
import liquibase.sqlgenerator.SqlGenerator;
import liquibase.sqlgenerator.SqlGeneratorChain;
import liquibase.statement.core.DropSequenceStatement;

public class DropSequenceGenerator extends AbstractSqlGenerator<DropSequenceStatement> {

    @Override
    public boolean supports(DropSequenceStatement statement, Database database) {
        return database.supportsSequences();
    }

    public ValidationErrors validate(DropSequenceStatement dropSequenceStatement, Database database, SqlGeneratorChain sqlGeneratorChain) {
        ValidationErrors validationErrors = new ValidationErrors();
        validationErrors.checkRequiredField("sequenceName", dropSequenceStatement.getSequenceName());
        return validationErrors;
    }

    public Sql[] generateSql(DropSequenceStatement statement, Database database, SqlGeneratorChain sqlGeneratorChain) {
        String sql = "DROP SEQUENCE " + database.escapeSequenceName(statement.getSchemaName(), statement.getSequenceName());
        if (database instanceof PostgresDatabase) {
            sql += " CASCADE";
        }

        return new Sql[] {
                new UnparsedSql(sql)
        };
    }
}
