package liquibase.statement.core;

import liquibase.statement.AbstractSqlStatement;

public class AddAutoIncrementStatement extends AbstractSqlStatement {

    private String schemaName;
    private String tableName;
    private String columnName;
    private String columnDataType;

    public AddAutoIncrementStatement(String schemaName, String tableName, String columnName, String columnDataType) {
        this.schemaName = schemaName;
        this.tableName = tableName;
        this.columnName = columnName;
        this.columnDataType = columnDataType;
    }

    public String getSchemaName() {
        return schemaName;
    }

    public String getTableName() {
        return tableName;
    }

    public String getColumnName() {
        return columnName;
    }

    public String getColumnDataType() {
        return columnDataType;
    }
}
