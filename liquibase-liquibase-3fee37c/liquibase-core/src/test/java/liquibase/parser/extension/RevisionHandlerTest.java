package liquibase.parser.extension;

import java.io.File;
import java.security.PrivateKey;

import org.junit.Before;
import org.junit.Test;
import static org.junit.Assert.*;
import org.tmatesoft.svn.core.SVNDepth;
import org.tmatesoft.svn.core.SVNException;
import org.tmatesoft.svn.core.SVNNodeKind;
import org.tmatesoft.svn.core.internal.io.svn.SVNRepositoryFactoryImpl;
import org.tmatesoft.svn.core.wc.SVNRevision;
import org.tmatesoft.svn.core.wc.admin.SVNLookClient;

public class RevisionHandlerTest {

  //  private File file = new File("liquibase-core/src/test/resources/liquibase/parser/core/xml/formattedRevisonNo.xml");
    private File file = new File("C:\\projects\\liquibase-liquibase-3fee37c\\liquibase-core\\src\\test\\resources\\liquibase\\parser\\core\\xml\\formattedRevisonNo.xml");
    private SVNRevision correctRevision = SVNRevision.create(1862);
	private SVNRevision differentRevision = SVNRevision.create(1857);

    @Test
	public void isDiff() throws Exception {

		RevisionHandler rev = new RevisionHandler();

    	rev.Update(file, correctRevision, SVNDepth.EMPTY, true, false);

        //System.out.println("Diff: " + rev.Diff(file, correctRevision));

		assertFalse(rev.IsDifferent(file, correctRevision));
        assertTrue(rev.IsDifferent(file, differentRevision));
    }

  /*  @Test
	public void UpdateCompleted() throws Exception {

		RevisionHandler rev = new RevisionHandler();

        // Update to diff revision, wait for completion of update and then confirm it's the same

    	rev.Update(file, differentRevision, SVNDepth.EMPTY, true, false);
        rev.UpdateCompleted(file, differentRevision);
        assertFalse(rev.IsDifferent(file, differentRevision));
		assertTrue(rev.IsDifferent(file, correctRevision));

        // Update to correct revision, wait for completion of update and then confirm it's the same

        rev.Update(file, correctRevision, SVNDepth.EMPTY, true, false);
        rev.UpdateCompleted(file, correctRevision);
		assertFalse(rev.IsDifferent(file, correctRevision));
        assertTrue(rev.IsDifferent(file, differentRevision));

    }     */

    @Test
    public void getAuthor() throws Exception {

        RevisionHandler rev = new RevisionHandler();
        assertEquals("kwhitmore",rev.getAuthor(file, correctRevision));
    }

	
}