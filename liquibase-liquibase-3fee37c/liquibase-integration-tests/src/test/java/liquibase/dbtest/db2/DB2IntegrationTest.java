package liquibase.dbtest.db2;

import liquibase.dbtest.AbstractIntegrationTest;

import java.util.Properties;

public class DB2IntegrationTest extends AbstractIntegrationTest {

    public DB2IntegrationTest() throws Exception {
        super("db2", "jdbc:db2://"+ getDatabaseServerHostname("DB2") +":50000/lqbase");
    }

    @Override
    protected Properties createProperties() {
        Properties properties = super.createProperties();
        properties.put("retrieveMessagesFromServerOnGetMessage", "true");
        return properties;
    }

}
