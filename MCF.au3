; ===============================================================================================================================
; Title .........: MetaCode File (MCF) library
; AutoIt Version : 3.3.12
; Description ...: processes CodeScanner ouput: structural and content files
; Author.........: A.R.T. Jonkers (RTFC)
; Release........: 1.3
; Latest revision: 16 Aug 2014
;
; License........: free for personal use; free distribution allowed provided
;							the original author is credited; all other rights reserved.
; Tested on......: W7Pro/64
; Forum Link.....: www.autoitscript.com/forum/topic/155537-mcf-metacode-file-udf/
; Dependencies...: CodeScanner, by RTFC, see www.autoitscript.com/forum/topic/153368-code-scanner/
;						 ReadCSDataDump, by RTFC (part of CodeScanner package)
;						 MCFinclude, by RTFC (itself includes AES.au3, by Ward)
; Acknowledgements: Ward, for AES.au3, included in MCFinclude.au3 (IMPORTANT: see AES patch instructions in MCFinclude.au3 remarks)
;============================================================================================
; MCF UDFs
;
; * Input-related:
;	_CreateSingleBuild	preprocess arrays, call _WriteMCF0(), save new arrays
;	_RemoveOrphans			remove orphaned globals and/or UDF defs (multi-pass, may take long)
;	_MCWords					replace code by MetaCode (NB also called by CodeScanner)
;	_WriteMCF0				generate MCF0.txt from MCF#.txt (#=1-N), without redundancies (recursive)
;
; * Structure-altering:
;	_IndirectMCF			replace direct variable assignments with equivalent calls
;	_PhraseMCF				replace all conditionals and calls with phrases
;
; * Content-altering:
;	_EncryptArrays			fill arrays stringEncryp and phrasesNew, calls _EncryptEntry
;	_EncryptEntry			encrypt an inputstring with a given keytype, add fixed-key wrapper if desired
;	_ObfuscateArrays		creates hex template, calls _ObfuscateNames on arrays variables, functions, and strings
;	_ObfuscateNames		given a source array, fills destination array
;	_TranslateVarsInStrings	replaces variable names (without "$") inside strings with their (user-predefined) translation
;
; * Output-related:
;	_BackTranslate			encode MCF0 with *original* CS-extracted datasets (no processing)
;	_CreateNewScript		encode MCF0 with *New[] arrays (no processing except what user externally changed in *New[] arrays)
;	_RebuildScript			encode MCF0 with altered? structure and altered? content arrays
;	_EncodeMCF				MCF Script Writer
;	_ReplaceMCinArray		replace MetaCode with code in arrays (strings, phrases)
;
; * Auxiliary:
;	_CallStack_Pop			update call stack
;	_CallStack_Push		update call stack
;	_ClearArrays			clear all buffers (any previous processing is lost)
;	_FillCSpath				check/set CS_dumppath
;	_FillSkipRegExpStrings()	; list RegeExp pattern strings for exclusion in various procedures
;	_PrepMCenvironment	call _FillCSpath(), (re)load all arrays from files
;	_PrepMCFinclude		store obfuscated _MCFCC calls for insertion into target
;	_RandomHex				generate a random hex string of given length
;	_ShowMCFile				run Notepad on currently processed file
;	_TestCCKey				check CCkeyp[] def
;	_ValidPrefix			XLATB table
;
;============================================================================================
; Summary (Wotsit?)
;
; MetaCode processing separates a script's CONTENT from its STRUCTURE,
;	allowing you to change one independently of the other, then rebuild the script
;
; These UDFs take CodeScanner metadata output (in *.CS_DATA\ output dir) to create:
; 	- a Single-Build MetaCode File called MCF0.txt
;	- an AutoIt script called MCF0.au3, based upon MCF0.txt and the CS_DATA arrays
;	- a copy of MCF0.au3 called MCF0test.au3, in the original source directory,
;		for testing (provided no errors occurred in processing)
;
; These UDFs are to be called from other scripts, notably:
;	-	CodeCrypter, by RTFC
;	-	CodeScanner, by RTFC
;
;============================================================================================
;	Application (WhyBother?)
;
; Short answer: MetaCode!
; Longer answer: code condensing, translation, obfuscation, encryption, possibly even cross-compilation...
; Better answer: see the MetaCode tutorial in the MetaCode thread in the AutoIt Exmple Scripts Forum
;
; Input: CodeScanner output directory (full path)
;			(run CodeScanner first with setting WriteMetaData=True)
;
; Outputs:
;		* Files: MCF0.txt, MCF0.au3
;		* many arrays, stored as text files in CodeScanner's DataDump subdirectory
;			NB original CodeScanner arrays are retained as <name>_CS.txt
;
;============================================================================================
; Remarks
;
; * please read the MetaCode tutorial in the MetaCode (MCF.au3) thread in the AutoIt Example Scripts Forum
;
; * Processing sequence:
;	1.	<myscript>.au3	+ #includes		=> Codescanner				=> MCF#.txt (MetaCode: 1-myscript, 2-N = #includes)
;	2.	MCF1.txt			+ MCF2-N.txt	=> _CreateSingleBuild()	=> MCF0.txt (MetaCodeFile zero)
;	3.	MCF0.txt								=> _BackTranslate()		=> MCF0.au3	(AutoIt script from MetaCode)
;		NB if BackTranslate is called without a prior call to _CreateSingleBuild(),
;			BackTranslate will itself first call _CreateSingleBuild()
;
; * MCF0.txt is the MetaCode equivalent of the complete source, in which:
; 		- all Autoit calls are replaced by, and refer to array entry:
;				{funcA#}  = $AU3Functions[#]  (complete set)
; 		- all UDF calls and defined names are replaced by, and refer to, array entry:
; 				{funcU#}  = $functionsUsed[#] (for active subset, see $functionsCalled[])
; 		- all variables are replaced by, and refer to array entry:
;				{var#}    = $variablesUsed[#]
; 		- all strings are replaced by, and refer to array entry:
;				{string#} = $stringsUsed[#]
; 		- all macros are replaced by, and refer to array entry:
;				{macro#}  = $macros[#]
;		- each executable line has a comment suffix specifying:
;				{file#}   = $includes[#] (original source files)
;				{line#}   = line number in original source file
;		- each global definition has an additional comment suffix specifying:
; 				{ref#}    = $references[#]
;
; * Why create a Single-Build?
; 		MCF0 is a portable, condensed MCF interpretation of the analysed source:
;		- without #includes (all required parts are placed in main script, the rest is out)
;		- without redundant UDF definitions (set $MCF_SKIP_UNCALLED_UDFS=False to keep them)
;		- without redundant globals (set $MCF_REMOVE_ORPHANS=False to keep them)
;
; * Why use BackTranslation?
;		1. to create a portable (single-source), executable script
;		2. to TEST whether the MetaCode version works, while being able to compare
;			with the original source before the former is altered
;
; * BackTranslation creates MCF0.au3; if no errors, it is also copied to
;		..\MCF0test.au3, because(!) its proper functioning may rely on
;		local resources, relative paths, etc.
;
; * once generated, load MCF0test.au3 in Scite and run AU3Check;
;		if errors, try _CreateSingleBuild() with
;			$MCF_SKIP_UNCALLED_UDFS=False, and/or
;			$MCF_REMOVE_ORPHANS=False (MCF0.au3 may become larger)
;		if no errors, run it to see whether it behaves as expected;
;		if so, you're in business (see MetaCode tutorial doc for some powerful applications)
;
; * MCF does not need CodeScanner's full DataDump; setting WriteMetaCode=True in
;		CodeScanner will automatically output only those arrays needed for MCFs
;
; * Using Keywords "Execute","Assign","Eval","IsDeclared" results in a flagged
;		Self-Modifying Code Issue in BackTranslation, but MCF0.au3 is still
;		generated and may work (try with $MCF_SKIP_UNCALLED_UDFS=False and $MCF_REMOVE_ORPHANS=False)
;
; * Optional structure alterations:
;	- Indirection:	replaces var assignments with indirect calls (more lines encrypted)
;		before: 	$varA = $varB
;		after:	_VarIsVar($varA,$varB)	; UDF def is in MCFinclude.au3
;	- Phrasing:		extracts conditionals and calls (faster decryption; default on)
;		before: 	{var}={funcU}(funcA}({string},$var},{macro}),{string},0,1,False)
;		after:	{var}={phrase}
;
; * Optional content alterations, in sequence:
;	- Linguistic translation:		YOU replace content of text file(s) *Transl.txt
;	- Obfuscation:						vars, UDFs, or both; affects strings that contain these automatically
;	- Encryption:						can affect all arrays, including phrases*[]
;	Final source data are stored in arrays *New[]
;
; * MCF content post-processing; which operation affects what, and in what order?
;
;		MetaCode		Translation	->	Obfuscation	->	Encryption
;		-------------------------------------------------------
;		AU3 call		-					-					YES (phrased)
;		UDF 			YES				YES				YES (phrased)
;		variable		YES				YES				-
;		string		YES				-					YES
;		macros		-					-					YES (phrased)
;		phrase		-					-					YES
;
; * Quick language Translation (after calling CreateSingleBuild):
;	1. dump stringsUsed.txt into Google Translate, save result in stringsTransl.txt
;			Note: translate UI strings only, not DllCall and WinAPI arguments, etc.
;	2. call _RebuildScript($path,True) with setting $MCF_TRANSLATE_STRINGS=True
;	3. Done.
;	NB if you want to translate names of variables and UDFs, edit their *Transl.txt files.
;
; * Quick Obfuscation (after calling CreateSingleBuild):
;	1. call _RebuildScript($path,True) with settings:
;			$MCF_OBFUSCATE_UDFS	= True
;			$MCF_OBFUSCATE_VARS	= True
;	2. Done.
;
; * Quick Encryption:
;	1. edit MCFinclude if you wish to define a new keytype, or choose the one(s) you want
;	2. add MCFinclude to your target script (anything below this #include line will by default be encrypted)
;	3. run CodeScanner on the target script (CodeScanner data dump subdirectory = $path used below)
;	4. call CreateSingleBuild($path, True)
;	5. call MCFCC_init(<selected_keytype>)		; UDF is in MCFinclude.au3, itself included in MCF.au3
;	6. call _RebuildScript($path,True) with settings:
;			$MCF_ENCRYPT_PHRASES	= True
;			$MCF_ENCRYPT_STRINGS	= True
;	7. Done.
;	(of course, CodeCrypter would do most of this automatically for you...)
;
; * Encryption replaces phrases, i.e.:
;		- conditionals (code following If/While/Until)
;		- calls (native AutoIt and UDFs)
;		- macros
;		with "Execute(_MCFCC(<encrypted code>))"
;	NB	Each of these three can be switched off individually by setting:
;		$MCF_REPLACE_* = False (* = VARS, UDS, MACROS) prior to calling _PhraseMCF()
;		NB always set these booleans back to True before calling _EncodeMCF()
;
; * setting UDF parameter $force_refresh=True => first reload all arrays from file
;
; * do not set $MCF_WRITE_COMMENTS = False PRIOR to creating the final output;
;		some UDFs require specific MCF-generated comments as location markers
;
; * you can use any encryption algorithm you want.
;		Steps for changing the encryption algorithm:
;		- rename a copy of MCFinclude.au3 as <newname>
;		- remove #include AES.au3 from <newname>
;		- if your algorithm requires some other external #include, add this at the top of <newname>
;		- in <newname>'s UDF _MCFCC(), replace the decryption call
;		- edit <newname>'s Global $MCFinclude = "MCFinclude.au3" => "<newname>"
;		- change in MCF.au3: #include "MCFinclude.au3" => "<newname>"
;		- change in MCF.au3: replace all encryption calls in UDF: _EncryptEntry()
;		- Test, test, and test, then test again (and do more tests). Then test.
;
;============================================================================================
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters= -q -w 1 -w 2 -w- 4 -w 6 -w- 7
#AutoIt3Wrapper_UseX64=N
#AutoIt3Wrapper_res_Compatibility=Vista,Windows7
#AutoIt3Wrapper_UseUPX=Y
#AutoIt3Wrapper_Run_Obfuscator=N
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#NoTrayIcon
#include-once
#include <Crypt.au3>
#include <Date.au3>
#include <File.au3>
#include <Math.au3>
#include <Misc.au3>
#include <String.au3>

#include ".\readCSdatadump.au3"		; part of the CodeScanner package
#include ".\MCFinclude.au3"			; default MCFinclude, using AES.au3, by Ward

#region Globals

; input-related booleans
Global $MCF_CREATE_SINGLE		=True
Global $MCF_BACKTRANSLATE		=False
Global $MCF_CREATE_NEW			=False

; content-altering booleans
Global $MCF_TRANSLATE			=False	; enable $MCF_TRANSLATE_* settings
Global $MCF_TRANSLATE_STRINGS	=False	; encode with $stringsTransl (auto-updated with $variablesTransl and $functionsTransl)
Global $MCF_TRANSLATE_UDFS		=False	; encode with $functionsTransl
Global $MCF_TRANSLATE_VARS		=False	; encode with $variablesTransl

Global $MCF_OBFUSCATE			=False	; enable $MCF_OBFUSCATE_* settings
Global $MCF_OBFUSCATE_UDFS		=False	; encode with $functionsObfusc
Global $MCF_OBFUSCATE_VARS		=False	; encode with $variablesObfusc

Global $MCF_ENCRYPT				=False	; enable $MCF_ENCRYPT_* settings
Global $MCF_ENCRYPT_PHRASES	=False	; Execute(decrypt(encrypted call or conditionals))
Global $MCF_ENCRYPT_STRINGS	=False	; decrypt(encrypted string)
Global $MCF_ENCRYPT_NESTED		=False	; T=encrypt(encrypt(code,dynamickey),statickey), F=encrypt(code,dynamickey)
Global $MCF_ENCRYPT_SUBSET		=False	; use $subset_definition to determine which lines will be encrypted
Global $MCF_ENCRYPT_SHUFFLEKEY=False	; T=select a random keytype from a predefined range of keys, F= single dynamic key

; structure-altering booleans
Global $MCF_SKIP_UNCALLED_UDFS=True		; affects WriteMCF0() (part of CreateSingleBuild)
Global $MCF_REMOVE_ORPHANS		=True		; enable recursive scan for orphaned global vars and UDFs
Global $MCF_INDIRECTION			=False	; replace direct assignments with indirect UDF calls (enhances encryption coverage)
Global $MCF_PHRASING				=False	; auto-True if $MCF_ENCRYPT=True

; encoding booleans (always keep all True, unless testing MCF.au3 itself)
Global $MCF_REPLACE_AUFUNCS	=True
Global $MCF_REPLACE_UDFS		=True
Global $MCF_REPLACE_VARS		=True
Global $MCF_REPLACE_STRINGS	=True
Global $MCF_REPLACE_MACROS		=True
Global $MCF_REPLACE_PHRASES	=True
Global $MCF_WRITE_COMMENTS		=True		; default = Not($MCF_ENCRYPT); affects final output only

; global arrays
Global $CallStack[1]
Global $phrases[1]
Global $phrasesUsed[1]
Global $phrasesUDF[1]
Global $phrasesEncryp[1]
Global $phrasesNew[1]
Global $strings1[1]
Global $strings2[1]
Global $globalsOrphaned[1]
Global $already_included[1]
Global $fileIncludeOnce[1]
Global $validprefix[256]
Global $namesUsed[1]
Global $SelectedUDFname[1]
Global $SelectedUDFstatus[1]
Global $skipRegExpStrings[1]

; internal call tags and parameters
Global $_MCFCC					=""	; (M)eta(C)ode(F)ile, (C)ode(C)rypter call
Global $_MCFCCXA				=""	; e(X)ecute once
Global $_MCFCCXB				=""	; e(X)ecute twice
Global $decryption_key		=""
Global $CCkeytype				=3		; see MCFinclude.au3 for key definition
Global $CCkeyshuffle_start	=2		; do not set < 1 (0 = fixedkey)
Global $CCkeyshuffle_end	=5		; do not set > Ubound(£CCkey)-1
Global $subset_definition	=0.5	; <1 = percentage (random), >1 = ccycled (1 in N lines)

; miscellaneous
Global $CCGUI,$INIvars
Global $ShowErrorMsg	=True
Global $showProgress	=True	; can also be defined as global in whatever is calling these UDFs
Global $MCF_file_ID	=0
Global $section1_lastline=0
Global $section2_lastline=0
Global $section1_lastphrase=0
Global $section2_lastphrase=0
Global $Obfstringwidth=16
Global $fhout			=0
Global $totalfiles	=0
Global $totalines		=0
Global $CS_dumppath	=".\"
Global $dumptag		=""
Global $errortag		="*** ERROR: "			; inserted in MCF0.au3 at each failed BackTramslation location
Global $timestamptag	="was generated on "	; inserted in MCF0.au3  (should not be empty)
$CallStack[0]=@ScriptName
Global $uselogfile=False				; create a log file? (used only in cmdline mode)
Global $fhlog=""

#endregion Globals

#region Input-related

Func _CreateSingleBuild($path,$force_refresh=False)		; build MCF0.txt, stripping all redundant parts
; parsed $path = CodeScanner DataDump path

	$procname="_CreateSingleBuild"
	_CallStack_Push($procname)

	If $uselogfile Then _FileWriteLog($fhlog,$procname & " started.")

	If _PrepMCenvironment($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,False)

	; reload original CodeScanner arrays
	If $showProgress=True Then SplashTextOn("","Preparing MCF0...",250,40,-1,-1,1+32,"Verdana",10)

	Global $stringsUsed		=$stringsUsed_CS
	Global $variablesUsed	=$variablesUsed_CS
	Global $functionsUsed	=$functionsUsed_CS
	Global $macrosUsed		=$macrosUsed_CS
	Global $functionsCalled	=$functionsCalled_CS
	Global $FuncEqualsString[1]
	SplashOff()

	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": processing strings...")
	For $rc=1 To $stringsUsed[0]
		If $showProgress=True And Mod($rc,500)=0 Then _
			SplashTextOn("","Processing Strings (" & _Min(99,Floor(100*$rc/$stringsUsed[0])) & "% done)...",300,40,-1,-1,1+32,"Verdana",10)
		If StringLen($stringsUsed[$rc])<3 Then ContinueLoop	; two chars used for quotes
		$curstring=StringTrimLeft(StringTrimRight($stringsUsed[$rc],1),1)	; clip quotes

		; scan for <entire string> = <UDFname without "(...)">
		$index=_ArraySearch($functionsUsed,$curstring,1)
		If $index>0 Then
			$stringsUsed[$rc]=StringLeft($stringsUsed[$rc],1) & "{funcU" & $index & "}" & StringRight($stringsUsed[$rc],1)	; working assumption here is that a func-ref is intended, not a literal string for output
			_ArrayAdd($FuncEqualsString,$curstring,0,Chr(0))

			; for safety, we'll include these func defs (possibly called); NB CodeScanner will have missed these calls
			If _ArraySearch($functionsCalled,$curstring,1)<1 Then _
				_ArrayAdd($functionsCalled,$curstring,0,Chr(0))
			ElseIf _ArraySearch($skipRegExpStrings,$rc,1)<1	Then	; skip regexp patterns
				$stringsUsed[$rc]=_MCWords($stringsUsed[$rc])
		EndIf
	Next
	_FileWriteFromArray($CS_dumppath & "stringsUsed.txt",$stringsUsed,1)
	$stringsTransl=$stringsUsed
	FileCopy($CS_dumppath & "stringsUsed.txt",$CS_dumppath & "stringsTransl.txt",1)
	SplashOff()

	; recursively add all additional funcU calls
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": processing UDF calls...")
	$FunctionsCalled[0]=UBound($FunctionsCalled)-1
	$rc=$FunctionsCalled_CS[0]+1
	While $rc<=UBound($FunctionsCalled)-1
		$curdefunc=$FunctionsCalled[$rc]
		$funcdef_ID=_ArraySearch($functionsDefined,$curdefunc)
		If $funcdef_ID>0 Then
			$split=StringSplit($MCinFuncDef[$funcdef_ID],"{")	; lookup all MCtags in this func def
			For $cc=2 To $split[0]
				If StringLeft($split[$cc],5)="funcU" Then
					$func_ID=StringTrimLeft($split[$cc],5)
					$curfunc=$FunctionsUsed[$func_ID]
					If _ArraySearch($functionsCalled,$curfunc)<1 Then
						_ArrayAdd($functionsCalled,$curfunc,0,Chr(0))
						_ArrayAdd($FuncEqualsString,$curfunc,0,Chr(0))
					EndIf
				EndIf
			Next
		EndIf
		$rc+=1
	WEnd
	$FunctionsCalled[0]=UBound($FunctionsCalled)-1
	$FuncEqualsString[0]=UBound($FuncEqualsString)-1

	Global $already_included[1]
	$newfile=$CS_dumppath & "MCF0.txt"
	Global $fhout=FileOpen($newfile,2)
	If @error Or $fhout=-1 Then Return SetError(_ErrorHandler(-2,"opening file " & $newfile,$procname),$newfile,False)
	FileWrite($fhout,$dumptag)
	$timestamp="; This Single-Build "& $timestamptag & @YEAR& "-" & @MON & "-" & @MDAY & ", at " & @HOUR & ":" & @MIN& ":" & @SEC
	FileWriteLine($fhout,$timestamp & @CRLF & ";" & _StringRepeat("=",StringLen($timestamp)-1))

	; recursive call builds MCF0.txt, inserting all #includes
	$totalines=0
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": writing MCF0.txt...")
	If _WriteMCF0(1)=False Then Return SetError(_ErrorHandler(-3,"recursive call to _WriteMCF0() failed",$procname),@error,False)
	FileClose($fhout)
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": MCF0.txt written.")
	$already_included=0

	; final totals
	$macrosUsed[0]			=UBound($macrosUsed)-1
	$variablesUsed[0]		=UBound($variablesUsed)-1
	$globalsredundant[0]	=UBound($globalsredundant)-1
	$functionsUsed[0]		=UBound($functionsUsed)-1
	$functionsCalled[0]	=UBound($functionsCalled)-1

	If $showProgress=True Then SplashTextOn("","Post-Processing Variables...",250,40,-1,-1,1+32,"Verdana",10)
	_FileWriteFromArray($CS_dumppath & "variablesUsed.txt",$variablesUsed,1)
	_FileWriteFromArray($CS_dumppath & "macrosUsed.txt",$macrosUsed,1)

	If $showProgress=True Then SplashTextOn("","Post-Processing Functions...",250,40,-1,-1,1+32,"Verdana",10)
	_FileWriteFromArray($CS_dumppath & "FunctionsUsed.txt",$FunctionsUsed,1)
	_FileWriteFromArray($CS_dumppath & "FunctionsCalled.txt",$functionsCalled,1)
	_FileWriteFromArray($CS_dumppath & "FuncEqualsString.txt",$FuncEqualsString,1)

	; file HAS to exist, but may be empty
	$curfile=$CS_dumppath & "FuncEqualsString.txt"
	If Not FileExists($curfile) Then _FileCreate($curfile)


	If $MCF_REMOVE_ORPHANS=True Then
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": removing orphans...")
		If _RemoveOrphans($CS_dumppath)=False Then
			$err=@error
			SplashOff()
			Return SetError(_ErrorHandler(-4,"call to _RemoveOrphans() failed",$procname),$err,false)
		EndIf
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": orphans removed.")
	EndIf

	; create all post-processing buffers
	_ClearArrays($CS_dumppath)

	If $uselogfile Then _FileWriteLog($fhlog,$procname & " finished." & @CRLF & @CRLF)

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _MCWords($curline,$isCall=False)
; replace vars, macros, AU3 / UDF calls

	If $curline="" Then Return $curline
	$split=StringSplit($curline,"$")
	If Not @error Then
		For $cc=2 To $split[0]
			If StringStripWS($split[$cc],1+2)="" Then
				$split[$cc]="$"	; restore
				ContinueLoop	; skip "$"
			EndIf
			; replace each char that cannot be part of a varname with space
			$curvar=StringRegExpReplace($split[$cc],"[^a-zA-Z0-9_]"," ",1) & " "	; added space suffix
			$pos=StringInStr($curvar," ")-1	; always found (added suffix)
			If $pos=0 Then
				$split[$cc]="$" & $split[$cc]	; restore
				ContinueLoop		; not a varname
			EndIf
			$curvar="$" & StringLeft($curvar,$pos)
			$nextchars=StringTrimLeft($split[$cc],$pos)
			If StringLeft($nextchars,1)="(" Or StringMid($nextchars,2,1)="(" Then
				$split[$cc]="$" & $split[$cc]	; restore
				ContinueLoop	; skip functions with $-prefix
			EndIf
			$index=_ArraySearch($variablesUsed,$curvar,1)
			If $index>0 Then
				$split[$cc]="{var" & $index & "}" & $nextchars
			Else
				_ArrayAdd($variablesUsed,$curvar,0,Chr(0))
				$split[$cc]="{var" & UBound($variablesUsed)-1 & "}" & $nextchars
				$index=_ArraySearch($globalsredundant,$curvar,1)
				If $index>0 Then _ArrayDelete($globalsredundant,$index)
			EndIf
		Next
		$curline=_ArrayToString($split,"",1)
	EndIf

	; extract all macros
	$split=StringSplit($curline,"@")
	If Not @error Then
		For $cc=2 To $split[0]
			; replace each char that cannot be part of a macroname with space
			$curmacro=StringRegExpReplace($split[$cc],"[^a-zA-Z0-9_]"," ",1) & " "
			$curmacro="@" & StringLeft($curmacro,StringInStr($curmacro," ")-1)
			$index=_ArraySearch($macros,$curmacro,1)
			If $index>0 Then
				If _ArraySearch($macrosUsed,$curmacro,1)<1 Then _ArrayAdd($macrosUsed,$curmacro,0,Chr(0))
				$split[$cc]="{macro" & $index & "}" & StringTrimLeft($split[$cc],StringLen($curmacro)-1)
			Else
				$split[$cc]="@" & $split[$cc]		; restore
			EndIf
		Next
		$curline=_ArrayToString($split,"",1)
	EndIf

	; function names parsed as string parameter (without "(...)") are caught in string processing
	$split=StringSplit($curline,"(")
	For $cc=2 To $split[0]
		$previousword=$split[$cc-1]
		$prefix=""
		For $rc=StringLen($previousword) To 1 Step -1
			If $validprefix[Asc(StringMid($previousword,$rc,1))]=True Then
				$prefix=StringLeft($previousword,$rc)
				$previousword=StringStripWS(StringTrimLeft($previousword,$rc),1+2)
				ExitLoop
			EndIf
		Next
		If StringLeft($previousword,5)<>"{func" And $previousword<>"" Then
			$index=_ArraySearch($AU3functions,$previousword,1)
			If $index>0 Then
				$split[$cc-1]=$prefix & "{funcA" & $index & "} "
			Else
				$index=_ArraySearch($functionsUsed,$previousword,1)
				If $index<1 And $isCall=True Then
					_ArrayAdd($functionsUsed,$previousword,0,Chr(0))
					$index=UBound($functionsUsed)-1
				EndIf
				If $index>0 Then
					$split[$cc-1]=$prefix & "{funcU" & $index & "} "
					If $isCall=True Then
						$index=_ArraySearch($functionsCalled,$previousword,1)
						If $index<1 Then _ArrayAdd($functionsCalled,$previousword,0,Chr(0))
					EndIf
				EndIf
			EndIf
		EndIf
	Next
	$curline=_ArrayToString($split,"(",1)

	Return $curline
EndFunc


Func _RemoveOrphans($path,$force_refresh=False)

	$procname="_RemoveOrphans"
	_CallStack_Push($procname)

	; environment checks/prep
	If $force_refresh=True Then
		If _PrepMCenvironment($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,False)
	Else
		If _FillCSpath($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-2,"preparing MCF environment",$procname),0,false)
	EndIf

	$pass=0
	$varorphans=0
	$keepscanning=True
	While $keepscanning	; iterative, because global A,B,C... may occur once each, but be defined A=1,B=A,C=B, etc.
		$pass+=1
		Local $funcalled[1]
		Local $funcorphans[1]
		Local $varonce[1]
		Local $vartwice[1]

		$inputfile=$CS_dumppath & "MCF0.txt"
		If Not FileExists($inputfile) Then Return SetError(_ErrorHandler(-3,"file not found:" & @CR & $inputfile,$procname),0,False)
		$fhin=FileOpen($inputfile)
		If @error Or $fhin=-1 Then Return SetError(_ErrorHandler(-4,"opening file " & $inputfile,$procname),$inputfile,False)

		$tmpfile=$CS_dumppath & "MCF0tmp.txt"
		$fh=FileOpen($tmpfile,2)
		If @error Or $fh=-1 Then
			FileClose($fhin)
			Return SetError(_ErrorHandler(-5,"opening file " & $tmpfile,$procname),$tmpfile,False)
		EndIf

		$linesdone=0
		$prevlineblank=false
		If $showProgress=True Then SplashTextOn("","Identifying Orphans, pass "&$pass&"...",350,40,-1,-1,1+32,"Verdana",10)

		While True
			$curline=FileReadLine($fhin)
			If @error Then	ExitLoop

			$curline=StringStripWS($curline,1+2)
			$linesdone+=1
			If $showProgress=True And Mod($linesdone,500)=0 And $totalines>0 Then _
				SplashTextOn("","Identifying Orphans, pass "& $pass&" (" & _Min(99,Floor(100*$linesdone/($totalines))) & "% done)...",350,40,-1,-1,1+32,"Verdana",10)

			; empty line
			If $curline="" Then
				If $prevlineblank=False Then
					FileWriteLine($fh,"")
					$prevlineblank=True
				EndIf
				ContinueLoop
			EndIf
			$prevlineblank=false

			; pure comment line
			If StringLeft($curline,1)=";" Then
				FileWriteLine($fh,$curline)
				ContinueLoop
			EndIf

			; clip comments
			$commentail=" "
			$pos0=Stringinstr($curline,";",0,-1)
			If $pos0>0 Then
				$commentail&=StringTrimLeft($curline,$pos0-1)
				$curline=StringLeft($curline,$pos0-1)
			EndIf

			; scan everywhere
			$newline=_MCWords($curline)
			If StringInStr($newline,"{var") Then
				$split=StringSplit($newline,"{var",1)
				For $rc=2 To $split[0]
					$pos=StringInStr($split[$rc],"}")
					If $pos>0 Then
						$curvar="{var" & StringLeft($split[$rc],$pos)
						$index=_ArraySearch($varonce,$curvar,1)
						If $index<1 Then	; found once
							_ArrayAdd($varonce,$curvar,0,Chr(0))
						Else					; found again
							If _ArraySearch($vartwice,$index,1)<1 Then _ArrayAdd($vartwice,$index,0,Chr(0))
						EndIf
					EndIf
				Next
			EndIf

			If StringInStr($newline,"{funcU") Then
				$split=StringSplit($newline,"{funcU",1)
				For $rc=2 To $split[0]
					If $rc=2 And StringLeft($split[1],5)="Func " Then ContinueLoop
					$pos=StringInStr($split[$rc],"}")
					If $pos>0 Then
						$curfuncindex=StringLeft($split[$rc],$pos-1)
						If _ArraySearch($funcalled,$curfuncindex,1)<1 Then _ArrayAdd($funcalled,$curfuncindex,0,Chr(0))
					EndIf
				Next
			EndIf

			FileWriteLine($fh, $newline& $commentail)
		WEnd

		FileClose($fhin)
		FileClose($fh)
		Sleep(250)

		_ArraySort($vartwice)
		For $rc=UBound($vartwice)-1 To 1 Step -1
			_arraydelete($varonce,$vartwice[$rc])
		Next
		$varonce[0]=UBound($varonce)-1

		$funcalled[0]=UBound($funcalled)-1
		For $rc=1 To $funcalled[0]
			$funcalled[$rc]=$functionsUsed[$funcalled[$rc]]	; replace with UDF name
		Next

		For $rc=$functionsCalled[0] To 1 Step -1
			$curfunc=$functionsCalled[$rc]
			If _ArraySearch($funcalled,$curfunc)<1 And _ArraySearch($FuncEqualsString,$curfunc)<1 Then
				_ArrayDelete($functionsCalled,$rc)
				$index=_ArraySearch($functionsUsed,$curfunc)
				If $index>0 Then _ArrayAdd($funcorphans,"{funcU" & $index & "}",0,Chr(0))
			EndIf
		Next
		$funcorphans[0]=UBound($funcorphans)-1
		$FunctionsCalled[0]=UBound($FunctionsCalled)-1

		$keepscanning=($varonce[0]>$varorphans Or $funcorphans[0]>0)
		$varorphans=$varonce[0]

		; replace target with tmp
		$fh=FileOpen($inputfile,2)
		If @error Or $fh=-1 Then Return SetError(_ErrorHandler(-6,"opening file " & $inputfile,$procname),$inputfile,False)

		$fhin=FileOpen($tmpfile)
		If @error Or $fhin=-1 Then
			FileClose($fh)
			Return SetError(_ErrorHandler(-7,"opening file " & $tmpfile,$procname),$tmpfile,False)
		EndIf

		$linesdone=0
		$prevlineblank=false
		$skiporphanfuncdef=False
		While True
			$curline=FileReadLine($fhin)
			If @error Then	ExitLoop

			$linesdone+=1
			If $showProgress=True And Mod($linesdone,500)=0 And $totalines>0 Then _
				SplashTextOn("","Removing " & $varonce[0]+$funcorphans[0] & " Orphans (" & _Min(99,Floor(100*$linesdone/($totalines))) & "% done)...",300,40,-1,-1,1+32,"Verdana",10)

			; empty line
			If StringStripWS($curline,1+2)="" Then
				If $prevlineblank=False Then
					FileWriteLine($fh,"")
					$prevlineblank=True
				EndIf
				ContinueLoop
			EndIf
			$prevlineblank=false

			; early-out(put)
			If StringLeft($curline,1)=";"  Then
				FileWriteLine($fh,$curline)
				ContinueLoop
			EndIf

			If StringLeft($curline,7)="EndFunc" Then
				$tmp=$skiporphanfuncdef
				$skiporphanfuncdef=False
				If $tmp=True Then ContinueLoop
			EndIf

			If StringLeft($curline,5)="Func " Then
				$pos1=StringInStr($curline,"{funcU")
				$pos2=stringinstr($curline,"}")
				If $pos1*$pos2>0 Then
					$curfunc=StringMid($curline,$pos1,1+$pos2-$pos1)
					If _ArraySearch($funcorphans,$curfunc)>0 Then $skiporphanfuncdef=True
				EndIf
			EndIf
			; skip writing out this func def (omit from output)
			If $skiporphanfuncdef=True Then ContinueLoop

			; scan global defs for our orphan vars
			If (StringLeft($curline,7)="Global " And StringMid($curline,8,5)<>"Enum ") Then
				$pos1=StringInStr($curline,"{var")
				If $pos1>0 Then
					$pos2=StringInStr($curline,"}",$pos1)
					$pos3=StringInStr($curline,"=")
					If $pos2>0 And ($pos3<1 Or $pos3>$pos2) Then
						$curvar=StringMid($curline,$pos1,1+$pos2-$pos1)
						; skip writing out this global def (omit from output)
						If _ArraySearch($varonce,$curvar,1)>0 Then ContinueLoop
					EndIf
				EndIf
			EndIf

			FileWriteLine($fh, $curline)
		WEnd
		$totalines=$linesdone
		FileClose($fhin)
		FileClose($fh)
		Sleep(250)

		If FileExists($tmpfile)	Then FileDelete($tmpfile)

		$totalines=$linesdone
	WEnd		; keepscanning
	SplashOff()

	; store updated list
	_FileWriteFromArray($CS_dumppath & "functionsCalled.txt",$functionsCalled,1)

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _WriteMCF0($file_ID)		; create MFC0.txt from MCF#.txt (#: 1-N)

	$procname="_WriteMCF0"
	_CallStack_Push($procname)

	If $file_ID<1 Or $file_ID>$includes[0] Then Return SetError(_ErrorHandler(-1,"file ID out of bounds: " & $file_ID,$procname),$file_ID,False)

	$mcfname="mcf" & $file_ID & ".txt"
	$curfile=$CS_dumppath & $mcfname
	If Not FileExists($curfile) Then Return SetError(_ErrorHandler(-2,"MetaCode file not found:"& @CR & $mcfname,$procname),$file_ID,False)

	$original_filename=$includes[$file_ID]
	If _ArraySearch($includeonce,$original_filename,1)>0 And _
		_ArraySearch($already_included,$original_filename,1)>0 Then
			_CallStack_Pop($procname)
			Return True
	EndIf
	_ArrayAdd($already_included,$original_filename,0,Chr(0))

	If $showProgress=True Then SplashTextOn("","Processing " & StringUpper($mcfname) & "...",250,40,-1,-1,1+32,"Verdana",10)

	Local $fh=FileOpen($curfile)
	If @error Or $fh=-1 Then Return SetError(_ErrorHandler(-3,"opening file " & $curfile,$procname),$file_ID,false)

	$enumerations=0
	$totalenumerations=0
	$enumeratedList=""
	$prevenumerating=False
	$prevcommentail=""
	$insidefuncdef=0
	$skipfuncdef=False

	While True
		$enumerating=False
		$curline=FileReadLine($fh)
		If @error Then			; eof?
			FileClose($fh)
			FileWriteLine($fhout,$enumeratedlist & $prevcommentail & @CRLF)	; fail-safe; these stringvars should both be empty
			$totalines+=1
			ExitLoop
		EndIf
		$skipwrite=False
		$pos1=Stringinstr($curline,"{incl")
		If $pos1>0 Then
			$pos2=Stringinstr($curline,"}",0,1,$pos1+5)
			$incl_ID=StringMid($curline,$pos1+5,$pos2-$pos1-5)
			FileWriteLine($fhout,@CRLF)
			$totalines+=1
			_WriteMCF0($incl_ID)		; recursive call
			ContinueLoop
		EndIf

		If StringLeft($curline,7)="EndFunc" Then
			$skipwrite=$skipfuncdef
			$skipfuncdef=False
			$insidefuncdef=0
			$curline&=@CRLF	; add blank line after endfunc def
		EndIf

		If StringLeft($curline,5)="Func " Then
			$pos1=Stringinstr($curline,"{func")
			$pos2=Stringinstr($curline,"}",0,1,$pos1+5)
			$func_ID=StringMid($curline,$pos1+6,$pos2-$pos1-6)
			If $func_ID>$FunctionsUsed[0] Then Return SetError(_ErrorHandler(-1,"unrecognised UDF function index " & $func_ID,$procname),$file_ID,False)

			If _ArraySearch($FunctionsCalled,$functionsUsed[$func_ID],1)<1 Then $skipfuncdef=$MCF_SKIP_UNCALLED_UDFS
			$curline=@CRLF & $curline	; add blank line before func def
			$insidefuncdef=1
		EndIf

		; do not write out func defs that are not called, unless forced
		If ($skipfuncdef Or $skipwrite)=True Then ContinueLoop

		; remove "{none}" from parameter-less function calls and global defs
		$curline=StringReplace($curline,"{none}"," ")
		$commentail=" "
		$pos0=Stringinstr($curline,";",0,-1)
		If $pos0=0 Then
			$pos0=StringLen($curline)
		Else
			$commentail&=StringTrimLeft($curline,$pos0-1)
		EndIf

		; remove undesired infix spaces
		$split=StringSplit(StringLeft($curline,$pos0-1),"")
		If $split[0]>2 Then
			$newline=$split[1]
			For $cc=2 To $split[0]-1
				; scientific notation (#E + #)
				If $cc>2 And $cc<$split[0]-1 And ($split[$cc]="+" Or $split[$cc]="-") Then
					If $split[$cc-2]="E" And $split[$cc-1]=" " Then $split[$cc-1]=""
					If ($split[$cc-2]="E" Or $split[$cc-1]="E") And $split[$cc+1]=" " Then $split[$cc+1]=""
				EndIf
				; operator pairs (e.g., "> =", "< >", etc.)
				If Not ($validprefix[Asc($split[$cc-1])]=True And _
					$validprefix[Asc($split[$cc+1])]=True And _
					$split[$cc]=" ") Then $newline&=$split[$cc]
			Next
			$curline=$newline
		EndIf

		If StringLeft($curline,7)="Global " Then
			$insertPrefix=""
			Select
				Case StringMid($curline,8,6)="Const "
					$insertPrefix="Const "
				Case StringMid($curline,8,5)="Enum "	; can be none or either one, but not both
					$enumerating=True
					$insertPrefix="Enum "
					If StringLeft($curline,13)="Step " Then
						$pos=StringInStr($curline," ",14)
						If $pos>0 Then	$insertPrefix&=StringLeft($curline,$pos-1)
					EndIf
			EndSelect
			$pos1=Stringinstr($curline,"$*")
			$pos2=Stringinstr($curline,"[")
			$pos4=Stringinstr($commentail,"{ref")
			$pos5=Stringinstr($commentail,"}",0,-1)

			; get refcontents
			$refrec=StringMid($commentail,$pos4+4,$pos5-$pos4-4)
			$var=$references[$refrec][4]
			If $pos2>0 Then $var=StringLeft($var,StringInStr($var,"[")-1)	; clip any array dims for redundancy scan
			; filter out redundant globals
			; this misses globals used only to define other redundant globals; these should be caught in _RemoveOrphans()
			If _ArraySearch($globalsredundant,$var,1)>0 And $enumerating=False Then ContinueLoop
			$MCtag=_MCWords($var)

			; build Orphans list (to be pruned later)
			If $enumerating=False Then
				If _ArraySearch($globalsOrphaned,$var,1)<1 Then
					$pos=StringInStr($MCtag,"[")
					If $pos<1 Then
						_ArrayAdd($globalsOrphaned,$MCtag,0,Chr(0))
					Else
						_ArrayAdd($globalsOrphaned,StringStripWS(StringLeft($MCtag,$pos-1),2),0,Chr(0))
					EndIf
				EndIf
			EndIf

			$posequal=Stringinstr($curline,"=")
			If $posequal>0 Then $curline=StringLeft($curline,$posequal)	; clip any square brackets after an equal-sign, if present
			$pos3=Stringinstr($curline,"]",0,-1)
			$insertdims=" "
			If $pos2*$pos3>0 Then $insertdims=StringMid($curline,$pos2,$pos3-$pos2+1) & " "
			$params=StringStripWS($references[$refrec][5],1+2)
			If $params="" Or $params="{none}" Then
				$curline=$MCtag & $insertdims
			Else
				; any called funcs here should already be stored, either through CS:TrackCalls or through MCF:string processing
				$curline=$MCtag & $insertdims & "= " & _MCWords($params,True)	; param2 = IsCall
			EndIf

			; rebuild Enum list as single line
			Select
				Case $enumerating=False And $prevenumerating=False	; default, most common case
					$curline="Global " & $insertPrefix & $curline
				Case $enumerating=True And $prevenumerating=False	; just started
					$enumeratedList="Global " & $insertPrefix & $curline
					; determine number of comma-separated Enum entries on the original line
					$enumerations=1
					$totalenumerations=1
					$curinclude=$references[$refrec][1]
					$linenr=$references[$refrec][2]
					For $cc=$refrec+1 To $references[0][0]
						If $linenr<>$references[$cc][2] Or $curinclude<>$references[$cc][1] Then ExitLoop
						If StringLeft($references[$cc][3],11)="Global Enum" Then $totalenumerations+=1
					Next
					$prevcommentail=$commentail
					$prevenumerating=True
					If $enumerations<$totalenumerations Then ContinueLoop		; defer writing out
					$curline=$enumeratedList
					$enumerating=False													; done with this list
				Case ($enumerating=True And $prevenumerating=True)				; still accumulating
					$enumeratedList&=", " & $curline									; rebuild single line
					$enumerations+=1
					$prevcommentail=$commentail
					If $enumerations<$totalenumerations Then ContinueLoop		; defer writing out
					$curline=$enumeratedList
					$enumerating=False													; done with this list
				Case ($enumerating=False And $prevenumerating=True)			; encountered something else
					$curline=$enumeratedList & $prevcommentail & @CRLF & $curline					; fail-safe, should never happen
			EndSelect
		EndIf

		FileWriteLine($fhout,$curline & $commentail)

		$totalines+=1
		If $insidefuncdef>0 Then $insidefuncdef+=1
		$enumeratedList=""
		$totalenumerations=0
		$enumerations=0
		$prevenumerating=$enumerating
		$prevcommentail=""
	WEnd

	_CallStack_Pop($procname)
	Return True
EndFunc

#endregion Input-related

#region Structure-altering

Func _IndirectMCF($path,$inputfile="MCF0.txt",$outputfile="MCF0_indirected.txt")
; replace  all variable assignments with their equivalent MCFinclude call

	$procname="_IndirectMCF"
	_CallStack_Push($procname)

	; for skipping lines from MCFinclude.au3
	$marker="{file:" & $MCF_file_ID & "}"

	Local $indirectcall[7]
	$indirectcall[0]=UBound($indirectcall)-1
	For $cc=1 To $indirectcall[0]
		$indirectcall[$cc]=""
	Next

	; create a lookup table
	For $rc=1 To $functionsUsed[0]
		Switch $functionsUsed[$rc]
			Case "_VarIsVar"
				$indirectcall[1]="{funcU" & $rc & "}"
			Case "_ArrayVarIsVar"
				$indirectcall[2]="{funcU" & $rc & "}"
			Case "_VarIsArrayVar"
				$indirectcall[3]="{funcU" & $rc & "}"
			Case "_ArrayVarIsArrayVar"
				$indirectcall[4]="{funcU" & $rc & "}"
			Case "_VarIsNumber"
				$indirectcall[5]="{funcU" & $rc & "}"
			Case "_ArrayVarIsNumber"
				$indirectcall[6]="{funcU" & $rc & "}"
		EndSwitch
		$alldone=True
		For $cc=1 To $indirectcall[0]
			$alldone=($alldone And ($indirectcall[$cc]<>""))
		Next
		If $alldone=True Then ExitLoop	; early-out
	Next

	If Not $alldone Then Return SetError(_ErrorHandler(-1,"one or more indirection UDFs missing",$procname),0,False)

	$fhin=FileOpen($path & $inputfile)
	If @error Or $fhin=-1 Then Return SetError(_ErrorHandler(-2,"opening file " & $inputfile,$procname),0,-1)

	$fhout=FileOpen($path & $outputfile,2)
	If @error Or $fhout=-1 Then
		FileClose($fhin)
		Return SetError(_ErrorHandler(-3,"opening file " & $outputfile,$procname),0,-1)
	EndIf

	If $showProgress=True Then SplashTextOn("","Indirecting MCF; please wait...",250,40,-1,-1,1+32,"Verdana",10)

	$linesdone=0
	While True

		$curline=FileReadLine($fhin)
		If @error Then	ExitLoop

		$curline=StringStripWS($curline,1+2)	; also clips @tab inside func defs
		$linesdone+=1
		If $showProgress=True And Mod($linesdone,500)=0 And $totalines>0 Then _
			SplashTextOn("","Indirecting MCF (" & _Min(99,Floor(100*$linesdone/$totalines)) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)

		; skip empty line
		If $curline="" Or StringLeft($curline,1)=";" Or  StringLeft($curline,5)="Func " Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; skip compiler directives and calls/defs
		If StringLeft($curline,1)="#" Or StringInStr($curline,"{func") Or StringInStr($curline,"{string") Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; skip conditionals (except "If") and loops
		If StringLeft($curline,4)="For " Or StringLeft($curline,6)="While " Or StringLeft($curline,6)="Until " Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; only keep lines with equal sign
		If Not StringInStr($curline,"=") Or StringLeft($curline,6)="Local " Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; clip comment tail
		$newline=$curline
		$commentail=" "
		$pos0=Stringinstr($curline,";",0,-1)
		If $pos0>0 Then
			$commentail&=StringTrimLeft($curline,$pos0-1)
			$newline=StringStripWS(StringLeft($curline,$pos0-1),2) ; have to clip any trailing spaces
		EndIf

		; skip replacements inside MCFinclude (avoid infinite recursion)
		If StringInStr($commentail,$marker) Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		$prefix=""
		$pos=StringInStr($newline,"Then ")	; trailing spaces are clipped, so this indicates executable code follows "Then" on same line
		If $pos>0 And StringLen($newline)>$pos+4 then
			$prefix=StringLeft($newline,$pos+4)
			$newline=StringTrimLeft($newline,$pos+4)
		EndIf

		$split=StringSplit($newline,"=")
		If $split[0]<>2 Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		$leftside=StringStripWS($split[1],1+2)
		$rightside=StringStripWS($split[2],1+2)
		If StringLeft($leftside,4)<>"{var" Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		If StringLeft($rightside,4)<>"{var" Then
			if StringLen(StringRegExpReplace($rightside,"[-+*/^0-9.e()]",""))=0 Then
				$rightside=Number(Execute($rightside))
			Else
				FileWriteLine($fhout,$curline)
				ContinueLoop
			EndIf
		EndIf

		$leftarrayindex=""
		$rightarrayindex=""
		$rightvar=""
		$rightnumber=""

		$pos=StringInStr($leftside,"}")
		$pos1=StringInStr($leftside,"[")
		$pos2=StringInStr($leftside,"]",0,1,$pos1+1)

		If $pos<1 Or _Max($pos,$pos2)<StringLen($leftside) Then	; more stuff on this side we cannot handle
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf
		$leftvar=StringLeft($leftside,$pos)
		If $pos1*$pos2>0 Then $leftarrayindex=StringMid($leftside,$pos1+1,$pos2-$pos1-1)

		If IsNumber($rightside) Then
			$rightnumber=Number($rightside)
		Else
			$pos=StringInStr($rightside,"}")
			$pos1=StringInStr($rightside,"[")
			$pos2=StringInStr($rightside,"]",0,1,$pos1+1)
			If $pos<1 Or _Max($pos,$pos2)<StringLen($rightside) Then	; more stuff on this side we cannot handle
				FileWriteLine($fhout,$curline)
				ContinueLoop
			EndIf
			$rightvar=StringLeft($rightside,$pos)
			If $pos1*$pos2>0 Then $rightarrayindex=StringMid($rightside,$pos1+1,$pos2-$pos1-1)
		EndIf

		; determine which replacement function to use
		$replacement=""
		Select
			Case $leftarrayindex="" And $rightvar<>"" And $rightarrayindex=""
				$replacement="_VarIsVar"
			Case $leftarrayindex<>"" And $rightvar<>"" And $rightarrayindex=""
				$replacement="_ArrayVarIsVar"
			Case $leftarrayindex="" And $rightvar<>"" And $rightarrayindex<>""
				$replacement="_VarIsArrayVar"
			Case $leftarrayindex<>"" And $rightvar<>"" And $rightarrayindex<>""
				$replacement="_ArrayVarIsArrayVar"
			Case $leftarrayindex="" And $rightnumber<>""
				$replacement="_VarIsNumber"
			Case $leftarrayindex<>"" And $rightnumber<>""
				$replacement="_ArrayVarIsNumber"
		EndSelect
		If $replacement="" Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; build replacement call
		Switch $replacement
			Case "_VarIsVar"
				$newline=$indirectcall[1] & "(" & $leftvar & "," & $rightvar &")"
			Case "_ArrayVarIsVar"
				$newline=$indirectcall[2] & "(" &$leftvar & "," & $leftarrayindex & "," & $rightvar &")"
			Case "_VarIsArrayVar"
				$newline=$indirectcall[3] & "(" & $leftvar & "," & $rightvar & "," & $rightarrayindex &")"
			Case "_ArrayVarIsArrayVar"
				$newline=$indirectcall[4] & "(" &$leftvar & "," & $leftarrayindex & "," & $rightvar & "," & $rightarrayindex &")"
			Case "_VarIsNumber"
				$newline=$indirectcall[5] & "(" & $leftvar & "," & $rightnumber &")"
			Case "_ArrayVarIsNumber"
				$newline=$indirectcall[6] & "(" &$leftvar & "," & $leftarrayindex & "," & $rightnumber &")"
		EndSwitch

		FileWriteLine($fhout, $prefix & $newline & $commentail)

	WEnd
	$totalines=$linesdone
	FileClose($fhout)
	FileClose($fhin)
	Sleep(250)	; allow some time to release handles

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _PhraseMCF($path,$inputfile="",$outputfile="MCF0_phrased.txt")

	$procname="_PhraseMCF"
	_CallStack_Push($procname)

	Global $section1_lastline=0
	Global $section2_lastline=0
	Global $section1_lastphrase=0
	Global $section2_lastphrase=0

	For $rc=1 To $references[0][0]
		If StringRight($references[$rc][1],StringLen($MCFinclude))=$MCFinclude Then
			If $references[$rc][3]="func end" Then
				If $references[$rc][4]="_MCFCC" Then $section1_lastline=$references[$rc][2]
				If $references[$rc][4]="_MCFCC_Init" Then
					$section2_lastline=$references[$rc][2]
					ExitLoop
				EndIf
			EndIf
		EndIf
	Next

	$recordingsection=1
	$marker1="{file:" & $MCF_file_ID & "}{line:" & $section1_lastline & "}"
	$marker2="{file:" & $MCF_file_ID & "}{line:" & $section2_lastline & "}"

	$index=_arraysearch($FunctionsUsed,"_MCFCC_Init")
	If $index<1 Then Return SetError(_ErrorHandler(-1,"internal UDF _MCFCC_Init() not found in array $FunctionsUsed",$procname),0,False)
	$initfunc="{funcU" & $index & "}"

	If $inputfile="" Then
		If $MCF_INDIRECTION=True Then
			$inputfile="MCF0_indirected.txt"
		Else
			$inputfile="MCF0.txt"
		EndIf
	EndIf

	$fhin=FileOpen($path & $inputfile)
	If @error Or $fhin=-1 Then Return SetError(_ErrorHandler(-2,"opening file " & $inputfile,$procname),0,False)

	$fhout=FileOpen($path & $outputfile,2)
	If @error Or $fhout=-1 Then
		FileClose($fhin)
		Return SetError(_ErrorHandler(-3,"opening file " & $outputfile,$procname),0,False)
	EndIf

	Global $MCF_PHRASING=True
	Global $phrases[1]			; redefine
	Global $phrasesUsed[1]		; redefine
	Global $phrasesUDF[1]		; redefine
	Global $phrasesEncryp[1]	; redefine
	Global $phrasesNew[1]		; redefine
	Global $strings1[1]			; need this in _EncrypMCF()
	Global $strings2[1]			; need this in _EncrypMCF()

	$curfunc="{Main}"
	$addtab=""
	$linesdone=0
	$prevlineblank=False

	If $showProgress=True Then SplashTextOn("","Phrasing MCF; please wait...",250,40,-1,-1,1+32,"Verdana",10)
	While True

		$curline=FileReadLine($fhin)
		If @error Then	ExitLoop

		$curline=StringStripWS($curline,1+2)	; also clips @tab inside func defs
		$linesdone+=1
		If $showProgress=True And Mod($linesdone,500)=0 And $totalines>0 Then _
			SplashTextOn("","Phrasing MCF (" & _Min(99,Floor(100*$linesdone/$totalines)) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)

		; empty line
		If $curline="" Then
			If $prevlineblank=False Then
				FileWriteLine($fhout,"")
				$prevlineblank=True
			EndIf
			ContinueLoop
		EndIf
		$prevlineblank=false

		; pure comment line
		If StringLeft($curline,1)=";" Then
			$pos=StringInStr($curline,$timestamptag)
			If $pos>0 Then $curline=StringLeft($curline,$pos+StringLen($timestamptag)-1) & @YEAR& "-" & @MON & "-" & @MDAY & ", at " & @HOUR & ":" & @MIN& ":" & @SEC
			If StringLeft($curline,3)<>"; {" Then FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; skip compiler directives
		If StringLeft($curline,1)="#" Then
			FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; clip comment tail
		$commentail=" "
		$pos0=Stringinstr($curline,";",0,-1)
		If $pos0>0 Then
			$commentail&=StringTrimLeft($curline,$pos0-1)
			$curline=StringLeft($curline,$pos0-1)
		EndIf

		If $recordingsection>0 Then	; collect strings
			$pos1=StringInStr($curline,"{string")
			while $pos1>0
				$pos2=StringInStr($curline,"}",0,1,$pos1)
				$curstring=StringMid($curline,$pos1,1+$pos2-$pos1)
				If $recordingsection=1 Then
					_ArrayAdd($strings1,$curstring,0,Chr(0))
				else
					_ArrayAdd($strings2,$curstring,0,Chr(0))
				EndIf
				$pos1=StringInStr($curline,"{string",0,1,$pos1+1)
			WEnd
		EndIf

		; skip func end
		If StringLeft($curline,7)="EndFunc" Then
			$curfunc="{Main}"
			$addtab=""
			FileWriteLine($fhout,$curline & $commentail)

			; obtain phrase markers for section bounds
			If $recordingsection>0 Then
				If StringInStr($commentail,$marker1) Then
					$section1_lastphrase=UBound($phrases)-1	; NB redefining from linenr to phrasenr
					$recordingsection+=1
				ElseIf StringInStr($commentail,$marker2) Then
					$section2_lastphrase=UBound($phrases)-1
					$recordingsection=0								; we're done
				EndIf
			EndIf

			ContinueLoop
		EndIf

		; skip func def
		If StringLeft($curline,5)="Func " Then
			FileWriteLine($fhout,$curline & $commentail)
			$pos=StringInStr($curline,"}")
			If $pos>6 Then $curfunc=StringLeft(StringTrimLeft($curline,5),$pos-5)
			$addtab=@TAB
			ContinueLoop
		EndIf

		; replace dummy call _MCFCC_Init() with real call parsing selected keytype
		If StringLeft($curline,StringLen($initfunc))=$initfunc Then _
			$curline=$initfunc & "(" & $CCkeytype & ")"

		; newline will contain the phrased equivalent of curline
		$newline=$curline

		; extract conditionals first (If, while, Until), because they can contain calls
		If StringLeft($newline,3)="If " Then
			$pos=StringInStr($newline," Then")
			If $pos>0 Then
				$curphrase=StringMid($newline,4,$pos-3)
				_ArrayAdd($phrases,$curphrase,0,Chr(0))
				_ArrayAdd($phrasesUDF,$curfunc,0,Chr(0))
				$index=UBound($phrases)-1
				$phrases[0]=$index
				$phrasesUDF[0]=$index
				$newline="If {phrase" & $index & "}" & StringTrimLeft($newline,$pos-1)
			EndIf
		EndIf

		If StringLeft($newline,6)="While " Or StringLeft($newline,6)="Until " Then
			If Not (StringMid($newline,7,4)="True" Or StringMid($newline,7,5)="False") Then
				$curphrase=Stringtrimleft($newline,6)
				_ArrayAdd($phrases,$curphrase,0,Chr(0))
				_ArrayAdd($phrasesUDF,$curfunc,0,Chr(0))
				$index=UBound($phrases)-1
				$phrases[0]=$index
				$newline=StringLeft($newline,6) & "{phrase" & $index & "}"
			EndIf
		EndIf

		; extract calls after conditionals (so calls inside conditionals remain intact), but before macros
		$pos1=StringInStr($newline,"{func")
		While $pos1>0
			$pos2=0
			$nesting=0
			For $cc=$pos1+5 To StringLen($newline)
				$curchar=StringMid($newline,$cc,1)
				Switch $curchar
					Case "("
						$nesting+=1
					Case ")"
						$nesting-=1
						If $nesting=0 Then
							$pos2=$cc
							ExitLoop
						EndIf
				EndSwitch
			Next
			If $pos2>$pos1 Then
				$curphrase=StringMid($newline,$pos1,1+$pos2-$pos1)
				_ArrayAdd($phrases,$curphrase,0,Chr(0))
				_ArrayAdd($phrasesUDF,$curfunc,0,Chr(0))
				$index=UBound($phrases)-1
				$phrases[0]=$index
				$newline=StringLeft($newline,$pos1-1) & "{phrase" & $index & "}" & StringTrimLeft($newline,$pos2)
			Else
				ExitLoop	; we need a valid departure point for the next search
			EndIf
			$pos1=StringInStr($newline,"{func",0,1,$pos2+1)
		WEnd

		; extract macros last, so macros inside conditionals and calls remain intact
		$pos1=StringInStr($newline,"{macro")
		while $pos1>0
			$pos2=StringInStr($newline,"}",0,1,$pos1)
			$curphrase=StringMid($newline,$pos1,1+$pos2-$pos1)
			_ArrayAdd($phrases,$curphrase,0,Chr(0))
			_ArrayAdd($phrasesUDF,$curfunc,0,Chr(0))
			$index=UBound($phrases)-1
			$phrases[0]=$index
			$newline=StringLeft($newline,$pos1-1) & "{phrase" & $index & "}" & StringTrimLeft($newline,$pos2)
			$pos1=StringInStr($newline,"{macro",0,1,$pos1+1)
		WEnd

		If $MCF_ENCRYPT_PHRASES=True Then
			FileWriteLine($fhout, $addtab & $newline & $commentail)	; new
		Else
			FileWriteLine($fhout, $addtab & $curline & $commentail)	; original (with _MCFCC_Init() defined)
		EndIf

	WEnd
	$totalines=$linesdone
	FileClose($fhout)
	FileClose($fhin)

	$phrases[0]=UBound($phrases)-1
	$phrasesUDF[0]=$phrases[0]
	_FileWriteFromArray($CS_dumppath & "phrasesUDF.txt",$phrasesUDF,1)
	_FileWriteFromArray($CS_dumppath & "phrases.txt",$phrases,1)
	FileCopy($CS_dumppath & "phrases.txt",$CS_dumppath & "phrasesNew.txt",1)
	SplashOff()

	_CallStack_Pop($procname)
	Return True
EndFunc

#endregion Structure-altering

#region Content-altering

Func _EncryptArrays($path,$force_refresh=false,$inputfile="")
; expects $CCkey[], $CCkeytype to be valid
; updates arrays $stringEncryp[], $stringsNew[],$phrases*[]

	$procname="_EncryptArrays"
	_CallStack_Push($procname)

	; set path, reload all arrays
	If _FillCSpath($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,False)

	If _TestCCKey()=False Then Return SetError(_ErrorHandler(-2,"Invalid key or keytype supplied",$procname),0,False)

	If $CCkey[$CCkeytype]="" Then	; empty entry = get user input at startup
		If $decryption_key="" Then
			Return SetError(_ErrorHandler(-2,"both keytype definition and user password are empty",$procname),0,False)
		Else
			; MCFinclude:_MCFCC_Init() in target will query user for this at startup
			; for encryption, store it temporarily in its allocated spot
			; NB $decryption_key is NOT incorporated in the target
			; only an empty slot in array $CCkey[] is included in the build,
			; where MCF_Init() will store it from cmdline or user query at target startup
			$CCkey[$CCkeytype]=$decryption_key
		EndIf
	Else					; non-empty entry = use current or pre-supplied definition
		If $decryption_key="" Then
			_MCFCC_Init($CCkeytype,False)	; execute $CCkey definition directly (use current environment)
		Else
			; pre-supply the *expected* return of the specified definition
			; use this if target is prepared for a different user/environment from current key definition
			; Example: $CCkeytype=X, MCFinclude defines $CCkey[X] = @UserName
			; but target should work not for you, but for username="Sally"
			; then predefine $decryption_key="Sally"
			; the MCFinclude in the target still defines $CCkey[X]=@UserName, so when
			; Sally runs the target, the correct decryption key is generated in $CCkey[X]
			$CCkey[$CCkeytype]=$decryption_key		; pre-supplied definition
		endif
	EndIf

	; obtain current MCFCC variable names (may be obfuscated)
	_PrepMCFinclude()

	$MCF_ENCRYPT=True
	If $inputfile="" Then
		If $MCF_INDIRECTION=True Then
			$inputfile="MCF0_indirected.txt"
		Else
			$inputfile="MCF0.txt"
		EndIf
	EndIf

	; extract phrases from MCF0.txt, fill $phrases[]; NB alters structure
	; always call to define section1/2 markers,strings (not dependent on $MCF_ENCRYPT_PHRASES=True)
	_PhraseMCF($path,$inputfile)		; also fills arrays $strings1/2

	; re-seed randomiser
	SRandom(@AutoItPID + @MSEC)

	; encode MC in phrasesUsed array
	; phrases=MC, phrasesUsed=code, phrasesEncryp=encrypted code
	; NB this uses contents of $stringsNew[] as prepared by _RebuilScript(), PRIOR to $MCF_ENCRYPT_STRINGS
	If $MCF_ENCRYPT_PHRASES=True Then
		If $showProgress=True Then SplashTextOn("","Preparing Arrays...",250,40,-1,-1,1+32,"Verdana",10)

		; replace all MC tags in phrases, save as phrasesUsed.txt
		_ReplaceMCinArray($phrases,$phrasesUsed,$functionsNew,$variablesNew,$stringsNew)	; remove all MCtags in phrasesUsed
		_FileWriteFromArray($CS_dumppath & "phrasesUsed.txt",$phrasesUsed,1)
		$phrasesEncryp=$phrasesUsed

		For $rc=1 To $phrasesEncryp[0]
			If $showProgress=True And Mod($rc,100)=0 Then _
				SplashTextOn("","Encrypting Phrases (" & _Min(99,Floor(100*$rc/$phrasesEncryp[0])) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)

			; determine keytype
			Select
				case $rc<=$section1_lastphrase
					ContinueLoop						; keep original content
				Case $rc<=$section2_lastphrase
					$keytype=0
				Case Else		;after MCFinclude
					If $MCF_ENCRYPT_SHUFFLEKEY=True Then
						$keytype=Random($CCkeyshuffle_start,$CCkeyshuffle_end,1)
					Else
						$keytype=$CCkeytype
					EndIf
			EndSelect

			; determine call structure
			Switch $MCF_ENCRYPT_NESTED
				Case True
					$_MCFcall=$_MCFCCXB
					$brackets=")))"
				Case Else
					$_MCFcall=$_MCFCCXA
					$brackets="))"
			EndSwitch

			; encryp phrase
			$phrasesEncryp[$rc]=$_MCFcall &"(" & _EncryptEntry($phrasesEncryp[$rc],$keytype,True) & $brackets
		Next

		; all phrases are encrypted in this array, any defined subset is reflected only in $phrasesNew[]
		If $showProgress=True Then SplashTextOn("","Saving Array...",250,40,-1,-1,1+32,"Verdana",10)
		_FileWriteFromArray($CS_dumppath & "phrasesEncryp.txt",$phrasesEncryp,1)

		; skipping everything up to and including #include MCFinclude.au3
		If $MCF_ENCRYPT_SUBSET=True And $section2_lastphrase>0 And $section2_lastphrase<$phrasesUsed[0] Then
			Switch $subset_definition
				Case 0			; encrypt nothing
					If $showProgress=True Then SplashTextOn("","Preparing Array...",250,40,-1,-1,1+32,"Verdana",10)
					$phrasesNew=$phrasesUsed
				Case Else
					If $showProgress=True Then SplashTextOn("","Preparing Array...",250,40,-1,-1,1+32,"Verdana",10)
					$phrasesNew=$phrasesEncryp
					If $showProgress=True Then SplashTextOn("","Defining Subset...",250,40,-1,-1,1+32,"Verdana",10)
					Select
						Case $subset_definition>0 And  $subset_definition<1
							For $rc=$section2_lastphrase+1 To $phrasesUsed[0]
								If Random(0,1)>$subset_definition Then _
									$phrasesEncryp[$rc]=$phrasesUsed[$rc]	; restore original
							Next
						Case $subset_definition>1
							For $rc=$section2_lastphrase+1 To $phrasesUsed[0]
								If Mod($rc,$subset_definition)=0 Then _
									$phrasesEncryp[$rc]=$phrasesUsed[$rc]	; restore original
							Next
					EndSelect
			EndSwitch

			; save phrasesNew as phraseEncryp
			If $showProgress=True Then SplashTextOn("","Saving Array...",250,40,-1,-1,1+32,"Verdana",10)
			_FileWriteFromArray($CS_dumppath & "phrasesEncryp.txt",$phrasesEncryp,1)
		EndIf
		If $showProgress=True Then SplashTextOn("","Preparing Phrases...",250,40,-1,-1,1+32,"Verdana",10)

		; load phrasesNew with partially/fully encrypted phrases
		$phrasesNew=$phrasesEncryp

		; final partial restoration pass
		; check1: always restore any phrase containing @error/@extended (cannot be encrypted; Execute wipes their status)
		; check2: this UDF is enabled for encrpytion, restore original content if not
		; NB the UDF filter is always applied, preset to all UDFs (and main script) enabled (True = encrypt)
		For $rc=$section2_lastphrase+1 To $phrasesUsed[0]
			If StringInStr($phrasesUsed[$rc],"@error") Or StringInStr($phrasesUsed[$rc],"@extended") Then
				$phrasesNew[$rc]=$phrasesUsed[$rc]	; restore unencrypted
			Else
				$curfunc=$phrasesUDF[$rc]
				$index=Number(StringTrimLeft(stringTrimRight($curfunc,1),6)) ; 0 = Main
				If $index>0 And $index<UBound($selectedUDFstatus) Then
					If $SelectedUDFstatus[$index]=False Then $phrasesNew[$rc]=$phrasesUsed[$rc]	; restore unencrypted
				EndIf
			EndIf
		Next

		FileCopy($CS_dumppath & "phrasesEncryp.txt",$CS_dumppath & "phrasesNew.txt",1)
		SplashOff()
	EndIf

	If $MCF_ENCRYPT_STRINGS=True Then
		If $showProgress=True Then SplashTextOn("","Preparing Array...",250,40,-1,-1,1+32,"Verdana",10)
		$stringsEncryp=$stringsNew

		For $rc=1 To $stringsEncryp[0]
			If $showProgress=True And Mod($rc,100)=0 Then _
				SplashTextOn("","Encrypting Strings (" & _Min(99,Floor(100*$rc/$stringsEncryp[0])) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)

			; check code section (before, inside, after MCFinclude)
			$curstring="{string" & $rc & "}"		; not collected in sequence, so lookup

			; determine keytype
			Select
				Case _ArraySearch($strings2,$curstring)>0	; in MCFinclude (smallest array to check)
					$keytype=0

				Case _ArraySearch($strings1,$curstring)>0	; prior to MCFinclude
					$stringsEncryp[$rc]=$stringsNew[$rc]	; original content (updated with transl/obfusc)
					ContinueLoop

				Case Else											; after MCFinclude
					If $MCF_ENCRYPT_SHUFFLEKEY=True Then
						$keytype=Random($CCkeyshuffle_start,$CCkeyshuffle_end,1)
					Else
						$keytype=$CCkeytype
					EndIf
			EndSelect

			; determine call structure
			Switch $MCF_ENCRYPT_NESTED
				Case True
					$_MCFcall=$_MCFCCXA
					$brackets="))"
				Case Else
					$_MCFcall=$_MCFCC
					$brackets=")"
			EndSwitch

			; encrypt string
			$stringsEncryp[$rc]=$_MCFcall & "(" & _EncryptEntry(StringTrimLeft(StringTrimRight($stringsEncryp[$rc],1),1),$keytype,False) & $brackets

		Next
		_FileWriteFromArray($CS_dumppath & "stringsEncryp.txt",$stringsEncryp,1)

		; exclude default Func parameter strings
		$inputfile="MCF0.txt"
		$fhin=FileOpen($CS_dumppath & $inputfile)
		If @error Or $fhin=-1 Then Return SetError(_ErrorHandler(-3,"opening file " & $inputfile,$procname),0,False)

		If $showProgress=True Then SplashTextOn("","Post-processing; please wait...",250,40,-1,-1,1+32,"Verdana",10)
		$linesdone=0
		While True

			$curline=FileReadLine($fhin)
			If @error Then	ExitLoop

			$curline=StringStripWS($curline,1)
			$linesdone+=1
			If $showProgress=True And Mod($linesdone,500)=0 And $totalines>0 Then _
				SplashTextOn("","Post-processing (" & _Min(99,Floor(100*$linesdone/$totalines)) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)

			If StringInStr($curline,"{string")<1 Then ContinueLoop
			If StringLeft($curline,1)="#" Then ContinueLoop

			$split=StringSplit($curline,"{string",1)
			For $rc=2 To $split[0]
				$pos=StringInStr($split[$rc],"}")
				If $pos>0 Then
					$index=StringLeft($split[$rc],$pos-1)
					If $index>0 And $index<=$stringsNew[0] Then
						If StringLeft($curline,5)="Func " Then
							$stringsEncryp[$index]=$stringsNew[$index]	; restore original string if default $var content in func def
						ElseIf $MCF_ENCRYPT_SUBSET=True Then
							If _ArraySearch($strings1,"{string" & $index & "}")>0 Then ContinueLoop
							If _ArraySearch($strings2,"{string" & $index & "}")>0 Then ContinueLoop

							Select
								Case $subset_definition>0 And $subset_definition<1	; random proportion
									If Random(0,1)>$subset_definition Then _
										$stringsEncryp[$index]=$stringsNew[$index]	; restore original string
								Case $subset_definition>1									; cycle
									If Mod($rc,$subset_definition)=0 Then _
										$stringsEncryp[$index]=$stringsNew[$index]	; restore original string
							EndSelect
						EndIf
					EndIf
				Endif
			Next

		WEnd
		FileClose($fhin)

		; any defined subset is reflected in $stringsNew[]
		If $showProgress=True Then SplashTextOn("","Saving Array...",250,40,-1,-1,1+32,"Verdana",10)
		$stringsNew=$stringsEncryp	; up to here, $stringsNew[] contained Used/Translated strings
		_FileWriteFromArray($CS_dumppath & "stringsNew.txt",$stringsNew,1)
	EndIf
	$strings1=0	; no longer needed
	$strings2=0
	SplashOff()

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _EncryptEntry($inputstring,$keytype,$AddSpaces=True)
; relies on globals defined in MCFinclude.au3
; you can change the ENcryption calls with whatever decryption algorithm you like
; as long as you also change the DEcryption call in MCFinclude.au3 (or its alternative)
; AND global variable $MCFinclude defined there, if using a different-named MCFinclude

	Switch $AddSpaces
		Case True	; same content = different encryption
			$pass1='"' & _AesEncrypt($CCkey[$keytype], _StringRepeat(" ",Random(0,4,1)) & $inputstring & _StringRepeat(" ",Random(0,4,1))) & '"'

		Case Else							; same content = same encryption
			$pass1='"' & _AesEncrypt($CCkey[$keytype], $inputstring) & '"'
	EndSwitch

	Switch $MCF_ENCRYPT_NESTED
		Case True
			Return "'" & _AesEncrypt($CCkey[0],$_MCFCC & "(" & $pass1 & "," & $keytype & ")") & "'"

		Case Else
			Switch $keytype
				Case 0	; default option requires no explicit parameter
					Return $pass1

				Case Else
					Return $pass1 & "," & $keytype
			EndSwitch
	EndSwitch

EndFunc


Func _ObfuscateArrays($path,$force_refresh=False)		; preprocessing pass, affects arrays only
; expects $MCF_OBFUSCATE_UDFS and $MCF_OBFUSCATE_VARS set as desired

	$procname="_ObfuscateArrays"
	_CallStack_Push($procname)

	; check path
	If _FillCSpath($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,False)

	SRandom(@AutoItPID + @MSEC)
	$hextemplate=_RandomHex($Obfstringwidth)

	If $MCF_OBFUSCATE_VARS=True Then
		$MCF_REPLACE_VARS=True
		If _ObfuscateNames($variablesUsed,$variablesTransl,$hextemplate)=False Then Return SetError(_ErrorHandler(-1,"obfuscating variables has failed",$procname),0,False)
		_FileWriteFromArray($CS_dumppath & "variablesTransl.txt",$variablesTransl,1)
	EndIf

	If $MCF_OBFUSCATE_UDFS=True Then
		$MCF_REPLACE_UDFS=True
		If _ObfuscateNames($functionsUsed,$functionsTransl,$hextemplate)=False Then Return SetError(_ErrorHandler(-1,"obfuscating UDFs has failed",$procname),0,False)
		_FileWriteFromArray($CS_dumppath & "functionsTransl.txt",$functionsTransl,1)
	EndIf

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _ObfuscateNames(ByRef $inputarray, ByRef $outputarray,$hextemplate)

	$procname="_ObfuscateNames"
	_CallStack_Push($procname)

	If UBound($inputarray)=1 Then Return SetError(_ErrorHandler(-1,"array to obfuscate is empty",$procname),0,False)

	If StringLeft($inputarray[1],1)="$" Then
		$prefix="$"
	Else
		$prefix="_"
	EndIf

	$inserts=1	; 1:6, 1:8, 2:10, 2:12, 3:14 changed
	$startpos=($Obfstringwidth/2)-2
	$endpos=($Obfstringwidth/2)+2
	$newname=""

	If $showProgress=True Then SplashTextOn("","Preparing Array...",250,40,-1,-1,1+32,"Verdana",10)
	$outputarray=$inputarray

	For $rc=1 To $inputarray[0]
		If $showProgress=True And Mod($rc,100)=0 Then _
			SplashTextOn("","Obfuscating (" & _Min(99,Floor(100*$rc/$inputarray[0])) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)
		If StringLeft($inputarray[$rc],8)="$cmdline" Then ContinueLoop	; special case (keep intact); includes $cmdlineraw

		$tries=0
		$newname=""
		Do
			$tries+=1
			If $tries>16 then
				$startpos-=1
				$endpos+=1
				If $startpos<2 Or $endpos>=StringLen($hextemplate) Then Return SetError(_ErrorHandler(-2,"obfuscation template too short",$procname),0,False)
				If Mod($startpos,2)=0 Then $inserts+=1
				$tries=1
			EndIf
			$newname=$hextemplate
			For $cc=1 To $inserts
				$pos=Random($startpos,$endpos,1)
				$newname=StringLeft($newname,$pos-1) & _RandomHex(1) & StringTrimLeft($newname,$pos)
			Next
		Until _ArraySearch($namesUsed,$newname)<0	; ensure unique name
		_ArrayAdd($namesUsed,$newname,0,Chr(0))	; no prefix here
		$outputarray[$rc]=$prefix & $newname
		$newname=""
	Next
	SplashOff()

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _TranslateVarsInStrings($path)
; Suggestions: translate variablesTransl.txt and functionsTransl.txt by hand
; you can use web services to translate stringsTransl.txt (but check/edit output)
; be extra careful with struct definitions and system call parameters
; for example, Google Translate will insert script-breaking spaces into "\\.\physicaldrive0"

	If $MCF_TRANSLATE_VARS=True Then
		For $rc=1 To $variablesUsed[0]
			$curvarname=StringTrimLeft($variablesUsed[$rc],1)	; clip prefix '$'
			$newvarname=StringTrimLeft($variablesTransl[$rc],1)	; clip prefix '$'
			If $curvarname=$newvarname Then ContinueLoop

			; var name has changed in translation, so replace in StringsTransl[]
			For $cc=1 To $stringsTransl[0]		; case without "$" prefix (case with  "$" prefix is MetaCoded)
				If _ArraySearch($skipRegExpStrings,$cc,1)>0 Then ContinueLoop
				If StringTrimLeft($stringsTransl[$cc],1)=$curvarname Then _
					$stringsTransl[$cc]=$newvarname
			Next
		Next
	EndIf
	_FileWriteFromArray($CS_dumppath & "stringsTransl.txt",$stringsTransl,1)

EndFunc

#endregion Content-altering

#region Output-related

Func _BackTranslate($path,$force_refresh=False)		; create MCF0.au3 directly from MCF0.txt

	$procname="_BackTranslate"
	_CallStack_Push($procname)

	; environment checks/prep
	If _FillCSpath($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,false)

	If Number(FileGetTime($CS_dumppath & "MCF0.txt",0,1)) < _
		Number(FileGetTime($CS_dumppath & "MCF1.txt",0,1)) Then _
		_CreateSingleBuild($CS_dumppath,True)

	$MCF_REPLACE_AUFUNCS	=True
	$MCF_REPLACE_UDFS		=True
	$MCF_REPLACE_VARS		=True
	$MCF_REPLACE_STRINGS	=True
	$MCF_REPLACE_MACROS	=True
	$MCF_WRITE_COMMENTS	=True

	; parsing original arrays
	$totalerrors=_EncodeMCF($path,$phrases,$AU3Functions,$functionsUsed,$variablesUsed,$stringsUsed,$macros)

	_CallStack_Pop($procname)
	Return $totalerrors
EndFunc


Func _CreateNewScript($path,$force_refresh=False,$inputfile="",$outputfile="MCF0_New.au3")

	$procname="_CreateNewScript"
	_CallStack_Push($procname)

	; environment checks/prep
	If _FillCSpath($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,false)

	$MCF_REPLACE_AUFUNCS	=True
	$MCF_REPLACE_UDFS		=True
	$MCF_REPLACE_VARS		=True
	$MCF_REPLACE_STRINGS	=True
	$MCF_REPLACE_MACROS	=True
	$MCF_WRITE_COMMENTS	=True

	; parsing original arrays
	$totalerrors=_EncodeMCF($path,$phrasesNew,$AU3Functions,$functionsNew,$variablesNew,$stringsNew,$macros)

	_CallStack_Pop($procname)
	Return $totalerrors
EndFunc


Func _RebuildScript($path,$force_refresh=False, $inputfile="",$outputfile="MCF0.au3")

	$procname="_RebuildScript"
	_CallStack_Push($procname)
	If $uselogfile Then _FileWriteLog($fhlog,$procname & " started...")

	; check path, reload arrays
	If _FillCSpath($path,$force_refresh)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,-1)	; return nonzero totalerrors

	If ($MCF_PHRASING Or $MCF_ENCRYPT)=True Then
		Global $MCF_file_ID=_ArraySearch($includes,"\"&$MCFinclude,1,0,0,1)
		If $MCF_file_ID<1 Then Return SetError(_ErrorHandler(-2,'MCFinclude file "' & $MCFinclude & '" not found among #includes',$procname),0,-1)	; return nonzero totalerrors
	EndIf

	; affects structure; indirection precedes phrasing and encryption
	If $MCF_INDIRECTION=True Then
		If _IndirectMCF($path)=False Then Return SetError(_ErrorHandler(-3,"indirection failed",$procname),0,-1)
	EndIf

	If $MCF_PHRASING=True And $MCF_ENCRYPT=False Then
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": phrasing started...")
		If _PhraseMCF($path)=False Then Return SetError(_ErrorHandler(-4,"phrasing failed",$procname),0,-1)	; _EncryptArrays() calls _PhraseMCF(), but _PhraseMCF() can also be called on its own
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": phrasing completed.")
	EndIf

	; affects content
	If $MCF_OBFUSCATE Then	; updates *Transl[]
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": obfuscation started...")
		If _ObfuscateArrays($path)=False Then Return SetError(_ErrorHandler(-6,"obfuscation failed",$procname),0,-1)
				If $uselogfile Then _FileWriteLog($fhlog,$procname & ": obfuscation completed.")
	EndIf

	; affects content
	If $MCF_TRANSLATE Or $MCF_OBFUSCATE_VARS=True Then 	; NB edit $variablesTransl.txt and/or $FunctionsTransl.txt yourself beforehand
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": translation started...")
		_TranslateVarsInStrings($path)
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": translation finished." & @CRLF & @CRLF)
	EndIf

	; prepare *New arrays for _EncryptArrays() and _EncodeMCF()
	If $showProgress=True Then SplashTextOn("","Saving Arrays...",250,40,-1,-1,1+32,"Verdana",10)
	If ($MCF_OBFUSCATE_UDFS Or $MCF_TRANSLATE_UDFS)=True Then
		$functionsNew=$functionsTransl
	Else
		$functionsNew=$functionsUsed	; ensure no garbage from previous runs
	EndIf
	_FileWriteFromArray($CS_dumppath & "functionsNew.txt",$functionsNew,1)

	If ($MCF_OBFUSCATE_VARS Or $MCF_TRANSLATE_VARS)=True Then
		$variablesNew=$variablesTransl
	Else
		$variablesNew=$variablesUsed	; ensure no garbage from previous runs
	EndIf
	_FileWriteFromArray($CS_dumppath & "variablesNew.txt",$variablesNew,1)
	SplashOff()

	; encode MC in $stringsNew[]
	If ($MCF_TRANSLATE Or $MCF_OBFUSCATE)=True Then
		_ReplaceMCinArray($stringsTransl,$stringsNew,$functionsNew,$variablesNew,$stringsNew)	; param $stringsNew is a dummy here (no MC {string#} inside)
	Else
		_ReplaceMCinArray($stringsUsed,$stringsNew,$functionsNew,$variablesNew,$stringsNew)	; param $stringsNew is a dummy here (no MC {string#} inside)
	EndIf

	; NB expects $CCkey[] and $CCkeytype to be defined
	If $MCF_ENCRYPT=True Then
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": encryption started...")
		; uses *New[] arrays; calls _PhraseMCF(); fills and writes out stringsNew[],phrasesNew[]
		If _EncryptArrays($path)=False Then Return SetError(_ErrorHandler(-7,"encryption failed",$procname),0,-1)
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": encryption completed.")
	Else							; keep our bookkeeping consistent
		_FileWriteFromArray($CS_dumppath & "stringsNew.txt",$stringsNew,1)

		; phrases used without encryption, so prep the buffers anyway
		If UBound($phrases)>1 then
			_ReplaceMCinArray($phrases,$phrasesNew,$functionsNew,$variablesNew,$stringsNew)	; remove all MCtags in phrases
			_FileWriteFromArray($CS_dumppath & "phrasesNew.txt",$phrasesNew,1)

			; added for consistency only
			; (arrays *Used/Transl[] should contain clearcode, *New[] whatever is used to encode)
			FileCopy($CS_dumppath & "phrasesNew.txt",$CS_dumppath & "phrasesUsed.txt",1)
		EndIf
	EndIf

	$MCF_REPLACE_AUFUNCS	=True
	$MCF_REPLACE_UDFS		=True
	$MCF_REPLACE_VARS		=True
	$MCF_REPLACE_STRINGS	=True
	$MCF_REPLACE_MACROS	=True
	$MCF_REPLACE_PHRASES	=True

	; always False in final output, unless unencrypted and unobfuscated and preset to True
	$MCF_WRITE_COMMENTS=((Not ($MCF_ENCRYPT Or $MCF_OBFUSCATE)) And $MCF_WRITE_COMMENTS)

	; determine which structural template to use
	If $inputfile="" Then
		If $MCF_PHRASING=True Then		; phrasing incorporates indirection if indirection was enabled
			$inputfile="MCF0_phrased.txt"
		ElseIf $MCF_INDIRECTION=True Then
			$inputfile="MCF0_indirected.txt"
		Else
			$inputfile="MCF0.txt"
		EndIf
	EndIf

	; create MCF0.au3 from MCF0.txt in CS_dumppath
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": creating MCF0.au3...")
	$totalerrors=_EncodeMCF($path,$phrasesNew,$AU3Functions,$functionsNew,$variablesNew,$stringsNew,$macros,$inputfile,$outputfile)
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": MCF0.au3 created; total errors: " & $totalerrors)

	If $uselogfile Then _FileWriteLog($fhlog,$procname & " finished." & @CRLF & @CRLF)
	_CallStack_Pop($procname)
	Return $totalerrors
