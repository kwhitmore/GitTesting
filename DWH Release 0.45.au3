#AutoIt3Wrapper_au3check_parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6
#include <Excel.au3>
#include <INet.au3>
#include <IE.au3>
#include <File.au3>
#include <Array.au3>
#include <Date.au3>
#include <GUIComboBox.au3>
#include <GuiConstantsEx.au3>
#include <Constants.au3>

;Opt('MustDeclareVars', 1)

; Declare Variables

Global $RootFolder, $ReleaseName, $ReleaseVersion, $ReleaseSystem, $ReleaseType, $ReleaseDir, $Log, $Password, $Excel, $CurrentDateTime, $ScriptName, $MaxRecord
Global $oMyRet[2], $oMyError = ObjEvent("AutoIt.Error", "MyErrFunc"), $CurrentSchema, $CurrentDB, $Functionality[1000], $vssPROD, $schemaoverride, $ReleaseNotes[1000]
Global $jFileName, $jReleaseHistory, $jVSSFolder, $jVSSVersion, $jSchema, $jVSSSubfolder,$jFunctionality,$jJIRA, $jNote, $ObjectExtract

; Get input details

$RootFolder = "P:\ITDevelopment\OthersDevelopment\DataWarehouse\Release\" 

InputGUI()
	
Func ObjectExtract($db)	
	
	Local $FileName[1000], $ApplicableSchemaArray[5]
	
	;Open Release note
	$Excel = _ExcelBookOpen($RootFolder & "Release Notes - Oracle\" & $ReleaseName & ".xls")
	If @error = 2 Then
		MsgBox(0, "Error!", "Release note does not exist")
		Exit
	EndIf	
	
	; Create versioning scripts and execute check		
	If $ReleaseType <> "PROD" Then 
		CreateVersionScripts($db)
		IF $ReleaseType = "Cognos"Then
			ExecuteScript("CONTENT" & $schemaoverride, $db, "VersionCheck_" & $db & ".sql", "Version check")
		Else
			ExecuteScript("COMMON_REPOSITORY", $db, "VersionCheck_" & $db & ".sql", "Version check")			
		EndIf
	Endif

	; Pole through the release note for object name, VSS folder and VSS version	
	For $i = 2 to 1000
		
		If _ExcelReadCell($Excel, $i, 5) = "" Then
			$MaxRecord = $i - 1
			ExitLoop
		Endif
		
		; Search for field locations in Excel FileChangeDir		
		For $j = 1 to 100
			If _ExcelReadCell($Excel, 1, $j) = "" Then 
				ExitLoop
			ElseIf _ExcelReadCell($Excel, 1, $j) = "Release Note" Then 
				$jNote = $j					
			ElseIf _ExcelReadCell($Excel, 1, $j) = "Schema" Then 
				$jSchema = $j
			ElseIf _ExcelReadCell($Excel, 1, $j) = "VSS Folder" Then 
				$jVSSFolder = $j
			ElseIf _ExcelReadCell($Excel, 1, $j) = "VSS Subfolder" Then 
				$jVSSSubfolder = $j				
			ElseIf _ExcelReadCell($Excel, 1, $j) = "File Name" Then
				$jFileName = $j
			ElseIf _ExcelReadCell($Excel, 1, $j) = "VSS Version" Then 
				$jVSSVersion = $j		
			ElseIf _ExcelReadCell($Excel, 1, $j) = "Release History" Then 
				$jReleaseHistory = $j				
			ElseIf _ExcelReadCell($Excel, 1, $j) = "Functionality" Then 
				$jFunctionality = $j		
			ElseIf _ExcelReadCell($Excel, 1, $j) = "JIRA #" Then 
				$jJIRA = $j						
			EndIf
		Next
		
		; Read variables from release note		
		$FileName[$i-1] = _ExcelReadCell($Excel, $i, $jFileName)
		$VSSFolder = _ExcelReadCell($Excel, $i, $jVSSFolder) & '/' & _ExcelReadCell($Excel, $i, $jSchema) & '/' & _ExcelReadCell($Excel, $i, $jVSSSubfolder) 
		$VSSVersion = _ExcelReadCell($Excel, $i, $jVSSVersion)
		$Schema = _ExcelReadCell($Excel, $i, $jSchema)
		$ReleaseStatus = _ExcelReadCell($Excel, $i, $jReleaseHistory)		
		$Functionality[$i-1] = _ExcelReadCell($Excel, $i, $jJIRA) & ' - ' & _ExcelReadCell($Excel, $i, $jFunctionality)	
		$ReleaseNotes[$i-1] = StringReplace(_ExcelReadCell($Excel, $i, $jNote),".xls","")
		
		; Make sure file hasn't already been released to this DB		
		If StringinStr($ReleaseStatus, $db) > 0 Then 
			MsgBox(0,"Warning",$FileName[$i-1] & " already released, skipping....",2)
			ContinueLoop
		EndIf	
				
		; Extract release objects from VSS
		If $ReleaseType <> "PROD" OR $ObjectExtract = 6 Then
			If FileExists($ReleaseDir & "\ReleaseObjects\" & $FileName[$i-1]) Then
				FileSetAttrib($ReleaseDir & "\ReleaseObjects\" & $FileName[$i-1], "-R", 1) 
				FileDelete($ReleaseDir & "\ReleaseObjects\" & $FileName[$i-1])
			Endif
			RunWait("ss get """ & $VSSFolder & '/' & $FileName[$i-1] & """ -GL""" & $ReleaseDir & "\ReleaseObjects" & """ -V" & $VSSVersion)
		Endif
		
		; Check if file extracted correctly		
		$Exists = FileOpen($ReleaseDir & "\ReleaseObjects\" & $FileName[$i-1], 0)
		
		If $Exists = -1 Then
			MsgBox(0, "Error", "Unable to find " & $FileName[$i-1] & " or open for reading")
			_ExcelBookClose($Excel) 
			Exit
		EndIf
		
		FileClose($Exists)
		
		; Create and execute script		
		If $ReleaseType <> "PROD" Then 
			CreateIndividualScripts($FileName[$i-1], $db)
			$Result = ExecuteScript($Schema & $schemaoverride, $db, $FileName[$i-1] & "_" & $db & "_" & ".sql", $FileName[$i-1])
			
			; If successful write to excel sheet			
			If $Result = "Successful" Then
				If StringLen($ReleaseStatus) > 0 Then
					_ExcelWriteCell($Excel, $ReleaseStatus & ", " & $db, $i, $jReleaseHistory)
				Else
					_ExcelWriteCell($Excel, $db, $i, $jReleaseHistory)
				EndIf
			EndIf				
		Endif
		
		; Check in files to $DWH_PROD if release type is prod		
		If $ReleaseType = "PROD" AND $vssPROD = 6 Then
			$VSSFolderPROD = StringReplace($VSSFolder,"DEV","PROD")
			
			; If Project doesn't exist, create it
			$error = Runwait("ss dir """ & $VSSFolderPROD & """")
			If $error <> 0 Then
				If MSGBox(3,"Create Folder?","Folder " & $VSSFolderPROD & " does not exist, create?") = 6 Then 
					Runwait("ss create """ & $VSSFolderPROD & """")
				Else
					MSGBox(0,"Error","Folder not created, exiting....",2)
					Exit
				EndIf
			EndIf
				
			; Set working folder and project			
			Runwait("ss workfold """ & $VSSFolderPROD & """ """ & $ReleaseDir & "\ReleaseObjects""")
			Runwait("ss project """ & $VSSFolderPROD & """")
							
			; Check object exists in prod
			$error = Runwait("ss dir """ & $VSSFolderPROD & "/" & $FileName[$i-1] & """")
			If $error <> 0 Then
				
				; If object doesn't exist in prod, create it
				Runwait("ss add """ & $ReleaseDir & "\ReleaseObjects\" & $FileName[$i-1] & """ ""-cFile released in " & $ReleaseSystem)
				
				; Confirm file exists
				$error = Runwait("ss dir """ & $VSSFolderPROD & "/" & $FileName[$i-1] & """")
				If $error <> 0 Then 
					MsgBox(0,"Error","File " & $VSSFolderPROD & "/" & $FileName[$i-1] & " has not been created")
					Exit
				Endif
			Else 
				; Check file out, get dev file and check back in to prod (couldn't find an easier way as -L switch doesn't seem to work as stated in the help file)
				
				RunWait("ss checkout """ & $VSSFolderPROD & '/' & $FileName[$i-1] & """ -GL""" & $ReleaseDir & "\ReleaseObjects""" & " -c""Check out for " & $ReleaseSystem)	
				FileSetAttrib($ReleaseDir & "\ReleaseObjects\" & $FileName[$i-1], "-R", 1) 
				FileDelete($ReleaseDir & "\ReleaseObjects\" & $FileName[$i-1])
				RunWait("ss get """ & $VSSFolder & '/' & $FileName[$i-1] & """ -GL""" & $ReleaseDir & "\ReleaseObjects" & """ -V" & $VSSVersion)	
				RunWait("ss checkin """ & $VSSFolderPROD & '/' & $FileName[$i-1] & """ -GL""" & $ReleaseDir & "\ReleaseObjects""" & " -c""File released in " & $ReleaseSystem)	
				
				; confirm Dev and Prod are the same
				$error = Runwait("ss diff """ & $VSSFolder & "/" & $FileName[$i-1] & """ -V" & $VSSVersion & " """ & $VSSFolderPROD & "/" & $FileName[$i-1] & """")
				If $error <> 0 Then 
					$continue = MsgBox(3,"OK?","Differences exist between Prod and Dev for " & $VSSFolderPROD & "/" & $FileName[$i-1])
					If $continue <> 6 Then Exit
				Endif				
			EndIf		
			
			; Update Excel to say released
			If StringLen($ReleaseStatus) > 0 Then
				_ExcelWriteCell($Excel, $ReleaseStatus & ", " & $db, $i, $jReleaseHistory)
			Else
				_ExcelWriteCell($Excel, $db, $i, $jReleaseHistory)
			EndIf

		EndIf	
		
		; Append to Release script and Schema Array	
		If $ReleaseType = "PROD" Then					
			ProdReleaseScript($Schema, $FileName[$i-1])
			_ArraySearch($ApplicableSchemaArray,$Schema)
			If @error <> 0 Then _ArrayAdd($ApplicableSchemaArray, $Schema)
		EndIf		
		
	Next
	
	; Create versioning scripts if production release	
	If $ReleaseType = "PROD" Then
		If MSGBox(3,"Create versioning scripts?","Create Current_Subsystem_Versions.sql and append to the release note?") = 6 Then 
			CreateVersioningScript()
		Endif
	EndIf
	
	_ExcelBookClose($Excel) 
	If @error = 1 Then MsgBox(0,"Error","Excel file does not exist")
	If @error = 2 Then MsgBox(0,"Error","Excel file exists, overwrite flag not set")
	
	; Run version increment script and send email		
	If $ReleaseType <> "PROD" Then 
		IF $ReleaseType = "Cognos"Then
			ExecuteScript("CONTENT" & $schemaoverride, $db, "VersionIncrement_" & $db & ".sql", "Version increment")
		Else
			ExecuteScript("COMMON_REPOSITORY", $db, "VersionIncrement_" & $db & ".sql", "Version increment")			
		EndIf		
		SendMail($Log)	
	Else			
		; Close prod release scripts
		For $r = 0 to UBound($ApplicableSchemaArray,1) - 1
			$ReleaseScript = $ReleaseDir & "\ReleaseObjects\Deploy_DWH_" & $ReleaseSystem & "_" & $ApplicableSchemaArray[$r] & ".sql"
			If FileExists($ReleaseScript) Then
				FileOpen($ReleaseScript,1)
				FileWriteLine($ReleaseScript,"select to_char(sysdate,'yyyy/mm/dd hh24:mi:ss') from dual;")
				FileWriteLine($ReleaseScript,"spool off")
				FileWriteLine($ReleaseScript,"prompt commit !!")
				Fileclose($ReleaseScript)		
			EndIf
		Next		
	Endif
	
	While ProcessExists("EXCEL.exe") 
		ProcessClose("EXCEL.exe")
	wend
	
EndFunc

Func ProdReleaseScript($schema, $object)
	
	$Deployname = "Deploy_DWH_" & $ReleaseSystem & "_" & $schema
	$ReleaseScript = $ReleaseDir & "\ReleaseObjects\" & $Deployname & ".sql"
	
	If not FileExists($ReleaseScript) Then
		$error = FileOpen($ReleaseScript,2)
		If $error = -1 Then
			MsgBox(0, "Error", "Unable to create release script for " & $schema & " schema")
			Exit
		EndIf
		
		FileWriteLine($ReleaseScript, "set linesize 100")
		FileWriteLine($ReleaseScript, "set pagesize 0") 
		FileWriteLine($ReleaseScript, "set serveroutput on size 100000")
		FileWriteLine($ReleaseScript, "set define off")		
		FileWriteLine($ReleaseScript, "")
		FileWriteLine($ReleaseScript, "spool " & $Deployname & ".log")
		FileWriteLine($ReleaseScript, "select * from global_name;")
		FileWriteLine($ReleaseScript, "select user from dual;")
		FileWriteLine($ReleaseScript, "select to_char(sysdate,'yyyy/mm/dd hh24:mi:ss') from dual;")
		FileWriteLine($ReleaseScript, "")
		FileClose($ReleaseScript)	
		
	Endif
	
	; append object	
	FileOpen($ReleaseScript,1)
	FileWriteLine($ReleaseScript, "prompt " & $object)
	FileWriteLine($ReleaseScript, "@@" & $object)
	FileWriteLine($ReleaseScript, "")

Endfunc	

; Create version check and increment scripts for specified DB 

Func CreateVersionScripts($db)

	$CurrentDateTime = _NowCalc()
		
	; Open the Version Check script for editing
	
	$ScriptName = "VersionCheck_" & $db & ".sql"

	$Script = FileOpen($ReleaseDir & "\Scripts\" & $ScriptName,2)
	$Log = $ReleaseName & "_" & $db & ".log"
	WinClose($Log)

	If $Script = -1 Then
		MsgBox(0, "Error", "Unable to create version check script")
		Exit
	EndIf

	FileWriteLine($Script, "set linesize 100")
	FileWriteLine($Script, "set pagesize 0") 
	FileWriteLine($Script, "set serveroutput on size 100000")
	FileWriteLine($Script, "set define off")
	FileWriteLine($Script, "WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;")		
	FileWriteLine($Script, "")
If FileExists($ReleaseDir & "\Logs\" & $Log) Then 
	$FirstTry = False
	FileWriteLine($Script, "spool " & $ReleaseDir & "\Logs\" & $Log & " append")
Else
	$FirstTry = True
	FileWriteLine($Script, "spool " & $ReleaseDir & "\Logs\" & $Log)	
EndIf
	FileWriteLine($Script, "")
	FileWriteLine($Script, "Prompt Start time: " & $CurrentDateTime)	
	FileWriteLine($Script, "")	
	FileWriteLine($Script, "SELECT 'Database: ' || REPLACE(ora_database_name,'ASC.ALLIANZ.CO.JP') FROM dual;")
	FileWriteLine($Script, "")
	FileWriteLine($Script, "DECLARE") 
    FileWriteLine($Script, "      current_version VARCHAR2(20);") 
    FileWriteLine($Script, "      release_version VARCHAR2(20);") 
    FileWriteLine($Script, "      Inconsecutive_Version EXCEPTION;")
	FileWriteLine($Script, "BEGIN")
    FileWriteLine($Script, "      release_version := '" & $ReleaseVersion & "';")
	FileWriteLine($Script, "")  	
	FileWriteLine($Script, "      SELECT MAX(VERSION_NO)") 
	FileWriteLine($Script, "            INTO   current_version")
	FileWriteLine($Script, "            FROM   AZJP_TDWH_SUBSYSTEM_VERSIONING")
	FileWriteLine($Script, "            WHERE  SYSTEM_ID = '" & $ReleaseSystem & "';")
	FileWriteLine($Script, "")      
If $FirstTry = True Then
	FileWriteLine($Script, "            dbms_output.put_line('Release System: " & $ReleaseSystem & "');")       
	FileWriteLine($Script, "            dbms_output.put_line('Current Version: ' || current_version);")
	FileWriteLine($Script, "            dbms_output.put_line('Release Version: ' || release_version);")     	
	FileWriteLine($Script, "            dbms_output.put_line('');")
EndIf
	FileWriteLine($Script, "")            
	FileWriteLine($Script, "            IF TO_NUMBER(REPLACE(release_version,'.','')) <> TO_NUMBER(REPLACE(current_version,'.','')) + 1 THEN")
	FileWriteLine($Script, "               RAISE Inconsecutive_Version;")    
	FileWriteLine($Script, "            ELSE")
	FileWriteLine($Script, "               COMMIT;")
	FileWriteLine($Script, "               dbms_output.put_line('Version check completed');")
	FileWriteLine($Script, "            END IF;")   
	FileWriteLine($Script, "")            
	FileWriteLine($Script, "            EXCEPTION") 
	FileWriteLine($Script, "                   WHEN Inconsecutive_Version THEN")
	FileWriteLine($Script, "                   ROLLBACK;")
	FileWriteLine($Script, "                   dbms_output.put_line('Versions are not consecutive, exiting....');")      
	FileWriteLine($Script, "")            
	FileWriteLine($Script, "END;")
	FileWriteLine($Script, "/")	
	FileWriteLine($Script, "")		
	FileWriteLine($Script, "spool off")
	FileWriteLine($Script, "")
	FileWriteLine($Script, "exit")
	FileClose($Script)	
	
	; Update subsystem version
	
	$ScriptName = "VersionIncrement_" & $db & ".sql"
	$Script = FileOpen($ReleaseDir & "\Scripts\" & $ScriptName,2)

	If $Script = -1 Then
		MsgBox(0, "Error", "Unable to create version increment script")
		Exit
	EndIf
	
	FileWriteLine($Script, "set linesize 100")
	FileWriteLine($Script, "set pagesize 0") 
	FileWriteLine($Script, "set serveroutput on size 100000")
	FileWriteLine($Script, "set define off")
	FileWriteLine($Script, "WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;")		
	FileWriteLine($Script, "")
	FileWriteLine($Script, "spool " & $ReleaseDir & "\Logs\" & $Log & " append")
	FileWriteLine($Script, "")		
	
	If $ReleaseType = "PROD" Then
		FileWriteLine($Script, "INSERT INTO AZJP_TDWH_SUBSYSTEM_VERSIONING VALUES ('" & $ReleaseSystem & "','" & $ReleaseVersion & "',SYSDATE);")			
	Else
		FileWriteLine($Script, "INSERT INTO AZJP_TDWH_SUBSYSTEM_VERSIONING VALUES ('" & $ReleaseSystem & "','" & $ReleaseVersion & _
							   "',TO_DATE('" & $CurrentDateTime & "','YYYY/MM/DD HH24:MI:SS'));")
	EndIf
	FileWriteLine($Script, "commit")		
	FileWriteLine($Script, "/")			

	; Recompile invalid objects		

	FileWriteLine($Script, "set linesize 100")
	FileWriteLine($Script, "set pagesize 0") 
	FileWriteLine($Script, "set serveroutput on size 100000")
	FileWriteLine($Script, "set define off")
	FileWriteLine($Script, "WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;")		
	FileWriteLine($Script, "")
	FileWriteLine($Script, "DECLARE")
	FileWriteLine($Script, "      CURSOR Recompile IS")
	FileWriteLine($Script, "         SELECT owner,object_name,")
	FileWriteLine($Script, "                'alter ' || decode(object_type,'PACKAGE BODY','PACKAGE','TYPE BODY','TYPE',object_type) || ' ' || object_name || ' compile ' || decode(object_type,'PACKAGE BODY','BODY','TYPE BODY','BODY') AS alter_cmd")
	FileWriteLine($Script, "         FROM dba_objects where STATUS = 'INVALID' AND OWNER IN ('CUSTOMER','COMMON_REPOSITORY')")
	FileWriteLine($Script, "         ORDER By object_type;")
	FileWriteLine($Script, "BEGIN")
	FileWriteLine($Script, "      FOR records IN Recompile")
	FileWriteLine($Script, "      LOOP")
	FileWriteLine($Script, "        BEGIN")
	FileWriteLine($Script, "          EXECUTE IMMEDIATE records.alter_cmd;")
	FileWriteLine($Script, "        EXCEPTION")
	FileWriteLine($Script, "          WHEN OTHERS THEN")
	FileWriteLine($Script, "           DBMS_OUTPUT.put_line('Failed to compile ' || records.owner || '.' || records.object_name);")
	FileWriteLine($Script, "        END;")
	FileWriteLine($Script, "      END LOOP;")
	FileWriteLine($Script, "END;")
	FileWriteLine($Script, "/")
	FileWriteLine($Script, "")		
	FileWriteLine($Script, "Prompt Version increment completed")	
	FileWriteLine($Script, "")	
	FileWriteLine($Script, "spool off")
	FileWriteLine($Script, "")
	FileWriteLine($Script, "exit")
	FileClose($Script)
	
EndFunc

Func CreateIndividualScripts($Filename, $db)
	
	; Create the individual object scripts
		
	$ScriptName = $FileName & "_" & $db & "_" & ".sql"
	$Script = FileOpen($ReleaseDir & "\Scripts\" & $ScriptName,2)

	If $Script = -1 Then
		MsgBox(0, "Error", "Unable to create " & $FileName & " release script")
		Exit
	EndIf
	
	FileWriteLine($Script, "set linesize 100")
	FileWriteLine($Script, "set pagesize 0") 
	FileWriteLine($Script, "set serveroutput on size 100000")
	FileWriteLine($Script, "set define off")
	FileWriteLine($Script, "WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;")		
	FileWriteLine($Script, "")
	FileWriteLine($Script, "spool " & $ReleaseDir & "\Logs\" & $Log & " append")
	FileWriteLine($Script, "")		
	FileWriteLine($Script, "PROMPT Executing " & $FileName & ".....")
	FileWriteLine($Script, "SELECT 'Start: ' || SYSTIMESTAMP FROM DUAL;")		
	FileWriteLine($Script, "@" & $ReleaseDir & "\ReleaseObjects\" & $FileName)
	FileWriteLine($Script, "")
	FileWriteLine($Script, "commit")	
	FileWriteLine($Script, "")		
	FileWriteLine($Script, "SELECT 'End: ' || SYSTIMESTAMP FROM DUAL;")			
	FileWriteLine($Script, "Prompt " & $FileName & " completed")	
	FileWriteLine($Script, "")				
	FileWriteLine($Script, "spool off")
	FileWriteLine($Script, "")
	FileWriteLine($Script, "exit")
	FileClose($Script)		
	
EndFunc

Func ExecuteScript($Schema, $db, $Script, $Process)
	
	If $Password = "Unset" OR $CurrentSchema <> $Schema OR $CurrentDB <> $db Then 
		$Password = InputBox("DB Password","Enter the password for " & $Schema & " on " & $db)
		If @error <> 0 Then Exit
	EndIf
	
	; execute sqlplus and run script 
	
	;MsgBox(0,"sqlplus", $Schema & "/" & $Password & "@" & $db & " @""" & $ReleaseDir & "\Scripts\" & $Script & """") 	
	RunWait("sqlplus " & $Schema & "/" & $Password & "@" & $db & " @""" & $ReleaseDir & "\Scripts\" & $Script & """") 
	If @error <> 0 Then
		Msgbox(0,"Error","Error logging onto db using sqlplus")
		_ExcelBookClose($Excel) 
		Exit
	EndIf
	
	$CurrentSchema = $Schema
	$CurrentDB = $db
	
	; Check if script executed successfully
	
	$Logcontents = FileRead($ReleaseDir & "\Logs\" & $Log)
	If StringInStr($Logcontents,$Process & " completed",0,1,StringInStr($Logcontents,$CurrentDateTime)) > 0 Then
		Return "Successful"
	Else
		Msgbox(0,"Error","Error encountered during running of " & $Process & ". Please check log")
		Run("notepad.exe " & $ReleaseDir & "\Logs\" & $Log)		
		_ExcelBookClose($Excel) 
		Exit		
	EndIf
	
EndFunc

; email log file to dataextraction

Func SendMail($Log)

	$SmtpServer = "ascsvr-ex02.asc.allianz.co.jp"
	$FromName = "DataExtraction"
	$FromAddress = "Dataextraction@asc.allianz.co.jp"
	$ToAddress = "Dataextraction@asc.allianz.co.jp;tie.liu@allianz.co.jp"
	$LogDir = $ReleaseDir & "\Logs\" & $Log	
	$Subject = $Log & " has completed, please check" 	                     
	$AttachFiles = $LogDir        
	$Body = ""
	$CcAddress = ""       
	$BccAddress = ""     
	$Importance = "Normal"                  ; Send message priority: "High", "Normal", "Low"
	$Username = "******"                    ; username for the account used from where the mail gets sent - REQUIRED
	$Password = "********"                  ; password for the account used from where the mail gets sent - REQUIRED
	$IPPort = 25                            ; port used for sending the mail
	$ssl = 0                                ; enables/disables secure socket layer sending - put to 1 if using httpS
	
	; Body should include functionality and JIRA #
	For $i = 0 to UBound($Functionality) - 1
		if StringLen($Functionality[$i]) > 0 then $Body = $Body & $Functionality[$i] & @crlf 
    Next
	
	$file = FileOpen($LogDir, 0)

	; Check if file opened for reading OK
	If $file = -1 Then
		MsgBox(0, "Error", "Unable to open log file.")
		Exit
	EndIf

	$invalid_exists = false
	
	; Read in lines of text until the EOF is reached
	While 1
		$line = FileReadLine($file)
		If @error = -1 Then ExitLoop
		If StringLeft($line, 17) = "Failed to compile" Then 
			if $invalid_exists = false Then 
				$Body = $Body & @crlf
				$invalid_exists = true
			endif
			$Body = $Body & $line & @crlf 		
		endif
	Wend
	
	;MsgBox(1,"Body",$body)
	FileClose($LogDir)

	$rc = _INetSmtpMailCom($SmtpServer, $FromName, $FromAddress, $ToAddress, $Subject, $Body, $AttachFiles, $CcAddress, $BccAddress, $Importance, $Username, $Password, $IPPort, $ssl)
	If @error Then
		MsgBox(0, "Error sending message", "Error code:" & @error & "  Description:" & $rc)
	EndIf			
	
EndFunc

; Create GUI to input release details

Func InputGUI()
	Local $button_1, $group_1, $radioSIT, $radioUAT, $radioPROD, $hCombo, $msg, $ReleaseNote,$radioCLONE,$radioCOG
	
	Opt("GUICoordMode", 1)
	GUICreate("DWH Oracle Release", 410, 300)

	; Create the controls
	$button_1 = GUICtrlCreateButton("Start &Release", 30, 20, 120, 40)
	$group_1 = GUICtrlCreateGroup("Environment", 30, 90, 165, 150)
	GUIStartGroup()

	$radioDEV = GUICtrlCreateRadio("&DEV", 50, 120, 70, 20)
	$radioSIT = GUICtrlCreateRadio("&SIT", 50, 150, 70, 20)
	$radioUAT = GUICtrlCreateRadio("&UAT", 50, 180, 60, 20)
	$radioPROD = GUICtrlCreateRadio("&PROD", 120, 120, 60, 20)
	$radioCLONE = GUICtrlCreateRadio("&Clone", 120, 150, 60, 20)	
	$radioCOG = GUICtrlCreateRadio("&Cognos", 120, 180, 60, 20)	
	$group_2 = GUICtrlCreateGroup("Release Note", 220, 90, 165, 100)
	GUIStartGroup()
	$hCombo = GUICtrlCreateCombo("", 240, 120, 140, 296)

	; Show the GUI
	GUISetState()
	
	; Add files
	_GUICtrlComboBox_BeginUpdate($hCombo)
	_GUICtrlComboBox_AddDir($hCombo, $RootFolder & "\Release Notes - Oracle\*.xls")
	_GUICtrlComboBox_EndUpdate($hCombo)

	; Get user Input
	
	While 1
		$msg = GUIGetMsg()
		Select
			Case $msg = $GUI_EVENT_CLOSE
				Exit
			Case $msg = $radioDEV
				$ReleaseType = "DEV"				
			Case $msg = $radioSIT
				$ReleaseType = "SIT"
			Case $msg = $radioUAT
				$ReleaseType = "UAT"
			Case $msg = $radioPROD
				$ReleaseType = "PROD"
			Case $msg = $radioCLONE
				$ReleaseType = "CLONE"			
			Case $msg = $radioCOG
				$ReleaseType = "Cognos"						
			Case $msg = $hCombo
				$ReleaseNote = GUICtrlRead($hCombo)
			Case $msg = $button_1
				If $ReleaseType = "" Then 
					MsgBox(0,"Missing Env","No environment selected. Please select an environment")
				ElseIf $ReleaseNote = "" Then 
					MsgBox(0,"Missing Release Note","No release note selected. Please select a release note")	
				Else
					$ReleaseVersion = StringReplace(StringMid($ReleaseNote,StringInStr($ReleaseNote,"_")+1),".xls","")
					$ReleaseSystem = StringLeft($ReleaseNote,StringInStr($ReleaseNote,"_")-1)
					
					; Validate Strings
										
					If StringLen($ReleaseVersion) <> 7 Then
						MsgBox(0,"Error","Unknown Release Version: " & $ReleaseVersion)
					Else
						$continue = Msgbox(4,"Release Details","Release Version: " & $ReleaseVersion & @crlf & "Release System: " & _
						$ReleaseSystem & @crlf & "Release Type: " & $ReleaseType)
						If $continue = 6 Then 
							
							; Define Variables

							$ReleaseName = $ReleaseSystem & "_" & $ReleaseVersion
							$ReleaseDir = $RootFolder & $ReleaseSystem & "\" & StringMid($ReleaseVersion,1,StringinStr($ReleaseVersion,".",0,2)-1) & "\" & StringRight($ReleaseVersion,2)	
							$Password = "Unset"
								
							; Create Release Directories

							DirCreate($ReleaseDir)
							DirCreate($ReleaseDir & "\ReleaseObjects")
							DirCreate($ReleaseDir & "\Logs")
							DirCreate($ReleaseDir & "\Scripts")							
							
							ExtractDBNames()
						Else
							Exit
						Endif 
					EndIf
					
				EndIf
		EndSelect
	WEnd
	
EndFunc 

; Open IE, browse to confluence and extract text from Environment page

Func ExtractDBNames()
	
	; check if can connect to confluence page
	Local $db

	$oIE = _IECreate ("http://tracker.asc.allianz.co.jp:8090/confluence/dashboard.action", 0, 0)
	_IELoadWait ($oIE)
	_IENavigate ($oIE, "http://tracker.asc.allianz.co.jp:8090/confluence/display/MEISDEV/MEISTER+Environment+Information")
	$sText = _IEBodyReadText ($oIE)
	_IEQuit($oIE)

	If $ReleaseType = "CLONE" Then
		$searchString = "Prod Clone"
	Else	
		$searchString = $ReleaseType & " Environment"
	EndIf

	; Browse confluence for db environments

	For $i = 1 to 100
		$Env = StringMid($sText, StringinStr($sText,$searchString,0,$i) - 20,20)
		
		If StringinStr($Env,"MEIS") > 0 Then $db = StringMid($Env,StringinStr($Env,"MEIS"))	
		If StringinStr($Env,"OPUS") > 0 Then $db = StringMid($Env,StringinStr($Env,"OPUS"))		
		If StringinStr($Env,"DWH") > 0 Then $db = StringMid($Env,StringinStr($Env,"DWH"))	
		If StringinStr($Env,"GIOS") > 0 Then $db = StringMid($Env,StringinStr($Env,"GIOS"))		
		If StringinStr($Env,"COG") > 0 Then $db = StringMid($Env,StringinStr($Env,"COG"))				
			
		$db = StringLeft($db,StringinStr($db," ")-1)
		
		;If $Pos > 0 Then msgbox(0,"Variables","$Pos: " & $Pos & @crlf & "$Env: " & $Env & @crlf & "$db: " & $db)	
		If stringlen($db) > 0 Then 
			If $ReleaseType = "PROD" Then
				$answer = 6
				$ObjectExtract = MSGBox(3,$ReleaseType & " Extract","Extract objects for " & $db & "?")
				$vssPROD = MSGBox(3,"Check in to VSS PROD?","Check files into VSS DWH_PROD?")
				; check if Deploy scripts exist
				$Deployscripts = $ReleaseDir & "\ReleaseObjects\Deploy_DWH_" & $ReleaseSystem & "*.sql"
				If FileExists($Deployscripts) Then
					If MSGBox(3,"Delete Existing scripts?","Delete Existing Deploy scripts for this release?") = 6 Then
						FileDelete($Deployscripts)
						If FileExists($Deployscripts) Then 
							Msgbox(4096,"Error","Issue deleting existing deploy scripts, exiting....")
						    Exit
						EndIf
					EndIf
				Endif				
			Else
				$answer = MSGBox(3,$ReleaseType & " Release","Release to " & $db & "?")	
			EndIf
			If $answer = 2 Then Exit
			If $db = "COGDEV01" AND MSGBox(3,"SIT Release?","Is this an SIT release?") = 6 Then 
				$schemaoverride = "_SIT01"
			ElseIf $db = "TKCOG2WT01" Then 
				$schemaoverride = "_UAT02"	
			Else
				$schemaoverride = ""
			EndIf
			If $answer = 6 Then ObjectExtract($db)
		EndIf
	Next
EndFunc	

Func _INetSmtpMailCom($s_SmtpServer, $s_FromName, $s_FromAddress, $s_ToAddress, $s_Subject = "", $as_Body = "", $s_AttachFiles = "", $s_CcAddress = "", $s_BccAddress = "", $s_Importance="Normal", $s_Username = "", $s_Password = "", $IPPort = 25, $ssl = 0)
    Local $objEmail = ObjCreate("CDO.Message")
    $objEmail.From = '"' & $s_FromName & '" <' & $s_FromAddress & '>'
    $objEmail.To = $s_ToAddress
    Local $i_Error = 0
    Local $i_Error_desciption = ""
    If $s_CcAddress <> "" Then $objEmail.Cc = $s_CcAddress
    If $s_BccAddress <> "" Then $objEmail.Bcc = $s_BccAddress
    $objEmail.Subject = $s_Subject
    If StringInStr($as_Body, "<") And StringInStr($as_Body, ">") Then
        $objEmail.HTMLBody = $as_Body
    Else
        $objEmail.Textbody = $as_Body & @CRLF
    EndIf
    If $s_AttachFiles <> "" Then
        Local $S_Files2Attach = StringSplit($s_AttachFiles, ";")
        For $x = 1 To $S_Files2Attach[0]
            $S_Files2Attach[$x] = _PathFull($S_Files2Attach[$x])
            ConsoleWrite('@@ Debug(62) : $S_Files2Attach = ' & $S_Files2Attach & @LF & '>Error code: ' & @error & @LF) ;### Debug Console
            If FileExists($S_Files2Attach[$x]) Then
                $objEmail.AddAttachment ($S_Files2Attach[$x])
            Else
                ConsoleWrite('!> File not found to attach: ' & $S_Files2Attach[$x] & @LF)
                SetError(1)
                Return 0
            EndIf
        Next
    EndIf
    $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
    $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserver") = $s_SmtpServer
    If Number($IPPort) = 0 then $IPPort = 25
    $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = $IPPort
    ;Authenticated SMTP
    If $s_Username <> "" Then
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate") = 1
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendusername") = $s_Username
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendpassword") = $s_Password
    EndIf
    If $ssl Then
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpusessl") = True
    EndIf
    ;Update settings
    $objEmail.Configuration.Fields.Update
    ; Set Email Importance
    Switch $s_Importance
        Case "High"
            $objEmail.Fields.Item ("urn:schemas:mailheader:Importance") = "High"
        Case "Normal"
            $objEmail.Fields.Item ("urn:schemas:mailheader:Importance") = "Normal"
        Case "Low"
            $objEmail.Fields.Item ("urn:schemas:mailheader:Importance") = "Low"
    EndSwitch
    $objEmail.Fields.Update
    ; Sent the Message
    $objEmail.Send
    If @error Then
        SetError(2)
        Return $oMyRet[1]
    EndIf
    $objEmail=""
EndFunc   ;==>_INetSmtpMailCom
;
;
; Com Error Handler
Func MyErrFunc()
    $HexNumber = Hex($oMyError.number, 8)
    $oMyRet[0] = $HexNumber
    $oMyRet[1] = StringStripWS($oMyError.description, 3)
    ConsoleWrite("### COM Error !  Number: " & $HexNumber & "   ScriptLine: " & $oMyError.scriptline & "   Description:" & $oMyRet[1] & @LF)
    SetError(1); something to check for when this function returns
    Return
EndFunc   ;==>MyErrFunc	

Func CreateVersioningScript()
	
	$ReleaseFolder = $ReleaseDir & "\ReleaseObjects"	
	$VSSFolder = "$/DWH_DEV/COMMON_REPOSITORY/Scripts"
	$TempFile = _TempFile($ReleaseFolder,"Ver_",".txt")
	$ScriptName = "Current_Subsystem_Versions.sql"
	$PropertiesBatch = _TempFile("C:\Temp","Out_",".bat")
	
	; Remove duplicates

	$uniqueRelNotes = _ArrayUnique($ReleaseNotes) 

	; Set working folder and project	

	Runwait("ss project " & $VSSFolder)
	Runwait("ss workfold """ & $RootFolder & """")

	; Check out versioning script

	RunWait("ss checkout """ & $VSSFolder & '/' & $ScriptName & """ -GL""" & $ReleaseFolder & """ -c""Check out for " & $ReleaseName)	
	FileSetAttrib($ReleaseFolder & "\" & $ScriptName, "-R", 1) 
	FileDelete($ReleaseFolder & "\" & $ScriptName)

	; Create Current_Subsystem_Versions.sql 

	$Script = FileOpen($ReleaseFolder & "\" & $ScriptName,2)

	If $Script = -1 Then
		MsgBox(0, "Error", "Unable to create " & $ScriptName & " release script")
		Exit
	EndIf

	FileWriteLine($Script, "set linesize 100")
	FileWriteLine($Script, "set pagesize 0") 
	FileWriteLine($Script, "set serveroutput on size 100000")
	FileWriteLine($Script, "set define off")
	FileWriteLine($Script, "WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;")		
	FileWriteLine($Script, "")		
	FileWriteLine($Script, "PROMPT Beginning update of subsystem versions")
	FileWriteLine($Script, "")

	; Extract subsystems and release versions
			
	For $i = 1 to UBound($uniqueRelNotes) - 1
		if StringLen($uniqueRelNotes[$i]) > 0 then
			
			$SubsystemVersion = StringMid($uniqueRelNotes[$i],StringInStr($uniqueRelNotes[$i],"_")+1)
			$SubsystemSystem = StringLeft($uniqueRelNotes[$i],StringInStr($uniqueRelNotes[$i],"_")-1)		

			If StringLen($SubsystemSystem) > 20 Then 
				MsgBox(0,"Subsystem length error","Length of subsystem name """ & $SubsystemSystem & """ is more than 20 chars. It will not be added to the subsystem version script")
			Else
				FileWriteLine($Script, "PROMPT Inserting " & $SubsystemSystem & " version " & $SubsystemVersion) 
				FileWriteLine($Script, "INSERT INTO AZJP_TDWH_SUBSYSTEM_VERSIONING VALUES ('" & $SubsystemSystem & "','" & $SubsystemVersion & "',SYSDATE);")
				FileWriteLine($Script, "") 
			Endif
		EndIf
	Next			
		
	FileWriteLine($Script, "PROMPT Update of subsystem versions completed")	
	FileClose($Script)	

	; Check script in to VSS

	Runwait("ss checkin """ & $VSSFolder & '/' & $ScriptName & """ -GL""" & $ReleaseFolder & """ -c""File released in " & $ReleaseName & """")

	; Get version number of script

	$output = FileOpen($PropertiesBatch, 2)
	FileWrite($output,"ss properties " & $VSSFolder & "/" & $ScriptName & " >""" & $TempFile & """")
	fileclose($output)
	Runwait($PropertiesBatch)
	FileDelete($PropertiesBatch)

	$file = Fileopen($TempFile,0)
	If $file = -1 Then
		MsgBox(0, "Error", "Unable to open file.")
		Exit
	EndIf

	While 1
		$line = FileReadLine($file)
		If @error = -1 Then 
			ExitLoop
		ElseIf StringInStr($line,"Version:",1) > 0 Then
			$ScriptVersion = StringMid($line,12,StringInStr($line," ",0,1,12))
			;MsgBox(0, "$ScriptVersion", $ScriptVersion)
			ExitLoop
		Endif
	Wend

	FileClose($file)
	FileDelete($TempFile)

	;~ ; Append to end of Production release note

	_ExcelWriteCell($Excel, "COMMON_REPOSITORY", $MaxRecord + 1, $jSchema) 
	_ExcelWriteCell($Excel, "$/DWH_DEV", $MaxRecord + 1, $jVSSFolder) 
	_ExcelWriteCell($Excel, "Scripts", $MaxRecord + 1, $jVSSSubfolder) 
	_ExcelWriteCell($Excel, $ScriptName, $MaxRecord + 1, $jFileName) 
	_ExcelWriteCell($Excel, $ScriptVersion, $MaxRecord + 1, $jVSSVersion) 
	_ExcelWriteCell($Excel, "Update Subsystem Versions", $MaxRecord + 1, $jFunctionality) 
	
	ProdReleaseScript("COMMON_REPOSITORY", $ScriptName)

EndFunc
