package liquibase.parser.extension;

import java.io.*;
import java.util.HashMap;
import java.util.Map;

import liquibase.exception.LiquibaseException;
import liquibase.logging.LogFactory;
import org.tmatesoft.svn.core.io.SVNRepository;
import org.tmatesoft.svn.core.auth.ISVNAuthenticationManager;
import org.tmatesoft.svn.core.*;
import org.tmatesoft.svn.core.internal.io.svn.SVNRepositoryFactoryImpl;
import org.tmatesoft.svn.core.io.SVNFileRevision;
import org.tmatesoft.svn.core.wc.*;

import javax.sound.sampled.Line;
import javax.swing.plaf.basic.BasicSplitPaneUI;

public class RevisionHandler {

	/*
	 * Constructor calls setup for SVNRepository Factory
	 */
	
    public RevisionHandler() {
        SVNRepositoryFactoryImpl.setup(); 
    }

    /*
     * Update of working copy file to revision specified
     */
    
    public static void Update( File wcPath , SVNRevision updateToRevision, SVNDepth updateDepth, boolean Obstructions, boolean IsSticky) throws LiquibaseException {

    	SVNClientManager ClientManager = SVNClientManager.newInstance();    	
    	SVNUpdateClient updateClient = ClientManager.getUpdateClient();
        long revisionNo = 0;

        updateClient.setIgnoreExternals( false );

        try {
            revisionNo = updateClient.doUpdate( wcPath, updateToRevision, updateDepth, Obstructions, IsSticky );
        }
        catch (SVNException svne) {
            LogFactory.getLogger().severe("Failed to update revision: " + revisionNo);
            throw new LiquibaseException(svne.getErrorMessage().toString())  ;
        }
    }
    
    /*
     * Return diff via System.out between working copy and revision 
     */   
    
    public String Diff( File wcPath , SVNRevision compRevision) {

        ByteArrayOutputStream output = new ByteArrayOutputStream();
    	SVNClientManager ClientManager = SVNClientManager.newInstance();    	
    	SVNDiffClient diff = ClientManager.getDiffClient();
    	diff.setIgnoreExternals( false );

        try {
    	    diff.doDiff(wcPath, SVNRevision.UNDEFINED, SVNRevision.WORKING, compRevision, SVNDepth.INFINITY, true, output, null);
        }
        catch (SVNException svne) {
            System.out.println(svne.getErrorMessage());
            svne.printStackTrace();
        }
        return output.toString();
    }

    /*
     * Return true if difference returned from dodiff method
     */

    public boolean IsDifferent( File wcPath , SVNRevision compRevision) {

    	RevisionHandler rev = new RevisionHandler();

        if (rev.Diff(wcPath, compRevision).length() > 0) {
            return true;
        }
        else {
            return false;
        }
    }

    public void UpdateCompleted ( File wcPath , SVNRevision revisionNo) throws InterruptedException {

    	RevisionHandler rev = new RevisionHandler();

        try {
            while (rev.IsDifferent(wcPath, revisionNo)) {
                Thread.sleep(2);
            }
        }
        catch (InterruptedException e) {
            LogFactory.getLogger().severe(e.toString());
            throw e;
        }
        LogFactory.getLogger().info(wcPath.getPath() + " updated to revision " + revisionNo.getNumber());
    }


   public String getAuthor( File wcPath , SVNRevision revision) {

     SVNClientManager clientManager = SVNClientManager.newInstance();
     SVNWCClient wcClient = clientManager.getWCClient();

     try {
       SVNInfo info = wcClient.doInfo(wcPath, revision);
       return info.getAuthor();
     }
     catch (SVNException e) {
       e.printStackTrace();
       return "Unknown Author";
     }
   }
}