EndFunc


Func _EncodeMCF($path, ByRef $phrasesNew, ByRef $AU3FunctionsNew, ByRef $functionsNew, ByRef $variablesNew, ByRef $stringsNew, ByRef $macrosNew,$inputfile="MCF0.txt",$outputfile="MCF0.au3")

	$procname="_EncodeMCF"
	_CallStack_Push($procname)

	$testfile=StringLeft($path,StringInStr($path,"\",0,-2)) & "MCF0test.au3"

	$inputfile=$path & $inputfile
	$fhin=FileOpen($inputfile)
	If @error Or $fhin=-1 Then Return SetError(_ErrorHandler(-2,"opening file " & $inputfile,$procname),0,-1)	; return nonzero totalerrors

	$outputfile=$path & $outputfile
	$fhout=FileOpen($outputfile,2)
	If @error Or $fhout=-1 Then
		FileClose($fhin)
		Return SetError(_ErrorHandler(-3,"opening file " & $outputfile,$procname),0,-1)	; return nonzero totalerrors
	EndIf

	If $showProgress=True Then SplashTextOn("","Encoding MCF; please wait...",250,40,-1,-1,1+32,"Verdana",10)
	$logfile=$CS_dumppath & "MCFencoding.log"
	If FileExists($logfile) Then FileDelete($logfile)
	$fhlogcc=FileOpen($logfile,1)
	If @error Or $fhlogcc=-1 Then
		FileClose($fhin)
		FileClose($fhout)
		Return SetError(_ErrorHandler(-1,"opening file " & $logfile,$procname),0,-1)
	EndIf
	FileWriteLine($fhlogcc,_NowCalc() & ": MCF Encoding Logging initiated.")
	FileWriteLine($fhlogcc,@CRLF & "Encoding Settings:")
	FileWriteLine($fhlogcc,"MCF_REPLACE_AUFUNCS = " & $MCF_REPLACE_AUFUNCS)
	FileWriteLine($fhlogcc,"MCF_REPLACE_UDFS = " & $MCF_REPLACE_UDFS)
	FileWriteLine($fhlogcc,"MCF_REPLACE_VARS = " & $MCF_REPLACE_VARS)
	FileWriteLine($fhlogcc,"MCF_REPLACE_STRINGS = " & $MCF_REPLACE_STRINGS)
	FileWriteLine($fhlogcc,"MCF_REPLACE_MACROS = " & $MCF_REPLACE_MACROS)
	FileWriteLine($fhlogcc,"MCF_REPLACE_PHRASES = " & $MCF_REPLACE_PHRASES)
	FileWriteLine($fhlogcc,"MCF_ENCRYPT_SUBSET = " & $MCF_ENCRYPT_SUBSET)
	FileWriteLine($fhlogcc,"MCF_WRITE_COMMENTS = " & $MCF_WRITE_COMMENTS & @CRLF & @CRLF)

	$addtab=""
	$linesdone=0
	$errortotal=0
	$errorcountvar=0
	$errorcountmacro=0
	$errorcountstring=0
	$errorcountfunc=0
	$errorcountfuncA=0
	$errorcountfuncU=0
	$errorcountSMC=0		; self-modifying/evaluating code (Execute,Assign,Eval,IsDefined)
	$errorcountother=0
	$errorcountresidual=0
	$errorlinetoolong=0
	$prevlineblank=false

	While True
		$curline=FileReadLine($fhin)
		If @error Then	ExitLoop

		$curline=StringStripWS($curline,1+2)
		$linesdone+=1
		If $showProgress=True And Mod($linesdone,500)=0 And $totalines>0 Then _
			SplashTextOn("","Encoding MCF (" & _Min(99,Floor(100*$linesdone/$totalines)) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)

		; empty line
		If $curline="" Then
			If $prevlineblank=False Then
				FileWriteLine($fhout,"")
				$prevlineblank=True
			Else
				$linesdone-=1
			EndIf
			ContinueLoop
		EndIf
		$prevlineblank=false

		; pure comment line
		If StringLeft($curline,1)=";" Then
			If $MCF_WRITE_COMMENTS=False Then ContinueLoop
			$pos=StringInStr($curline,$timestamptag)
			If $pos>0 Then $curline=StringLeft($curline,$pos+StringLen($timestamptag)-1) & @YEAR& "-" & @MON & "-" & @MDAY & ", at " & @HOUR & ":" & @MIN& ":" & @SEC
			If StringLeft($curline,3)<>"; {" Then FileWriteLine($fhout,$curline)
			ContinueLoop
		EndIf

		; clip comments
		$commentail=" "
		$pos0=Stringinstr($curline,";",0,-1)
		If $pos0>0 Then
			If $MCF_WRITE_COMMENTS=True Then $commentail&=StringTrimLeft($curline,$pos0-1)
			$curline=StringLeft($curline,$pos0-1)
		EndIf
		$newline=$curline

		; replace all phrases (conditionals and calls)
		If $MCF_REPLACE_PHRASES=True Then
			$split=StringSplit($newline,"{phrase",1)
			For $rc=2 To $split[0]
				$curMC=$split[$rc]
				$pos=StringInStr($curMC,"}")
				$index=StringMid($curMC,1,$pos-1)
				If $index>0 And $index<=$phrasesNew[0] Then
					$realcode=$phrasesNew[$index] & StringTrimLeft($curMC,$pos)
				Else
					$realcode="{" & $errortag & "MC ref "&StringLeft($curMC,$pos)&" NOT FOUND}"
					FileWriteLine($fhlogcc,_NowCalc() & ": " & $newline & @CRLF & $realcode & @CRLF)
					$errorcountvar+=1
				EndIf
				$split[$rc]=$realcode
			Next
			$newline=_ArrayToString($split,"",1)
		EndIf

		; replace all strings
		$stringbrokenup=False
		If $MCF_REPLACE_STRINGS=True Then
			$split=StringSplit($newline,"{string",1)
			For $rc=2 To $split[0]
				$curMC=$split[$rc]
				$realcode="{string" & $curMC	; preset restore contents; replaced if $realcode changes
				; check that the next char in the MCtag is a digit
				If StringRegExp(StringLeft($curMC,1),"[0-9]",0) Then
					$pos=StringInStr($curMC,"}")
					$index=StringLeft($curMC,$pos-1)
					If $index>0 And $index<=$stringsNew[0] Then
						$curstring=$stringsNew[$index]	; replace with MC-filled strings in case replacing with something else
						$realcode=$curstring & StringTrimLeft($realcode,$pos+7)
					Else
						$realcode="{" & $errortag & "MC ref "&StringLeft($curMC,$pos)&" NOT FOUND}"
						FileWriteLine($fhlogcc,_NowCalc() & ": " & $newline & @CRLF & $realcode & @CRLF)
						$errorcountstring+=1
					EndIf
				EndIf
				$split[$rc]=$realcode
				$prevchar=StringRight(StringStripWS($split[$rc-1],2),1)
				If $prevchar="," Or $prevchar="&" Then
					$split[$rc]=" _" & @CRLF & $addtab & @TAB & $realcode
					$stringbrokenup=True
				EndIf
			Next
			$newline=_ArrayToString($split,"",1)
		EndIf

		; replacing {var#}, {macro#}, and {func*#}
		$split=StringSplit($newline,"{",1)
		For $rc=2 To $split[0]
			$curMC=$split[$rc]
			$realcode=$split[$rc]
			$pos=StringInStr($curMC,"}")
			Select
				Case StringLeft($curMC,3)="var" And StringRegExp(StringMid($curMC,4,1),"[0-9]",0)	; next char=?isdigit
					If $MCF_REPLACE_VARS=True Then
						$index=StringMid($curMC,4,$pos-4)
						If $index>0 And $index<=$variablesNew[0] Then
							$realcode=$variablesNew[$index]
						Else
							$realcode="{" & $errortag & "MC ref "&StringLeft($curMC,$pos)&" NOT FOUND}"
							FileWriteLine($fhlogcc,_NowCalc() & ": " & $newline & @CRLF & $realcode & @CRLF)
							$errorcountvar+=1
						EndIf
					EndIf
				Case StringLeft($curMC,4)="func" And StringRegExp(StringMid($curMC,6,1),"[0-9]",0)	; next char=?isdigit
					$functype=StringMid($curMC,5,1)
					$index=StringMid($curMC,6,$pos-6)	; add extra char for A/U marker
					Switch $functype
						Case "A"
							If $MCF_REPLACE_AUFUNCS=True Then
								If $index>0 And $index<=$AU3FunctionsNew[0] Then
									$realcode=$AU3FunctionsNew[$index]
									Switch $realcode	; self-modifying code or indirect variable-name referencing
										Case "Assign"
											$errorcountSMC+=1
										Case "Eval"
											$errorcountSMC+=1
										Case "Execute"
											$errorcountSMC+=1
										Case "IsDeclared"
											$errorcountSMC+=1
									EndSwitch
								Else
									$realcode="{" & $errortag & "MC ref "&StringLeft($curMC,$pos)&" NOT FOUND}"
									FileWriteLine($fhlogcc,_NowCalc() & ": " & $newline & @CRLF & $realcode & @CRLF)
									$errorcountfuncA+=1
								EndIf
							EndIf
						Case "U"
							If $MCF_REPLACE_UDFS=True Then
								If $index>0 And $index<=$FunctionsNew[0] Then
									$realcode=$FunctionsNew[$index]
								Else
									$realcode="{" & $errortag & "MC ref "&StringLeft($curMC,$pos)&" NOT FOUND}"
									FileWriteLine($fhlogcc,_NowCalc() & ": " & $newline & @CRLF & $realcode & @CRLF)
									$errorcountfuncU+=1
								EndIf
							EndIf
					EndSwitch
				Case StringLeft($curMC,5)="macro" And StringRegExp(StringMid($curMC,6,1),"[0-9]",0)	; next char=?isdigit
					If $MCF_REPLACE_MACROS=True Then
						$index=StringMid($curMC,6,$pos-6)
						If $index>0 And $index<=$macrosNew[0] Then
							$realcode=$macrosNew[$index]
						Else
							$realcode="{" & $errortag & "MC ref "&StringLeft($curMC,$pos)&" NOT FOUND}"
							FileWriteLine($fhlogcc,_NowCalc() & ": " & $newline & @CRLF & $realcode & @CRLF)
							$errorcountmacro+=1
						EndIf
					EndIf
			EndSelect
			If $split[$rc]<>$realcode Then
				$split[$rc]=$realcode & StringTrimLeft($curMC,$pos)
			Else
				$split[$rc]="{" & $split[$rc]		; restore original
			EndIf
		Next
		$newline=_ArrayToString($split,"",1)

		; check for any residual MC tags
		$split=StringSplit($newline,"{")
		For $rc=1 To $split[0]
			$residual=False
			Select
				Case StringLeft($split[$rc],4)="phrase" And StringRegExp(StringMid($split[$rc],5,1),"[0-9]",0)	; next char=?isdigit
					If $MCF_REPLACE_PHRASES=True Then
						$errorcountresidual+=1
						$residual=True
					EndIf
				Case StringLeft($split[$rc],4)="incl" And StringRegExp(StringMid($split[$rc],5,1),"[0-9]",0)	; next char=?isdigit
					$errorcountresidual+=1
					$residual=True
				Case StringLeft($split[$rc],5)="funcA" And StringRegExp(StringMid($split[$rc],6,1),"[0-9]",0); next char=?isdigit
					If $MCF_REPLACE_AUFUNCS=True Then
						$errorcountresidual+=1
						$residual=True
					EndIf
				Case StringLeft($split[$rc],5)="funcU" And StringRegExp(StringMid($split[$rc],6,1),"[0-9]",0); next char=?isdigit
					If $MCF_REPLACE_UDFS=True then
						$errorcountresidual+=1
						$residual=True
					EndIf
				Case StringLeft($split[$rc],5)="macro" And StringRegExp(StringMid($split[$rc],6,1),"[0-9]",0); next char=?isdigit
					If $MCF_REPLACE_MACROS=True Then
						$errorcountresidual+=1
						$residual=True
					EndIf
				Case StringLeft($split[$rc],6)="string" And StringRegExp(StringMid($split[$rc],7,1),"[0-9]",0); next char=?isdigit
					If $MCF_REPLACE_STRINGS=True Then
						$errorcountresidual+=1
						$residual=True
					EndIf
				Case StringLeft($split[$rc],3)="var" And StringRegExp(StringMid($split[$rc],4,1),"[0-9]",0)	; next char=?isdigit
					If $MCF_REPLACE_VARS=True Then
						$errorcountresidual+=1
						$residual=True
					EndIf
			EndSelect
		Next

		If StringLeft($curline,8)="EndFunc " Then $addtab=""
		$newline=$addtab & StringStripWS($newline & $commentail,2)

		; write single line or multiline
		If StringLen($newline)<4096 Then
			FileWriteLine($fhout,$newline)

		Else
			$linelength=StringLen($newline)
			$singlecount=0
			$doublecount=0
			Local $markers[1]		; this method is overkill at the moment
			Local $locations[1]	; but provides scope for improvement later
			For $cc=1 To StringLen($newline)
				$curchar=StringMid($newline,$cc,1)
				Switch $curchar
					Case "'"
						_Arrayadd($markers,1,0,Chr(0))
						_Arrayadd($locations,$cc,0,Chr(0))
						$singlecount+=1
					Case '"'
						_Arrayadd($markers,2,0,Chr(0))
						_Arrayadd($locations,$cc,0,Chr(0))
						$doublecount+=1
				EndSwitch
			Next
			$markers[0]=UBound($markers)-1
			If $markers[0]=0 Then Return SetError(_ErrorHandler(-4,"line too long " & $outputfile,$procname),0,-1)

			$locations[0]=$markers[0]
			$firstsingle=0
			$lastsingle=0
			$firstdouble=0
			$lastdouble=0
			For $cc=1 To $locations[0]
				switch $markers[$cc]
					Case 1
						If $lastsingle=0 Then $firstsingle=$locations[$cc]
						$lastsingle=$locations[$cc]
					Case 2
						If $lastdouble=0 Then $firstdouble=$locations[$cc]
						$lastdouble=$locations[$cc]
				EndSwitch
			Next

			Select
				; single long string enclosed in single quotes
				Case $singlecount=2 And $doublecount=0 And $firstsingle<1024 And $lastsingle>$linelength-1024
					For $cc=1 To ceiling($linelength/1024)
						If $cc<ceiling($linelength/1024) Then
							FileWrite($fhout, StringMid($newline,1+(($cc-1)*1024),1024) & "' _ " & $commentail & @CRLF & @TAB & "'")
						Else
							FileWriteLine($fhout,StringMid($newline,1+(($cc-1)*1024),1024))
						EndIf
					next

				; single long string enclosed in double quotes
				Case $doublecount=2 And $singlecount=0 And $firstdouble<1024 And $lastdouble>$linelength-1024
					For $cc=1 To ceiling($linelength/1024)
						If $cc<ceiling($linelength/1024) Then
							FileWrite($fhout,StringMid($newline,1+(($cc-1)*1024),1024) & '" _ ' & $commentail & @CRLF & @TAB & "'")
						Else
							FileWriteLine($fhout,StringMid($newline,1+(($cc-1)*1024),1024))
						EndIf
					next

				Case Else	; room for improvement here... (disentangling nested string markers)
					FileWriteLine($fhout,$newline)	; write out anyway, so user can fix it
					If $stringbrokenup=False Then
						$errorlinetoolong+=1
						If $showProgress=True Then ConsoleWrite("Line too long: " & $linesdone & @CR)
					EndIf
			EndSelect
		EndIf	; write single line or multiline

		If StringLeft($curline,5)="Func " Then $addtab=@TAB

	WEnd
	FileClose($fhout)
	FileClose($fhin)
	Sleep(250)	; allow some time to release handles

	; NB $errorcountSMC is ignored here (may still work)
	$errortotal=$errorcountvar+$errorcountstring+$errorcountmacro+$errorcountfunc+$errorcountfuncA+$errorcountfuncU+$errorcountresidual+$errorcountother+$errorlinetoolong

	If $errortotal=0 And FileGetSize($outputfile)>0 Then
		FileCopy($outputfile,$testfile,1)
	Else
		If FileExists($testfile) Then FileDelete($testfile)	; to avoid confusion witht earlier output
	EndIf

	SplashOff()
	If $showProgress=True And $errortotal>0 Then
		Global $report="Potential encoding issues:"  & @CRLF & @CRLF & _
					"Variable-related issues: " & $errorcountvar & @CRLF & _
					"String-related issues: " & $errorcountstring & @CRLF & _
					"Macro-related issues: " & $errorcountmacro & @CRLF & _
					"AutoIt-related issues: " & $errorcountfuncA & @CRLF & _
					"UDF-related issues: " & $errorcountfuncU & @CRLF & _
					"Unknnown function issues: " & $errorcountfunc & @CRLF & _
					"Residual MC issues: " & $errorcountresidual & @CRLF & _
					"Other MC issues: " & $errorcountother & @CRLF & @CRLF & _
					"Lines too long: " & $errorlinetoolong & @CRLF & @CRLF & _
					"Total number of issues: " & $errortotal & @CRLF
		MsgBox(0,"MCF Report",$report & @CR & "An error log has been written to:" & @CR & $logfile)
	Else
		Global $report="No problems found." & @CRLF
	EndIf
	FileWriteLine($fhlogcc,_NowCalc() & ": " & @CRLF & $report & @CRLF)
	FileWriteLine($fhlogcc,_NowCalc() & ": MCF Encoding completed.")
	FileClose($fhlogcc)

	_CallStack_Pop($procname)
	Return $errortotal-$errorlinetoolong	; overlong lines can easily be fixed by user
EndFunc


Func _ReplaceMCinArray(ByRef $inputarray, ByRef $outputarray, ByRef $functions, ByRef $variables, ByRef $strings)
; replacing {strings},{var#}, {macro#}, and {func*#}; all errors are suppressed
; {funcA#} and {macro#} are replaced from the original full sets
; the rest is replaced from whatever arrays are parsed

	If $showProgress=True Then SplashTextOn("","Preparing Array...",250,40,-1,-1,1+32,"Verdana",10)
	$outputarray=$inputarray	; copy array

	For $cc=1 To $inputarray[0]
		If $showProgress=True And Mod($cc,100)=0 Then _
			SplashTextOn("","Processing MetaCodes (" & _Min(99,Floor(100*$cc/$inputarray[0])) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)

		$curstring=$inputarray[$cc]
		If StringInStr($curstring,"{")<1 Then ContinueLoop

		$split=StringSplit($curstring,"{",1)
		For $rc=2 To $split[0]
			$curMC=$split[$rc]
			$realcode=$split[$rc]
			$pos=StringInStr($curMC,"}")
			Select
				Case StringLeft($curMC,3)="var" And StringRegExp(StringMid($curMC,4,1),"[0-9]",0)	; next char=?isdigit
					If $MCF_REPLACE_VARS=True Then
						$index=StringMid($curMC,4,$pos-4)
						If $index>0 And $index<=$variables[0] Then $realcode=$variables[$index]
					EndIf

				Case StringLeft($curMC,4)="func" And StringRegExp(StringMid($curMC,6,1),"[0-9]",0)	; next char=?isdigit
					$functype=StringMid($curMC,5,1)
					$index=StringMid($curMC,6,$pos-6)	; add extra char for A/U marker
					Switch $functype
						Case "A"
							If $MCF_REPLACE_AUFUNCS=True Then
								If $index>0 And $index<=$AU3Functions[0] Then $realcode=$AU3Functions[$index]
							EndIf
						Case "U"
							If $MCF_REPLACE_UDFS=True Then
								If $index>0 And $index<=$Functions[0] Then $realcode=$Functions[$index]
							EndIf
					EndSwitch

				Case StringLeft($curMC,5)="macro" And StringRegExp(StringMid($curMC,6,1),"[0-9]",0)	; next char=?isdigit
					If $MCF_REPLACE_MACROS=True Then
						$index=StringMid($curMC,6,$pos-6)
						If $index>0 And $index<=$macros[0] Then $realcode=$macros[$index]
					EndIf

				; this case does not apply when target array is strings*[]
				Case StringLeft($curMC,6)="string" And StringRegExp(StringMid($curMC,7,1),"[0-9]",0)	; next char=?isdigit
					If $MCF_REPLACE_STRINGS=True Then
						$index=StringMid($curMC,7,$pos-7)
						If $index>0 And $index<=$strings[0] Then $realcode=$strings[$index]
					EndIf
			EndSelect

			If $split[$rc]<>$realcode Then
				$split[$rc]=$realcode & StringTrimLeft($curMC,$pos)
			Else
				$split[$rc]="{" & $split[$rc]		; restore line
			EndIf
		Next
		$outputarray[$cc]=_ArrayToString($split,"",1)
	Next
	SplashOff()

EndFunc

#endregion Output-related

#region auxiliary

Func _CallStack_Pop($procname)
	If $procname="" Then Return
	If $CallStack[UBound($CallStack)-1]=$procname Then _ArrayPop($CallStack)
EndFunc


Func _CallStack_Push($procname)
	If $procname="" Then Return
	_ArrayAdd($Callstack,$procname,0,Chr(0))
	$ShowErrorMsg=True
EndFunc


Func _ClearArrays($path)	; copies stored arrays from *Used.txt

	$procname="_ClearArrays"
	_CallStack_Push($procname)

	If Not FileExists($path & ".") Then Return SetError(_ErrorHandler(-1,"path not found:" & @CR & $path,$procname),0,False)

	If $showProgress=True Then SplashTextOn("","Preparing buffers...",250,40,-1,-1,1+32,"Verdana",10)
	Global $phrases[1]			; MC, filled by _PhraseMCF()
	Global $phrasesUsed[1]		; clearcode, filled by _EncryptArrays()
	Global $phrasesUDF[1]
	Global $phrasesEncryp[1]	; cryptcode, filled by _EncryptArrays()
	Global $phrasesNew[1]
	Global $namesUsed[1]			; list of obfuscation replacements
	$namesUsed[0]=""
	Global $skipRegExpStrings[1]
	$skipRegExpStrings[0]=0

	If FileExists($path & "stringsUsed.txt") Then
		FileCopy($path & "stringsUsed.txt",$path & "stringsTransl.txt",2)
		FileCopy($path & "stringsUsed.txt",$path & "stringsEncryp.txt",2)
		FileCopy($path & "stringsUsed.txt",$path & "stringsNew.txt",2)
	EndIf

	If FileExists($path & "variablesUsed.txt") Then
		FileCopy($path & "variablesUsed.txt",$path & "variablesTransl.txt",2)
		FileCopy($path & "variablesUsed.txt",$path & "variablesEncryp.txt",2)
		FileCopy($path & "variablesUsed.txt",$path & "variablesNew.txt",2)
	EndIf

	If FileExists($path & "functionsUsed.txt") Then
		FileCopy($path & "functionsUsed.txt",$path & "functionsTransl.txt",2)
		FileCopy($path & "functionsUsed.txt",$path & "functionsEncryp.txt",2)
		FileCopy($path & "functionsUsed.txt",$path & "functionsNew.txt",2)
	EndIf
	SplashOff()

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _ErrorHandler($error,$description,$procname,$CallStack_Pop=True)

	$stacktrace= "Call Stack: " & $CallStack[0] & @CRLF
	For $rc=1 To UBound($CallStack)-1
		$stacktrace&=@TAB &"calling " & $CallStack[$rc] & "()" & @CRLF
	Next

	If $description="" Then
		$msg="An unknown error has occurred in function " & $procname & "()" & @CRLF
	Else
		$msg="Error in function" & $procname & "()," & @CRLF & "related to: " & $description & @CRLF
	EndIf
	$msg &= "Error code: " & $error & @CRLF & @CRLF
	$msg &= $stacktrace

	If $uselogfile=True Then _FileWriteLog($fhlog,$msg)

	If $ShowErrorMsg=True Then
		ProgressOff()
		SplashOff()

		MsgBox(262144+4096+16,"MCF: Unable to Proceed",$msg)

		; prevent multiple messages while the same underlying error is
		; working its way back up the calling chain
		$ShowErrorMsg=False
	EndIf

	If $CallStack_Pop=True Then _CallStack_Pop($procname)

	Return $error	; parse back to SetError()
EndFunc


Func _FillCSpath($path,$force_refresh=False)

	$procname="_FillCSpath"
	_CallStack_Push($procname)

	If StringStripWS($path,1+2)="" Then Return SetError(_ErrorHandler(-1,"empty path variable parsed",$procname),0,false)
	If StringRight($path,1)<>"\" Then $path&="\"
	If Not FileExists($path & ".") Then _
		Return SetError(_ErrorHandler(-2,"path not found:" & @CR& $path,$procname),0,False)

	Global $CS_dumppath=$path

	If $force_refresh=True Then
		If _ReadCSDataDump($CS_dumppath,False)=False Then _
			Return SetError(_ErrorHandler(-3,"preparing MCF environment",$procname),0,False)
	EndIf

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _FillSelectedUDFarrays($path,$force_reset=False)
; creates new UDFarrays from $FunctionsUsed_CS, with all UDFs enabled
; or fills UDFarrays with previously stored data, if available and force_reset=False

	$procname="_FillSelectedUDFarrays"
	_CallStack_Push($procname)

	; ensure that the required CS arrays are filled
	_PrepMCenvironment($path,True)

	; check whether valid content was already stored
	If $force_reset=False Then
		If UBound($SelectedUDFname)=UBound($FunctionsUsed_CS) And UBound($FunctionsUsed_CS)>1 Then
			For $rc=1 To UBound($SelectedUDFname)-1
				If $SelectedUDFname[$rc]<>$FunctionsUsed_CS[$rc] Then
					$force_reset=True
					ExitLoop
				EndIf
			Next
		Else
			$force_reset=True
		EndIf

		If $force_reset=False Then
			_CallStack_Pop($procname)
			Return True					; early-out
		EndIf
	EndIf

	; load $SelectedUDFname with all active UDFs (calling and/or called)
	$SelectedUDFname=$FunctionsUsed_CS
	$SelectedUDFname[0]="Main Script"

	$listsize=$FunctionsUsed_CS[0]
	Global $SelectedUDFstatus[$listsize+1]	; T=to be encrypted (default: on, if )
	Global $SelectedUDFfixed[$listsize+1]	; read-only, either preceding MCFinclude or not used
	; status=T + R/O = always encrypted or not used; status=F + R/O = cannot be encrypted

	; defaults in case of error
	$selectedUDFstatus[0]=True
	$SelectedUDFfixed[0]=False
	For $rc=1 To $listsize
		$selectedUDFstatus[$rc]=True
		$SelectedUDFfixed[$rc]=True
	Next

	; assign source status (=encryptable) to each include, based on sequence and nesting
	; 0 = main (all: yes)
	; 1 = preceding MCFinclude.au3, or nested below that (all: no)
	; 2 = MCFinclude, or nested below that (special case: _dummycalls, MCFCC_Init: yes, rest: no)
	; 3 = following MCFinclude, or nested below that (all: yes)
	$totalincludes=$includes[0]
	If $totalincludes<=1 Then Return SetError(_ErrorHandler(-1,"Includes table is empty",$procname),0,False)
	Local $includesStatus[$totalincludes+1]	; lookup for UDF encryptable status
	$includesStatus[0]=$totalincludes
	$includesStatus[1]=0								; marker: main script

	; determine separator string
	$separator=""
	$firstbranch=StringTrimLeft($treeincl[1],StringLen($includes[1]))
	For $cc=1 To StringLen($firstbranch)-1
		If _ArraySearch($includes,StringTrimLeft($firstbranch,$cc),1)>0 Then
			$separator=StringLeft($firstbranch,$cc)
			ExitLoop
		EndIf
	Next
	If $separator="" Then Return False

	; scan top nesting level
	$marker=1
	For $rc=1 To $treeincl[0]
		$branch=StringSplit($treeincl[$rc],$separator,1)
		If @error Or $branch[0]>2 Then ExitLoop	; are we done with top-level scan?

		If StringRight($branch[2],15)="\MCFinclude.au3" Then
			$marker=2
		Else
			If $marker=2 Then $marker=3
		EndIf

		$index=_ArraySearch($includes,$branch[2],1)
		If $index>0 Then $includesStatus[$index]=$marker
	Next

	; scan all remaining branches, assign top level's marker
	For $cc=$rc To $treeincl[0]
		$branch=StringSplit($treeincl[$cc],$separator,1)
		If @error Or $branch[0]<3 Then ExitLoop	; are we done with top-level scan?
		$topindex=_ArraySearch($includes,$branch[2],1)
		$index=_ArraySearch($includes,$branch[$branch[0]],1)
		If $topindex>0 And $index>0 And $includesStatus[$index]="" Then _
			$includesStatus[$index]=$includesStatus[$topindex]
	Next

	If $showprogress=True Then SplashTextOn("","Resolving UDF hierarchy..." ,300,40,-1,-1,1+32,"Verdana",10)
	For $rc=1 To $references[0][0]
		If $references[$rc][3]="func def" Then
			$source=$references[$rc][1]
			$curfunc=$references[$rc][4]
			$index=_ArraySearch($includes,$source,1)
			If $index<1 Then ContinueLoop

			$marker=$includesStatus[$index]
			Switch $marker
				Case 0,3		; main script, or include following MCFinclude
					$status=True
					$fixed=False

				Case 1		; include preceding MCFinclude
					$status=False
					$fixed=True

				Case 2		; MCFinclude
					$status=($curfunc="_dummycalls" Or $curfunc="_MCFCC_Init")
					$fixed=True

				Case Else	; unknown error
					ContinueLoop
			EndSwitch

			; if UDF is not used, status is also fixed
			$fixed=($fixed Or (_ArraySearch($uniquefuncsAll,$source & " UDF: " & $curfunc,1)<1))

			; assign settings to UDF
			$index=_ArraySearch($SelectedUDFname,$curfunc,1)
			If $index>0 Then
				$selectedUDFstatus[$index]=$status
				$SelectedUDFfixed[$index]=$fixed
			EndIf
		EndIf
	Next
	SplashOff()

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _PrepMCenvironment($path,$force_refresh=True)

	$procname="_PrepMCenvironment"
	_CallStack_Push($procname)

	; load all CS arrays
	If $showProgress=True Then SplashTextOn("","Preparing MC environment...",250,40,-1,-1,1+32,"Verdana",10)
	If _FillCSpath($path,$force_refresh)=False Then _
		Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,False)

	; additional arrays
	Global $globalsOrphaned[1]
	Global $already_included[1]
	Global $fileIncludeOnce[1]
	$globalsOrphaned[0]=0
	$already_included[0]=0
	$fileIncludeOnce[0]=0

	; miscellaneous
	Global $fhout=0						; output handle
	Global $totalfiles=0
	Global $totalines=0
	_ValidPrefix()							; build XLATB table
	Global $totalfiles=$includes[0]
	Global $fileIncludeOnce[$totalfiles+1]
	For $fc=1 To $totalfiles
		$curfile=$includes[$fc]
		$fileIncludeOnce[$fc]=(_Arraysearch($includeonce,$curfile,1)>0)
	Next

	Global $totalines=0
	Global $dumptag="; CODESCANNER header is missing" & @CRLF & ";" & @CRLF
	$readmefile=$CS_dumppath & "readme.txt"
	If FileExists($readmefile) Then
		$fh=FileOpen($readmefile)
		If Not @error And $fh>0 Then
			$dumptag=""
			While True
				$curline=FileReadLine($fh)
				If @error Or StringLeft($curline,1)<>";" Then ExitLoop
				If StringInStr($curline,"{incl#}") Then ContinueLoop
				$dumptag&=$curline & @CRLF
			WEnd
			FileClose($fh)
		EndIf
	EndIf

	_FillSkipRegExpStrings()

	SplashOff()

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _FillSkipRegExpStrings()

	Global $skipRegExpStrings[1]
	$skipRegExpStrings[0]=0

	$regexplist=_ArrayFindAll($references,"StringRegExp",1,0,0,1,4)
	For $rc=0 To UBound($regexplist)-1
		$split=StringSplit(StringTrimLeft($references[$regexplist[$rc]][5],StringInStr($references[$regexplist[$rc]][5],",")),"{string",1)
		For $cc=2 To $split[0]
			_ArrayAdd($skipRegExpStrings,StringLeft($split[$cc],StringInStr($split[$cc],"}")-1))
		Next
	Next
	$skipRegExpStrings[0]=UBound($skipRegExpStrings)-1

EndFunc


Func _PrepMCFinclude()
; store obfuscated MCFCC calls for insertion into target

	$procname="_PrepMCFinclude"
	_CallStack_Push($procname)

	If $MCF_OBFUSCATE_UDFS=True Then
		$index=_ArraySearch($FunctionsUsed,"_MCFCC")
		If $index<1 Then Return SetError(_ErrorHandler(-1,"internal UDF _MCFCC() not found in array $FunctionsUsed",$procname),0,false)
		Global $_MCFCC=$FunctionsTransl[$index]
	Else		; restore original global definitions
		Global $_MCFCC="_MCFCC"
	EndIf

	Global $_MCFCCXA="Execute(" & $_MCFCC
	Global $_MCFCCXB="Execute(Execute(" & $_MCFCC

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _RandomHex($digits=2)

	Select
		Case $digits<1
			Return ""
		Case $digits<8
			Return Hex(random(0,(16^$digits)-1,1),$digits)
		Case Else
			$hexstring=""
			For $cc=1 To Ceiling($digits/4)
				$hexstring&=_RandomHex(4)
			Next
			Return StringLeft($hexstring,$digits)
	EndSelect

EndFunc


Func _ShowMCFile($path,$mcfile="")

	$procname="_ShowMCFile"
	_CallStack_Push($procname)

	If _FillCSpath($path)=False Then Return SetError(_ErrorHandler(-1,"preparing MCF environment",$procname),0,False)

	If $mcfile="" Then
		$mcfile=FileOpenDialog("Please select a MetaCode file", $CS_dumppath, "MetaCode files (mcf*.txt)|AutoIt files (mcf*.au3)", 1+2)
		If @error Then	Return SetError(_ErrorHandler(-2,"no file was selected",$procname),0,False)
	Else
		If Not StringInStr($mcfile,"\") Then $mcfile=$CS_dumppath & $mcfile
	EndIf

	If Not FileExists($mcfile) Then Return SetError(_ErrorHandler(-3,"file not found:" & @CR & $mcfile,$procname),0,False)

	If StringRight($mcfile,4)=".au3" Then
		RunWait("notepad.exe " & $mcfile)	; memory leak if opened in Scite?
	Else
		ShellExecuteWait($mcfile)
	EndIf

	_CallStack_Pop($procname)
	Return True
EndFunc


Func _TestCCKey()

	If Not IsDeclared("CCkey") Then
		$msg="Error: Array $CCkey[] has not been declared."
		MsgBox(262144+4096+16,"MCF: Testing encryption keys",$msg)
		Return False
	EndIf
	$maxkeytype=UBound($CCkey)-1
	If $maxkeytype<2 Then
		$msg="Error: Array $CCkey[] has no defined runtime-keys."
		MsgBox(262144+4096+16,"MCF: Testing encryption keys",$msg)
		Return False
	EndIf
	If $CCkeytype<0 Or $CCkeytype>$maxkeytype Then
		$msg="Error: $CCkeytype (" & $CCkeytype & ") is out of bounds (valid range: 0-" & $maxkeytype & ")."
		MsgBox(262144+4096+16,"MCF: Testing encryption keys",$msg)
		Return False
	EndIf

	$empty=0
	For $rc=0 To $maxkeytype
		If $CCkey[$rc]="" Then $empty+=1
	Next

	If $empty>1 Then	; one entry is allowed for user query
		$msg="Warning: array $CCkey[] contains multiple empty entries."
		If $CCkey[$CCkeytype]<>"" Then
			MsgBox(262144+4096+16,"MCF: Testing encryption keys",$msg)
		Else
			$msg&=@CR & "The selected keytype points to one of these, which will trigger a user password query at startup." & @CR & @CR
			$msg&=@CR & "If this is not intended, please press Cancel now."
			If MsgBox(262144+4096+16+1,"MCF: Testing encryption keys",$msg)=2 Then Return False
		EndIf
	EndIf

	If $CCkey[$CCkeytype]="" And $decryption_key="" then
		$msg="Error: $CCkey[" & $CCkeytype & "] and $decryption_key are BOTH empty, providing nothing to encrypt with."
		MsgBox(262144+4096+16,"MCF: Testing encryption keys",$msg)
		Return False
	EndIf

	Return True
EndFunc


Func _ValidPrefix()

	Global $validprefix[256]	; the poor man's XLATB

	For $cc=0 To 255
		$validprefix[$cc]=False
	Next

	$validprefix[32]=True	; space
	For $cc=1 To $AU3operators[0]
		If StringLen($AU3operators[$cc])=1 Then _
			$validprefix[Asc($AU3operators[$cc])]=True
	Next

EndFunc


Func _HandleEnteredSubsetDef($newvalue)

	If $newvalue==$subset_definition Or $newvalue="" Then Return $subset_definition

	$newvalue=StringStripWS(StringRegExpReplace($newvalue,"[^0-9.%]",""),8)
	If StringRight($newvalue,1)="%" Then
		$newvalue=Number(StringTrimRight($newvalue,1))
		If $newvalue<=0 Or $newvalue>=100 Then Return $subset_definition	; use default instead
		Return Round($newvalue*.01,3)
	EndIf
	$newvalue=Number($newvalue)
	If $newvalue=0 Or $newvalue=1 Then Return $subset_definition
	If $newvalue<>Int($newvalue) Then $newvalue=Round($newvalue,3)

	Return $newvalue
EndFunc


#endregion auxiliary