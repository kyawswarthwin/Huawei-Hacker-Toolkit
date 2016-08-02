;============================================================================================
; Title .........: Code Scanner
; AutoIt Version : 3.3.12
; Description ...: scans an Autoit script and reports issues that compilers miss
; Author.........: A.R.T. Jonkers (RTFC)
; Release........: 2.9
; Latest revision: 16 Aug 2014
;
; License........: free for personal use; free distribution allowed, provided
;							the original author is credited; all other rights reserved.
; Tested on......: W7Pro/64
; Dependencies...: MCF.au3, by RTFC (see: http://www.autoitscript.com/forum/topic/155537-mcf-metacode-file-udf/)
; Forum Link.....: www.autoitscript.com/forum/topic/153368-code-scanner/
;
; Acknowledgements: guinness, Yashied, AZJIO, BrewmanNH, PsaltyDS
; * guinness, for _ParseAPI()
;		http://www.autoitscript.com/forum/topic/152146-au3-script-parsing-related-functions/
; * Yashied, for _arrayUniqueFast()
; 		http://www.autoitscript.com/forum/topic/122192-arraysort-and-eliminate-duplicates/#entry849187
; * AZJIO, BrewmanNH: @programfilesdir/CLSID for Autoitincludefolder (in codescanner thread)
; * PsaltyDS: TreeView doubleclick handling
;		http://www.autoitscript.com/forum/topic/108187-double-click-mouse-option-in-tree-view/
;============================================================================================
; Summary (Wotsit?)
;
; This utility scans an AutoIt code project with multiple #includes and/or UDFs
; for inconsistencies, clashes, and various other hidden potential problems.
;
; It also tracks, lists, and outputs many code components (includes, definitions,
; calls, loops, exitpoints, variables, globals, literal strings) plus statistics,
; and can generate MetaCode files for further processing.
;
; >>> It does NOT alter your code; it just reads, evaluates, and reports. <<<
;
; Any code changes YOU make on the basis of its results are YOUR OWN RESPONSIBILITY.
; That means: no guarantees, no warranties, no liability for damages, no refunds.
; Use at your own risk.
;
;============================================================================================
;	Application (WhyBother?)
;
; With this utility you can:
;	1. identify hidden run-time issues and bugs that compilers miss
;	2. gather/display/store data on the content and structure of your script
;  3. generate MetaCode files and content arrays for MCF processing
; 	4. impress onlookers by appearing to understand insanely complicated code structures
;	5. refresh your memory re. spaghetti code you wrote years ago, at 3 a.m., while drunk
;	6. have a great excuse for taking a powernap while it's running
;
; Input: Select root file: <yourAU3file>.au3 containing the main code that calls
;				other procs/funcs	and/or #includes
;
; Optional Outputs (can all be written to file):
;		* Report identifying:
;			- missing #includes
;			- duplicate UDFs (lists *all* occurrences, with their resp. parameters)
;			- globals defined only within UDFs (also available as separate .au3 #include, see below)
;			- implicit exitpoint(s)
;			- sundry observations of questionable interest
;		* Treeviews of code architecture (with search function)
;			-nested #includes
;			-active(!) function calls (AU3 and/or UDF)
;		* Arraydisplay listings (some 2-D) of:
;			- identified potential issues
;			- unique #includes, with calling stats (in/out)
;			- all native AU3 functions called anywhere	(tracking optional; performance penalty: large)
;			- unique UDFs, with calling stats (in/out)	(tracking optional; performance penalty: HUGE)
;			- all loops												(tracking optional; performance penalty: small)
;			- all main code sections
;			- all exitpoints (explicit and implicit)
;			- all variables										(tracking optional; performance penalty: moderate)
;			- all globals (incl. redefinitions)
;			- all strings (incl. empty)						(tracking optional; performance penalty: small)
;			- all locations/definitions of UDF defs and calls, #includes, globals, AU3 calls
;		* List of global definitions per (non-native) #include, with reference (and embedding UDF)
;		* MetaCode Files (see the MCF thread:http://www.autoitscript.com/forum/topic/155537-mcf-metacode-file-udf/)
;
; Assumptions re. analysed code:
; * ASCII or AutoIt-supported Unicode encoding: see http://www.autoitscript.com/autoit3/docs/intro/unicode.htm
; * maximum line length: 4096 bytes (AutoIt limit; easily adjusted if need be)
;		NB if ASCII, each line should end with @CRLF (not @CR or @LF by itself)
; * Func / Endfunc / #include / #ce / Global should be the FIRST word on a line that contains it
; * Each line starting with "Func" requires an associated later line starting with "Endfunc"
;		#cs may be preceded by code on the same line;
; 		#ce may be followed by more comments on the same line;
;		multiple pairs of #cs + #ce may be nested; single stray #ce's are ignored
;
;============================================================================================
; Remarks (Just Run It!)
;
; * Want a demo first? Let it analyse itself
; (will take quite a while though, and report won't be very interesting)
;
; * procedural booleans and paths can be set in the Settings panel;
;		also accessible in local INI file "codescanner.ini", generated upon first run
;		Many tracked features are optional (see Settings panel)
;		NB progressbar recedes when new #include files are added to the to-do list
;
; * report is created in memory, and can be opened in Notepad as a temporary file
;		that you can then edit, rename, and save wherever you want
;
; * non-native globals can be array-listed and written to a .au3 include file,
;		enabling you to incorporate them into the rootfile so all globals are declared first
;		The "Const" predicate is ignored.
;
; * to save _ArrayDisplay contents, use its GUI's bottom button <Copy Selected>
;
; * TreeViews (Includes, Functions):
;		- press <Esc> to interrupt Tree building
;		- display the ACTIVE parts of the code only
;		- can be step-searched as in Scite (Ctrl-F, F3, Shift-F3)
;		- multiple occurrences are highlighted in bold and are are not branch-tracked further down the hierarchy
;		- the first occurrence of a UDF call or #include is always shown
;		- display of subsequent occurrences depend on boolean $showfirstduplication; change in Settings panel (or INI file)
;		- set both $showfirstduplication and $showAU3native to True to display *all* AU3 calls within *each* UDF;
;			otherwise only the first occurrence in the entire code of each AutoIt function is shown;
;			but such trees can be large, and may take several minutes to build
;
; * script analysis first identifies global-scope parts:
;		- #include compiler directives (hierarchy mapped)
;		- global definitions	(unless calling functions!)
;		- UDF definition code blocks
;
; * "main code" (everything else) per source file yields data on:
;			- main code sections	(separated by aforementioned instances of global scope)
;			- entry points
;			- loop structures
;			- native AutoIt function calls
;			- UDF function calls	(hierarchy mapped, can include AU3 calls too)
;			- variables
;			- literal strings
;			- implicit/explicit exit points
;
; * NOT SUPPORTED:
;		- legacy AutoIt versions prior to 3.3.12
;		- variables that switch between being single variant and array
;		- object- and variable-related functions (e.g., WMI $*.ExecQuery())
;			(NB MCF *does* support functions defined as object methods in a literal string )
;		- Assign() and Execute() with $variable-based parameter contents (self-modifying code)
;			(may be dynamically defined at runtime, so static analysis cannot determine its contents)
;		- parameterised function calls defined by compound constructs (using "&")
;			(for the same reason, as compounds likely have variable parts)
;		- strings containing chr(0)
;
; * call stats reflect the static state, not necessarily the dynamic load, e.g.,
;		a UDF may have incoming calls=1, but if called within nested loops it may be
;		the most often	executed code section in the entire architecture
;
; * when an #include is flagged as *possibly* redundant, the current build does not
;		DIRECTLY require it in terms of globals and/or UDF definitions. However,
;			- other builds/codes may call parts not used in the current build;
;			- the flagged #include may itself include other #includes that DO provide
;				essential globals and/or UDFs for the current build.
;		Therefore:
; 	To be SAFE, only disable/remove redundant subsidiaries #included in the ROOT file.
;	These are prefixed with "*" in the report.
;
; * a UTF16-encoded file processed with $UnicodeSupport=false produces a "Retry?" query.
;		if the user agrees, $UnicodeSupport=true for that session if $useINIsettings=false;
;		if additionally $useINIsettings=True, "$UnicodeSupport=true" is stored as new default;
;		these settings can also be preset in the Settings panel per session (edit+<Return>)
;		and permanently (edit+<Store>).
;
; * can be started from the cmdline with arguments for single run + datadump:
;		full path + filename of AutoIt script to scan (must exist); enclose in quotes if it contains spaces
;		-q or /q		(optional) run quiet, no error messages (only negative exit code if error, 0 if okay)
;
; * native AU3 function calls used to define globals in #includes are excluded from the lists of AU3 function calls;
;		to gather these, process the #include separately as a root file
;
; * $AU3FunctionsCalled (active calls) is a subset of $AU3FunctionsUsed (found anywhere)
;		$FunctionsCalled (active calls) is a subset of $FunctionsUsed (found anywhere)
;
; * Entry points are marked False if found outside the root file;
; 		Exit points are marked False if found outside the root file AND being
;		<implicit> (i.e., not using the "Exit" keyword)
; 		Although the Exit keyword can be used as a function, it is tracked as a separate entity
; 		Entry- and Exit points marked False are not flagged as issues because these
;		occurrences may be intentional
;
; * extracted strings and variables are stored both sequentially and sorted;
;		symbolic tags in curly brackets ("{string#}","{var#}") are numbered sequentially
;		as encountered (e.g., {string123} is stored in $stringsUsed[123], NOT in $stringsUsedSorted[123])
;		so sequence = processing order (entire root file first, then its #includes, then their #includes, etc.
;
; * Main Menu attributes "All" and "Used" = found anywhere within processed code;
;		attribute "Called" and "Calling" = part of the ACTIVE code, tracing calls from
;		within the main code sections (NB not necessarily found only in the root file)
;
; * BEWARE: if you switch UDF call tracking off, only main code sections will left to analyse,
;		leading to low or zero counts in the remaining stats
;
; * The following #includes are often listed as redundant (not serious, just ignore):
;	- Security.au3
;	- WinAPIError.au3
;	- SendMessage.au3
;
; * Command line parameters for automatic processing:
;		/b		: create single (B)uild
;		/c		: (C)reate single build (see /b)
;		/d		: (D)efine (D)ecryption key (password or macro's expected return)
;		/e		: (E)ncrypt (both strings and phrases); modified by /s parameter (NB requires #include "MCFinclude.au3" in source file!)
;		/f		: input (F)ile
;		/i		: (I)nput file (see /f)
;		/k		: (K)ey type (requires /e); index to $CCkey in MCFinclude.au3
;		/l		: (L)ogfile CS.<timestamp>.log written to CS datadump directory (NB MCF errors are AKWAYS logged in MCFencoding.log in CS datadump subdirectory)
;		/n		: (N)o source pruning (removing orphans or unused UDFs)
;		/o		: (O)bfuscate (both variables and UDF names)
;		/p		: define (P)assword (decryption key; password or macro's expected return)
;		/q		: (Q)uiet mode: no screen messages (errors and progress updates)
;		/r		: write (R)eport: incorporate CodeScanner's report output into logfile (param /l is not additionally required)
;		/s		: define (S)ubset, followed by either proportion (0-1, random), line modulo (>1, cycled), <percentage>% (1-100); this part will be encrypted
;		/w		: (W)rite report: incorporate CodeScanner's report output into logfile (param /l is not additionally required)
;
;	Note: if a parameter requires additional input, do NOT add any space inbetween
;			/d, /k expect integer (index to $CCkey in MCFinclude.au3, so ensure it exists!)
;			/f, /i expects the target file name (with optional path)
;			/p expects a string or number, depending on value defined by /k;
;				NB if /k is defined but /p is not, decryption key will use whatever the current environment returns
;			/s expects some number N (and requires /e):
;				if 0 < N < 1: interpreted as proportion to encrypt (randomly allocated)
;				if N > 1: interpreted as modulo cycle (e.g., N=5: ecrypt every fifth encryptable occurrence in user's script)
;				if N%: interpret as percentage (handle as proportion, see above)
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

#Region Includes

#include <Array.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <File.au3>
#include <GuiConstantsEx.au3>
#include <GuiListBox.au3>
#include <GuiTreeView.au3>
#include <Math.au3>
#include <Misc.au3>
#include <ProgressConstants.au3>
#include <SendMessage.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

#include ".\MCF.au3"					; MetaCodeFile UDF

#EndRegion Includes

#Region Globals

; INI-related
Global $useINIsettings=True
Global $inifile=@ScriptDir & "\CodeScanner.ini"
Global $INIvars[1][1]
Global $pathvars[1][1]

; procedural booleans
; defaults are overwritten by codescanner.ini values, if INI is found in codescanner's directory
; if you edit them here (e.g., for testing), set $useINIsettings=False above
Global $includeConstants=False		; True = process @programfilesdir\AutoIt3\Include\*Constants*.au3 #includes (slower)
Global $TrackAU3Calls=True				; track native AutoIt function calls
Global $TrackUDFCalls=True				; track UDF function calls
Global $TrackLoops=True					; track nested loops
Global $ExtractVars=True				; create a list of all unique $variablesUsed
Global $ExtractStrings=True			; store all strings in array $stringsUsed and number each reference in $references->Parameters
Global $ExtractMacros=True				; create a list of all @macros used
Global $WriteMetaCode=False			; translate script into symbolic metacode for post-processing
Global $showprogress=True				; True = show progressbars
Global $showResultsBySubject=True	; treemenu display setting
Global $showResultsByFormat=True		; treemenu display setting
Global $showMetaCode=True				; treemenu display setting
Global $UnicodeSupport=False			; True = use Filereadline; False = use struct I/O
Global $showfirstduplication=True	; treeview setting, T/F = display/omit first duplicate occurrence
Global $showAU3native=True				; treeview setting, T/F = display/omit AU£ native function calls/includes
Global $diagnostics=False				; True = console output on current progress (slow)
Global $TrackCalls=($TrackAU3Calls Or $TrackUDFCalls)
Global $uselogfile=False				; create a log file? (used only in cmdline mode)

; string tags (should NOT be empty)
Global Const $separator=" | "					; in $tree*[] (buffers for building trees); should not be part of any include/UDF string; do not use "|"
Global Const $tagmarker=" *** "
Global Const $paramsunresolvedtag=$tagmarker & " parameters unresolved <<<"
Global Const $duplicatestag=$tagmarker & "DUPL. <<< "
Global Const $recursiontag=$tagmarker & "recursion <<< "
Global Const $unresolvedUDFtag=$tagmarker & "unresolved UDF <<<"
Global Const $filenotfoundtag=$tagmarker & "file not found <<<"
Global Const $func_unknown_tag="func unknown"
Global Const $lastmainlinetag="<implicit Exit>"
Global $rootpath="<undefined>"
Global $rootfile="<undefined>"
Global $trimmedroot="<undefined>"
Global $filelinetag=""	; the rest can be empty
Global $dumptag=""

If $separator="" Or $tagmarker="" Or $paramsunresolvedtag="" Or $duplicatestag=22 Or _
	$recursiontag="" Or $unresolvedUDFtag="" Or $filenotfoundtag="" Or $func_unknown_tag="" Then
		MsgBox(262144+8192+16,"Unable to proceed","at least one string tag is empty",8)
		Exit (-10)
	EndIf

; language environment
Global $extrapaths=StringSplit(RegRead("HKEY_CURRENT_USER\Software\AutoIt v3\AutoIt","Include"),";")
If $extrapaths[0]=1 And StringLen($extrapaths[1])=0 Then $extrapaths[0]=0
For $rc=1 To $extrapaths[0]	; clip any
	Local $tmp=StringStripWS($extrapaths,1+2)
	If StringRight($tmp,1)<>"\" Then
		$extrapaths[$rc]=$tmp & "\"
	Else
		$extrapaths[$rc]=$tmp
	EndIf
Next

Global $AutoItIncludeFolder=""	; filled either from INI or _GetAutoItIncludeFolder()
Global $AU3Functions[1]
Global $AU3operators[1]
Global $macros[1]
Global $validprefix[1]

; miscellaneous
Global $runquiet=False
Global $tstart=0
Global $insertPrefix=""
Global $level0=""
Global $parent[1]
Global $child[1]
Global $includedonceasparent[1]
Global $includedonceaschild[1]
Global $funcdef_ID=0
Global $fhlog=""

; GUI-related
Global $hGUI
Global $tree
Global $treemenu
Global $ListedOptions
Global $item_clicked
Global $itemtext
Global $selection_changed
Global $PBGUI
Global $PBmaintexthandle
Global $PBsubtexthandle
Global $includedonceasparent[1]
Global $includedonceaschild[1]
Global $displayoptionstrings[1]
Global $idTV
Global $EscPressed
Global $CS_dumppath=".\"
Global $hTreeView=""						; generic handle for any treeview
Global $hTreeViewMenu=""
Global $hGUImenu=""
Global $hEditmenu=""
Global $RBShandle=0
Global $RBFhandle=0
Global $MChandle=0
Global $maxdisplayoption=36
Global $treeviewmenuhome
Global $treeviewmenuexit
Global $treeviewmenuactivate
Global $AccelKeysmenu[1][1]

;__________
; remaining globals are to be reset for every (re)scan

; strings
Global $report="Report not (yet) generated."
Global $stats="Stats not (yet) generated."
Global $settingslist="Settings List not (yet) generated."
Global $newfunc="<undefined>"
Global $trimmedfname="<undefined>"
Global $globaldeflist="; <undefined>"
Global $lastmainline="<undefined>"

; counters etc
Global $filecount=0
Global $pairs=0
Global $startofuncs=0
Global $totalines=0
Global $totalcalls=0
Global $sourcedex=0
Global $truelinecount=0
Global $addlines=0
Global $include_notfound=0
Global $include_deadweight=0
Global $func_duplicated=0
Global $func_paramsunresolved=0
Global $stringcounter=0
Global $loopmismatch=0
Global $loopmissingparams=0
Global $loop_ID=0
Global $trueFirstEntrypoint=-1
Global $WriteMetaCodeFail=False

; arrays
Global $stringsUsed[1]			; non-unique
Global $stringsUsedSorted[1]
Global $variableIsArray[1]
Global $variablesUsed[1]
Global $variablesUsedSorted[1]
Global $AU3FunctionsUsed[1]	; FOUND in main code or any UDF (not necessarily called)
Global $AU3FunctionsCalled[1]	; CALLED in main code or any Called UDF
Global $FunctionsDefined[1]	; UDF func def
Global $FunctionsUsed[1]		; UDF func FOUND in main code or any Called UDF; filled in MCF.au3: _AddFunCall
Global $FunctionsCalled[1]		; UDF func CALLED in main code or any Called UDF
Global $dupes[1]
Global $includes[2]				; root file = includes[1]
Global $macrosUsed[1]
Global $MCinFuncDef[1]
Global $myincludes[2]			; root file = myincludes[1]
Global $includeonce[1]
Global $includesRedundant[1]
Global $incl_notfound[1]
Global $unknownUDFs[1]
Global $include_lines[1]
Global $globals[1]
Global $newglobals[1]
Global $globalglobals[1]
Global $globalsRedundant[1]	; won't catch globals used only to define other globals that themselves turn out to be redundant
Global $internalfuncs[1]
Global $uniquefuncsAll[1]
Global $uniqueFuncsCalling[1]
Global $uniqueFuncsCalled[1]
Global $treeIncl[1]
Global $treeFunc[1]

; 2-D arrays with predefined headers
Global $mainCodeSections[1][5]	; continuous sections of code other than globals, #includes, and UDF definitions
Global $globalsinFuncs[1][5]		; globals defined within UDF definitions
Global $references[1][6]		; main internal data storage for all types of tracked tags
Global $include_stats[1][11]
Global $refindex[1][7]

_PrepGlobals()
_ArrayHeaders()

; subsets of $references by feature
Global $refglobals=$references		; tracking tag: global
Global $problems	=$references		; col0=false = something is possibly wrong
Global $loops		=$references		; tracking tags: For,Next,While,Wend,Do,Until
Global $Entrypoints=$references		; first line of first main code section per source file (NB main code <> global,UDF def,#compiler-directive)
Global $Exitpoints=$references		; tracking tag: Exit (plus implicit exit = last line of main code)

Func _ArrayHeaders()

	$references[0][0]=0
	$references[0][1]="Source file"
	$references[0][2]="Line"
	$references[0][3]="Tracking tag"		; func def/ func call / #include / global
	$references[0][4]="Reference"			; func/include name
	$references[0][5]="Parameters"		; func(...)

	$mainCodeSections[0][0]=0
	$mainCodeSections[0][1]="Source file"
	$mainCodeSections[0][2]="first line nr"
	$mainCodeSections[0][3]="last line nr"
	$mainCodeSections[0][4]="last line"

	$globalsinFuncs[0][0]=0
	$globalsinFuncs[0][1]="Source file"
	$globalsinFuncs[0][2]="Line"
	$globalsinFuncs[0][3]="UDF"
	$globalsinFuncs[0][4]="Global"

	$include_stats[0][0]=1
	$include_stats[0][1]="Filename"
	$include_stats[0][2]="Lines"
	$include_stats[0][3]="Includes"
	$include_stats[0][4]="UDF defs"
	$include_stats[0][5]="incoming calls"
	$include_stats[0][6]="outgoing calls"
	$include_stats[0][7]="Globals"
	$include_stats[0][8]="native"
	$include_stats[0][9]="main code sections"
	$include_stats[0][10]="refs record"

	$refindex[0][0]=0	; rest of column contains filenames( #includes) and UDF names
	$refindex[0][1]="$refs start row"
	$refindex[0][2]="$refs end row"
	$refindex[0][3]="start line nr"
	$refindex[0][4]="end line nr"
	$refindex[0][5]="incoming calls"
	$refindex[0][6]="outgoing calls"

EndFunc

#endregion	Globals

#region	Main

; set up work environment
If $useINIsettings=True Then
	_ReadIniFile()	; calls _GetAutoItIncludeFolder() if notfound/undefined
Else
	If _GetAutoItIncludeFolder()=False Then Exit (-1)
EndIf
_FillAutoItFuncs()	; reads from <$AutoItIncludeFolder>\SciTE\api\au3.api

If $cmdline[0]>0 Then		; automatic single run with data dump
	$uselogfile=True
	$file=""
	$fulldump=False
	$runquiet=False
	$callCrypter=False
	$writeReport=False
	$createSingleBuild=False
	$decryption_key=""
	$subset_definition=1

	; MCF settings
	$MCF_OBFUSCATE				=False	; enable $MCF_OBFUSCATE_* settings
	$MCF_OBFUSCATE_UDFS		=False	; encode with $functionsObfusc
	$MCF_OBFUSCATE_VARS		=False	; encode with $variablesObfusc
	$MCF_ENCRYPT				=False	; enable $MCF_ENCRYPT_* settings
	$MCF_ENCRYPT_PHRASES		=False	; Execute(decrypt(encrypted call or conditionals))
	$MCF_ENCRYPT_STRINGS		=False	; decrypt(encrypted string)
	$MCF_ENCRYPT_SUBSET		=False	; use $subset_definition to determine which lines will be encrypted
	$MCF_SKIP_UNCALLED_UDFS	=True		; clean up redundant source
	$MCF_REMOVE_ORPHANS		=True		; clean up redundant source

	For $cc=1 To $cmdline[0]

		Switch StringLeft($cmdline[$cc],2)

			Case "/b","-b","/c","-c"	; create single build
				$createSingleBuild=True

			Case "/d","-d","/p","-p"	; p for password (required when setting /k1)
				$decryption_key=StringTrimLeft($cmdline[$cc],2)
				If $decryption_key="" Then Exit (-11)

			Case "/e","-e"		; encrypt
				$MCF_PHRASING=True
				$MCF_ENCRYPT=True
				$MCF_ENCRYPT_PHRASES=True
				$MCF_ENCRYPT_STRINGS=True
				$createSingleBuild=True
				$callCrypter=True

			Case "/f","-f","/i","-i"	; input file
				If StringLen($cmdline[$cc])=2 And StringMid($cmdline[$cc],2,1)="f" Then
					$fulldump=True
				Else	; fill once only
					If $file="" Then $file=StringTrimLeft($cmdline[$cc],2)
				EndIf

			Case "/k","-k"		; key type (see array $CCkey in MCFinclude.au3)
				$Cckeytype=StringTrimLeft($cmdline[$cc],2)
				If $CCkeytype<1 Or $CCkeytype>UBound($CCkey)-1 Then $CCkeytype=1	; default: user password query

			Case "/l","-l"			; write CS logfile (NB MCF logs errors in MCFencoding.log in CS datadumpdir
				$uselogfile=True

			Case "/n","-n"		; no cleanup
				$MCF_SKIP_UNCALLED_UDFS	=False
				$MCF_REMOVE_ORPHANS		=False

			Case "/o","-o"		; obfuscate
				$MCF_OBFUSCATE=True
				$MCF_OBFUSCATE_UDFS=True
				$MCF_OBFUSCATE_VARS=True
				$createSingleBuild=True
				$callCrypter=True

			Case "/q","-q"		; quiet
				$runquiet=True

			Case "/r","-r","/w","-w"
				$writeReport=True		; stored in logfile
				$uselogfile=True

			Case "/s","-s"
				$subset_definition=_HandleEnteredSubsetDef(StringTrimLeft($cmdline[$cc],2))
				$MCF_ENCRYPT_SUBSET=True
		EndSwitch
	Next
	If $file="" Then _IOError("no input file supplied")
	If Not FileExists($file) Then _IOError("input file not found: " & $file)

	; required settings for MetaCode output for CodeCrypter
	If $callcrypter=True Then
		$WriteMetaCode=True
		$includeConstants=True
		$trackAU3calls=True
		$trackUDFcalls=True
		$ExtractVars=True
		$ExtractStrings=True
		$ExtractMacros=True
		If $MCF_ENCRYPT=True And $CCkeytype=1 And $decryption_key="" Then _IOError("user password query defined, but no password provided (add option /p<password>)")
	EndIf

	If $runquiet=True Then
		$showprogress=False
		$diagnostics=False
	EndIf

	; non-interactive single processing & data dump
	_GetNewRootfile($file)	; just for filling some globals; no user-query or checks

	If $uselogfile=True Then
		$logfile=$CS_dumppath & "CS." & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log"
		If _FileCreate($logfile)=False Then _IOError("Unable to create logfile:" & @CR & $logfile)
		$fhlog=FileOpen($logfile,2+8)	; open for write, create dir too
		If $fhlog<1 Then _IOError("Unable to open logfile:" & @CR & $logfile)
		_FileWriteLog($fhlog,"CodeScanner Log" & @CRLF & "Processing file: " & $includes[1] & @CRLF & @CRLF)
		OnAutoItExitRegister("_CloseLogfile")
	EndIf

	_AnalyseCode()						; run the engine
	_WriteCSDataDump($fulldump)	; dump CS data

	If $createSingleBuild=True Then
		_CreateSingleBuild($CS_dumppath,True)	; T = force_refresh
		If $callCrypter=True Then _RebuildScript($CS_dumppath,True)	; T = force_refresh
	EndIf

Else	; no cmdline parameters, so run interactively until user exits

	_BuildTreeviewMenu()
	_GetNewRootfile()	; get filename through user dialog

	While True
		_AnalyseCode()	; Who you gonna call? Code Busters!
		_TreeviewMenu()
	WEnd

EndIf

OnAutoItExitUnRegister("_CloseLogfile")
_CloseLogfile()
Exit (0)				; That's all, folks!

#endregion	Main

#region	GUI-related UDFs

Func _BuildTreeviewMenu()

	Global $displayoptionstrings[$maxdisplayoption+1]
	$displayoptionstrings[0]=$maxdisplayoption
	For $lc=1 To $maxdisplayoption
		$displayoptionstrings[$lc]=""
	Next

	Global $level0="CodeScanner"

	Local $level1[9]
	$level1[1]="Rescan"
	$level1[2]="New File"
	$level1[3]="Settings"
	$level1[4]="Data Dump"
	$level1[5]="Exit"
	$level1[6]="Results by Subject"
	$level1[7]="Results by Format"
	$level1[8]="MetaCode"
	$level1[0]=UBound($level1)-1

	Local $level2_1[5]		; by subject
	$level2_1[1]="General"
	$level2_1[2]="Includes"
	$level2_1[3]="Functions"
	$level2_1[4]="Variables"
	$level2_1[0]=UBound($level2_1)-1

	Local $level3_2_1a[9]		; by subject, general
	$level3_2_1a[1]="Report Summary (text file)"
	$level3_2_1a[2]="List of potential issues"
	$level3_2_1a[3]="Calling Statistics"
	$level3_2_1a[4]="Tracked Features"
	$level3_2_1a[5]="Main Code Sections"
	$level3_2_1a[6]="Loops"
	$level3_2_1a[7]="Entry points"
	$level3_2_1a[8]="Exit points"
	$level3_2_1a[0]=UBound($level3_2_1a)-1

	$displayoptionstrings[1]=$level3_2_1a[1]
	$displayoptionstrings[2]=$level3_2_1a[2]
	$displayoptionstrings[22]=$level3_2_1a[3]
	$displayoptionstrings[23]=$level3_2_1a[4]
	$displayoptionstrings[30]=$level3_2_1a[5]
	$displayoptionstrings[27]=$level3_2_1a[6]
	$displayoptionstrings[31]=$level3_2_1a[7]
	$displayoptionstrings[28]=$level3_2_1a[8]

	Local $level3_2_1b[7]		; by subject, includes
	$level3_2_1b[1]="Includes Architecture (treeview)"
	$level3_2_1b[2]="Includes, Statistics"
	$level3_2_1b[3]="Includes, non-native"
	$level3_2_1b[4]="Includes, included-once"
	$level3_2_1b[5]="Includes, redundant"
	$level3_2_1b[6]="Includes, not found"
	$level3_2_1b[0]=UBound($level3_2_1b)-1

	$displayoptionstrings[7]=$level3_2_1b[2]
	$displayoptionstrings[8]=$level3_2_1b[3]
	$displayoptionstrings[9]=$level3_2_1b[4]
	$displayoptionstrings[10]=$level3_2_1b[5]
	$displayoptionstrings[11]=$level3_2_1b[6]

	Local $level3_2_1c[10]		; by subject, Functions
	$level3_2_1c[1]="Native AutoIt Functions"
	$level3_2_1c[2]="Native AutoIt Functions, Called"
	$level3_2_1c[3]="UDF Architecture (treeview)"
	$level3_2_1c[4]="UDFs, defined (incl. inactives)"
	$level3_2_1c[5]="UDFs, unique active, All"
	$level3_2_1c[6]="UDFs, unique active, Calling"
	$level3_2_1c[7]="UDFs, unique active, Called"
	$level3_2_1c[8]="UDFs, unique undefined, Called"
	$level3_2_1c[9]="UDFs, unique duplicate"
	$level3_2_1c[0]=UBound($level3_2_1c)-1

	$displayoptionstrings[24]=$level3_2_1c[1]
	$displayoptionstrings[29]=$level3_2_1c[2]
	$displayoptionstrings[12]=$level3_2_1c[4]
	$displayoptionstrings[13]=$level3_2_1c[5]
	$displayoptionstrings[14]=$level3_2_1c[6]
	$displayoptionstrings[15]=$level3_2_1c[7]
	$displayoptionstrings[16]=$level3_2_1c[8]
	$displayoptionstrings[17]=$level3_2_1c[9]

	Local $level3_2_1d[12]		; by subject, variables
	$level3_2_1d[1]="Strings, sequential"
	$level3_2_1d[2]="Strings, sorted"
	$level3_2_1d[3]="Variables, sequential"
	$level3_2_1d[4]="Variables, sorted"
	$level3_2_1d[5]="Globals, All"
	$level3_2_1d[6]="Globals, non-native, with refs (text file)"
	$level3_2_1d[7]="Globals, non-native"
	$level3_2_1d[8]="Globals, UDF-only defined"
	$level3_2_1d[9]="Globals, redundant"
	$level3_2_1d[10]="Array variables"
	$level3_2_1d[11]="Macros, Used"
	$level3_2_1d[0]=UBound($level3_2_1d)-1

	$displayoptionstrings[26]=$level3_2_1d[1]
	$displayoptionstrings[32]=$level3_2_1d[2]
	$displayoptionstrings[25]=$level3_2_1d[3]
	$displayoptionstrings[33]=$level3_2_1d[4]
	$displayoptionstrings[18]=$level3_2_1d[5]
	$displayoptionstrings[21]=$level3_2_1d[6]
	$displayoptionstrings[19]=$level3_2_1d[7]
	$displayoptionstrings[20]=$level3_2_1d[8]
	$displayoptionstrings[34]=$level3_2_1d[9]
	$displayoptionstrings[35]=$level3_2_1d[10]
	$displayoptionstrings[36]=$level3_2_1d[11]

	Local $level4_3_2_1[3]
	$level4_3_2_1[1]="sequential"
	$level4_3_2_1[2]="sorted"
	$level4_3_2_1[0]=UBound($level4_3_2_1)-1

	Local $level2_2[5]		; by format (item titles should match the ones defined earlier)
	$level2_2[1]="Text files"
	$level2_2[2]="Trees"
	$level2_2[3]="Tables"
	$level2_2[4]="Lists"
	$level2_2[0]=UBound($level2_2)-1

	Local $level3_2_2a[3]		; by format, text file
	$level3_2_2a[1]="Report Summary"
	$level3_2_2a[2]="Globals, non-native, with refs"
	$level3_2_2a[0]=UBound($level3_2_2a)-1

	Local $level3_2_2b[3]		; by format, treeview
	$level3_2_2b[1]="Includes Architecture"
	$level3_2_2b[2]="UDF Architecture"
	$level3_2_2b[0]=UBound($level3_2_2b)-1

	Local $level3_2_2c[11]		; by format, arraydisplay 2-D
	$level3_2_2c[1]="List of potential issues"
	$level3_2_2c[2]="Calling Statistics"
	$level3_2_2c[3]="Tracked Features"
	$level3_2_2c[4]="Includes, Statistics"
	$level3_2_2c[5]="Loops"
	$level3_2_2c[6]="Main Code Sections"
	$level3_2_2c[7]="Entry Points"
	$level3_2_2c[8]="Exit Points"
	$level3_2_2c[9]="Globals, non-native"
	$level3_2_2c[10]="Globals, UDF-only defined"
	$level3_2_2c[0]=UBound($level3_2_2c)-1

	Local $level3_2_2d[21]		; by format, arraydisplay 1-D
	$level3_2_2d[1]="Includes, non-native"
	$level3_2_2d[2]="Includes, included-once"
	$level3_2_2d[3]="Includes, redundant"
	$level3_2_2d[4]="Includes, not found"
	$level3_2_2d[5]="Native AutoIt Functions"
	$level3_2_2d[6]="Native AutoIt Functions, Called"
	$level3_2_2d[7]="UDFs, defined (incl. inactives)"
	$level3_2_2d[8]="UDFs, unique active, All"
	$level3_2_2d[9]="UDFs, unique active, Calling"
	$level3_2_2d[10]="UDFs, unique active, Called"
	$level3_2_2d[11]="UDFs, unique undefined, Called"
	$level3_2_2d[12]="UDFs, unique duplicate"
	$level3_2_2d[13]="Variables, sequential"
	$level3_2_2d[14]="Variables, sorted"
	$level3_2_2d[15]="Strings, sequential"
	$level3_2_2d[16]="Strings, sorted"
	$level3_2_2d[17]="Globals, All"
	$level3_2_2d[18]="Globals, redundant"
	$level3_2_2d[19]="Array variables"
	$level3_2_2d[20]="Macros, Used"
	$level3_2_2d[0]=UBound($level3_2_2d)-1

	Local $level2_3[4]			; MetaCode options
	$level2_3[1]="Show/Edit MC File"		; text editor opens MCF#.txt
	$level2_3[2]="Create Single-Build"	; build MCF0.txt, stripping all redundancies
	$level2_3[3]="Back-Translate"			; create MCF0.au3 from MCF0.txt
	$level2_3[0]=UBound($level2_3)-1

	Global $treemenu[1]

	For $lc1=1 To $level1[0]
		_arrayadd($treemenu, $level0 & $separator & $level1[$lc1],0,Chr(0))
	Next

	$lc1=6
	For $lc2=1 To $level2_1[0]
		_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_1[$lc2],0,Chr(0))
		Switch $lc2
			Case 1
				For $lc3=1 To $level3_2_1a[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_1[$lc2] & $separator & $level3_2_1a[$lc3],0,Chr(0))
				Next
			Case 2
				For $lc3=1 To $level3_2_1b[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_1[$lc2] & $separator & $level3_2_1b[$lc3],0,Chr(0))
					If $lc3=1 Then
						For $lc4=1 To $level4_3_2_1[0]
							_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_1[$lc2] & $separator & $level3_2_1b[$lc3] & $separator & $level4_3_2_1[$lc4],0,Chr(0))
						Next
					EndIf
				Next
			Case 3
				For $lc3=1 To $level3_2_1c[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_1[$lc2] & $separator & $level3_2_1c[$lc3],0,Chr(0))
					If $lc3=3 Then
						For $lc4=1 To $level4_3_2_1[0]
							_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_1[$lc2] & $separator & $level3_2_1c[$lc3] & $separator & $level4_3_2_1[$lc4],0,Chr(0))
						Next
					EndIf
				Next
			Case 4
				For $lc3=1 To $level3_2_1d[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_1[$lc2] & $separator & $level3_2_1d[$lc3],0,Chr(0))
				Next
		EndSwitch
	Next

	$lc1=7
	For $lc2=1 To $level2_2[0]
		_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_2[$lc2],0,Chr(0))
		Switch $lc2
			Case 1
				For $lc3=1 To $level3_2_2a[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_2[$lc2] & $separator & $level3_2_2a[$lc3],0,Chr(0))
				Next
			Case 2
				For $lc3=1 To $level3_2_2b[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_2[$lc2] & $separator & $level3_2_2b[$lc3],0,Chr(0))
					For $lc4=1 To $level4_3_2_1[0]
						_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_2[$lc2] & $separator & $level3_2_2b[$lc3] & $separator & $level4_3_2_1[$lc4],0,Chr(0))
					Next
				Next
			Case 3
				For $lc3=1 To $level3_2_2c[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_2[$lc2] & $separator & $level3_2_2c[$lc3],0,Chr(0))
				Next
			Case 4
				For $lc3=1 To $level3_2_2d[0]
					_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_2[$lc2] & $separator & $level3_2_2d[$lc3],0,Chr(0))
				Next
		EndSwitch
	Next

	$lc1=8
	For $lc2=1 To $level2_3[0]
		_arrayadd($treemenu, $level0 & $separator & $level1[$lc1] & $separator & $level2_3[$lc2],0,Chr(0))
	Next
	$treemenu[0]=UBound($treemenu)-1

EndFunc


Func _TreeviewMenu()

	If $hGUImenu="" Then
		If $showprogress=True Then SplashTextOn("","Building TreeView Menu..." ,250,40,-1,-1,1+32,"Verdana",10)

		Local $viewsize=450,$boxheight=150
		Local $iStyle = BitOR($TVS_HASBUTTONS, $TVS_HASLINES, $TVS_LINESATROOT, $TVS_DISABLEDRAGDROP, $TVS_SHOWSELALWAYS, $TVS_NOTOOLTIPS)
		Global $hGUImenu = GUICreate("Code Scanner Main Menu", $viewsize, $viewsize+$boxheight)

		Global $hTreeViewMenu = _GUICtrlTreeView_Create($hGUImenu, 2, 2, $viewsize-4, $viewsize-4, $iStyle, $WS_EX_CLIENTEDGE)
		Global $idTV = _WinAPI_GetDlgCtrlID($hTreeViewMenu)

		Global $hEditmenu = GUICtrlCreateEdit("Please wait...", 2, $viewsize+4, $viewsize-4, $boxheight-8, BitOr($ES_MULTILINE,$ES_READONLY,$WS_VSCROLL))
		GUICtrlSetColor($hEditmenu,0x000080)
		GUICtrlSetFont($hEditmenu,10,600)

		_GUICtrlTreeView_BeginUpdate($hTreeViewMenu)
		$hItem = _GUICtrlTreeView_Add($hTreeViewMenu, 0, $level0)

		For $bc =1 To $treemenu[0]
			$curbranch=$treemenu[$bc]

			; create a branch search key
			$cursource=StringReplace(StringLeft($curbranch,StringInStr($curbranch,$separator,0,-1)),$separator,"|")

			; identify new branch to add
			$curinclude=StringTrimLeft($curbranch,StringInStr($curbranch,$separator,0,-1)+StringLen($separator)-1)

			; graft at right place
			$hItem=_GUICtrlTreeView_FindItemEx($hTreeViewMenu, $cursource)
			If $hItem>0 Then
				$newhandle=_GUICtrlTreeView_AddChild($hTreeViewmenu, $hItem, $curinclude)
				If $curinclude="Results by Subject" Then $RBShandle=$newhandle
				If $curinclude="Results by Format" Then $RBFhandle=$newhandle
				If $curinclude="MetaCode" Then $MChandle=$newhandle
			Else
				ConsoleWrite("branch not found: " & $cursource & @CRLF)
			EndIf
		Next

		_GUICtrlTreeView_Expand($hTreeViewMenu)

		$hItem = _GUICtrlTreeView_GetFirstItem($hTreeViewMenu)
		_GUICtrlTreeView_SetBold($hTreeViewMenu,$hItem)
		While $hItem <> 0
			$itemtext=_GUICtrlTreeView_GetText($hTreeViewMenu,$hItem)
			$hitem1=_GUICtrlTreeView_GetParentHandle($hTreeViewMenu,$hitem)
			$parentext=_GUICtrlTreeView_GetText($hTreeViewMenu,$hItem1)

			If (_GUICtrlTreeView_Level($hTreeViewMenu,$hItem)=2 And $parentext<>"MetaCode") Or _
			StringLeft(_GUICtrlTreeView_GetText($hTreeViewMenu,$hItem),11)="Results by " Or _
			StringLeft(_GUICtrlTreeView_GetText($hTreeViewMenu,$hItem),11)="MetaCode" Then _
				_GUICtrlTreeView_SetBold($hTreeViewMenu,$hItem)
			$hItem = _GUICtrlTreeView_GetNext($hTreeViewMenu, $hItem)
		WEnd

		_GUICtrlTreeView_SetIndent($hTreeViewMenu,30)
		_GUICtrlTreeView_EndUpdate($hTreeViewMenu)

		Global $treeviewmenuhome = GUICtrlCreateDummy()
		Global $treeviewmenuexit = GUICtrlCreateDummy()
		Global $treeviewmenuactivate = GUICtrlCreateDummy()
		Global $AccelKeysmenu[3][2] = [["{Home}", $treeviewmenuhome],["{Esc}", $treeviewmenuexit],["{Enter}", $treeviewmenuactivate]]
		GUISetAccelerators($AccelKeysmenu)
		SplashOff()

	EndIf

	; expand/collapse branches?
	_GUICtrlTreeView_Expand($hTreeViewmenu,$RBShandle,$showResultsBySubject)
	_GUICtrlTreeView_Expand($hTreeViewmenu,$RBFhandle,$showResultsByFormat)
	_GUICtrlTreeView_Expand($hTreeViewmenu,$MChandle,$showMetaCode)

	; move view to top
	$hItem=_GUICtrlTreeView_GetFirstItem($hTreeViewMenu)
	_GUICtrlTreeView_SelectItem($hTreeViewMenu,$hItem)

	GUISetState(@SW_SHOW,$hGUImenu)
	_UnFadeGUI($hGUImenu)

	GUICtrlSetData($hEditmenu,"Press <Enter> or double-click to activate a selection." & @CRLF & @CRLF & $stats & @CRLF & $settingslist)

	Global $item_clicked=False
	Global $itemtext=""
	Global $selection_changed=False

	While True

		Local $msg=GUIGetMsg()
		Select
			Case $msg = $GUI_EVENT_CLOSE Or $msg = $treeviewmenuexit
				GUIDelete()
				Exit (0)

			Case $msg = $treeviewmenuhome
				$hItem=_GUICtrlTreeView_GetFirstItem($hTreeViewMenu)
				_GUICtrlTreeView_SelectItem($hTreeViewMenu,$hItem)

			Case $msg = $treeviewmenuactivate Or $item_clicked=true
				$item_clicked=False
				$hItem=_GUICtrlTreeView_GetSelection($hTreeViewMenu)
				$itemtext=_GUICtrlTreeView_GetText($hTreeViewMenu,$hItem)

				If _GUICtrlTreeView_IsFirstItem($hTreeViewMenu,$hitem) Then
					MsgBox(262144+8192+64,"About CodeScanner","Codescanner version 2.7" & @CR & "Latest Revision: 24 July 2014" & @CR & Chr(169) & " RTFC, 2013-14.")
				Else
					If _GUICtrlTreeView_GetBold($hTreeViewMenu,$hItem)=False Then
						$caseindex=-1
						Select
							Case $itemtext="Rescan"
								$tmproot=$includes[1]
								_PrepGlobals()
								$includes[1]=$tmproot
								$myincludes[1]=$tmproot
								ExitLoop

							Case $itemtext="New File"
								_PrepGlobals()
								_FadeGUI($hGUImenu)
								_GetNewRootfile()
								ExitLoop

							Case $itemtext="Settings" Or $itemtext="Data Dump"
								_FadeGUI($hGUImenu)
								If $itemtext="Settings" Then
									_Settings()
								Else
									_WriteCSDataDump()
								EndIf
								_UnFadeGUI($hGUImenu)

							Case $itemtext="Exit"
								Exit (0)

							Case $itemtext="Show/Edit MC File"		; text editor opens MCF#.txt
								_FadeGUI($hGUImenu)
								_ShowMCFile($CS_dumppath)
								_UnFadeGUI($hGUImenu)

							Case $itemtext="Create Single-Build"	; build MCF0.txt, stripping all redundancies
								_FadeGUI($hGUImenu)
								$outfile=$CS_dumppath & "MCF0.txt"
								If FileExists($outfile) Then FileDelete($outfile)
								$ret=_CreateSingleBuild($CS_dumppath,True)
								SplashOff()
								If $ret=True And FileExists($outfile) Then	; force full reprocessing
									If MsgBox(262144+8192+256+64+4,"CodeScanner MFC","MCF0.txt written to subdirectory:" & _
										@CR & $CS_dumppath & @CR & @CR & "Inspect now?")=6 Then _ShowMCFile($CS_dumppath,$outfile)
								Else
									MsgBox(262144+8192+48,"Code Scanner","Creation of Single-Build has failed; exitcode: " & @error)
								EndIf
								_UnFadeGUI($hGUImenu)

							Case $itemtext="Back-Translate"			; create MCF0.au3 from MCF0.txt + arrays *Used[]
								_FadeGUI($hGUImenu)

								$outfile=$CS_dumppath & "MCF0.au3"
								If FileExists($outfile) Then FileDelete($outfile)

								$errortotal=_BackTranslate($CS_dumppath,True)	; force full reprocessing
								SplashOff()
								If $errortotal=0 And FileExists($outfile) Then
									If MsgBox(262144+8192+256+64+4,"CodeScanner MFC","MCF0.au3 written to subdirectory:" & _
										@CR & $CS_dumppath & @CR & @CR & "Inspect now?")=6 Then _ShowMCFile($CS_dumppath,$outfile)
								Else	; if $showprogress=True, _BackTranslate() displays its own, mpore detailed errormsg
									If $showprogress=False Then MsgBox(262144+8192+48,"Code Scanner","BackTranslation failed." & @CR & @CR & "Number of errors: " & $errortotal)
								EndIf
								_UnFadeGUI($hGUImenu)

							Case StringInStr($itemtext,"architecture")
								If StringLeft($itemtext,8)="Includes" Then
									$caseindex=3		; defaults to sequential display
								ElseIf StringLeft($itemtext,3)="UDF" Then
									$caseindex=5		; defaults to sequential display
								EndIf

							Case StringInStr($itemtext,"sequential") Or StringInStr($itemtext,"sorted")
								$hitem1=_GUICtrlTreeView_GetParentHandle($hTreeViewMenu,$hitem)
								$parentext=_GUICtrlTreeView_GetText($hTreeViewMenu,$hItem1)

								Select
									Case StringInStr($itemtext,"sequential")
										Select
											Case StringLeft($parentext,8)="Includes"
												$caseindex=3
											Case StringLeft($parentext,3)="UDF"
												$caseindex=5
											Case StringLeft($itemtext,7)="Strings"
												$caseindex=26
											Case StringLeft($itemtext,9)="Variables"
												$caseindex=25
										EndSelect

									Case StringInStr($itemtext,"sorted")
										Select
											Case StringLeft($parentext,8)="Includes"
												$caseindex=4
											Case StringLeft($parentext,3)="UDF"
												$caseindex=6
											Case StringLeft($itemtext,7)="Strings"
												$caseindex=32
											Case StringLeft($itemtext,9)="Variables"
												$caseindex=33
										EndSelect
								EndSelect

							Case Else
								$caseindex=_ArraySearch($displayoptionstrings,$itemtext,0,0,0,1)

						EndSelect

						If $caseindex>0 And $caseindex<=$maxdisplayoption Then
							_FadeGUI($hGUImenu)
							_DisplayListItem($caseindex)
							_UnFadeGUI($hGUImenu)
						EndIf
					EndIf
				EndIf
		EndSelect
	WEnd
	GUISetState(@SW_HIDE,$hGUImenu)
	Return True	; flag for main loop to re-analyse

EndFunc


Func _FadeGUI($hGUI)

	GUIRegisterMsg($WM_NOTIFY, "")
	WinSetTrans($hGUI,"",153)
	GUISetState(@SW_DISABLE,$hGUI)

EndFunc


Func _UnFadeGUI($hGUI)

	GUIRegisterMsg($WM_NOTIFY, "_WM_NOTIFY_TreeView")
	GUISetState(@SW_ENABLE,$hGUI)
	GUISetState(@SW_SHOW,$hGUI)
	WinSetTrans($hGUI,"",255)
	WinSetOnTop($hGUI,"",1)		; move to front
	WinSetOnTop($hGUI,"",0)		; allow other windows on top of it again
	WinActivate($hGUI)

EndFunc


Func _GetNewRootfile($fname="")
; filters for extension .au3; amend as needed

	; contains full path
	If $fname="" Then
		If $runquiet=True Then Exit (-11)
		$includes[1]=FileOpenDialog("CODE SCANNER: Please select a root file to scan", @ScriptDir & "\", "AutoIt files (*.au3)", 1+2)
		If @error Then	_IOerror("No file selected")

	Else	; may or may not contain any path; if it does, it is valid
		$pos=StringInStr($fname,"\")
		If $pos=0 Or StringLeft($fname,2)=".\" Then
			$fname=@ScriptDir & "\" & $fname
		Else
			If StringLeft($fname,3)="..\" Then $fname=Stringleft(@ScriptDir,StringInStr(@scriptdir,"\",0,-1)) & $fname
		EndIf						; may still contain dots, but should work anyway
		$includes[1]=$fname
	EndIf
	$myincludes[1]=$includes[1]
	; rootfile = filename only
	Global $rootpath=StringLeft($includes[1],StringInStr($includes[1],"\",0,-1))
	Global $rootfile=StringTrimLeft($includes[1],StringInStr($includes[1],"\",0,-1))
	Global $trimmedroot=$rootfile
	If stringLen($rootfile)>35 Then $trimmedroot=StringLeft($rootfile,17) & "..." & StringRight($rootfile,17)

	Global $CS_dumppath=$rootpath & $rootfile & ".CS_DATA\"

EndFunc


Func _DisplayListItem($selection)

	Switch $selection
		Case 1		;	"Open Notepad with <Report Summary> (for saving)"
			$tmpfile=_TempFile(@tempdir,"","txt",8)
			If FileWrite($tmpfile,$report)=0 Then Return
			Sleep(250)	; handle release grace period
			If FileExists(@WindowsDir & "\notepad.exe") Then
				RunWait(@WindowsDir & "\notepad.exe " & $tmpfile,@ScriptDir)
			Else
				ShellExecuteWait($tmpfile,"",@ScriptDir)	; other default editor?
			EndIf
			FileDelete($tmpfile)

		Case 2
			_ArrayDisplay($problems,"Identified potential issues")

		Case 3
			If $pairs>0 Then
				_Treeview(1,False)
			Else
				MsgBox(262144+8192+48,"Code Scanner","No #includes found")
			EndIf

		Case 4
			If $pairs>0 Then
				_Treeview(1,True)
			Else
				MsgBox(262144+8192+48,"Code Scanner","No #includes found")
			EndIf

		Case 5
			If $uniquefuncsAll[0]>0 Then
				_Treeview(2,False)
			Else
				MsgBox(262144+8192+48,"Code Scanner","No active UDFs found")
			EndIf

		Case 6
			If $uniquefuncsAll[0]>0 Then
				_Treeview(2,True)
			Else
				MsgBox(262144+8192+48,"Code Scanner","No active UDFs found")
			EndIf

		Case 7
			If $include_stats[0][0]>0 Then
				_ArrayDisplay($include_stats, "#include statistics (sequential)")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No #includes found")
			EndIf

		Case 8
			_ArrayDisplay($myincludes, "non-native #includes")	; cannot be empty

		Case 9
			If $includeonce[0]>0 Then
				_ArrayDisplay($includeonce, "#included-once")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No #include-once found")
			EndIf

		Case 10
			If $includesRedundant[0]>0 Then
				_ArrayDisplay($includesRedundant, "Redundant #includes")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No redundant #includes found")
			EndIf

		Case 11
			If $incl_notfound[0]>0 Then
				_ArrayDisplay($incl_notfound, "#includes not found")
			Else
				MsgBox(262144+8192+48,"Code Scanner","All #includes accounted for; no lost sheep")
			EndIf

		Case 12
			If $functionsDefined[0]>0 Then
				_ArrayDisplay($functionsDefined, "UDFs, Defined")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No defined UDFs found")
			EndIf

		Case 13
			If $uniquefuncsAll[0]>0 Then
				_ArrayDisplay($uniquefuncsAll, "active UDFs (all)")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No active UDFs found")
			EndIf

		Case 14
			If $uniqueFuncsCalling[0]>0 Then
				_ArrayDisplay($uniqueFuncsCalling, "active UDFs (calling)")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No active, calling UDFs found")
			EndIf

		Case 15
			If $uniqueFuncsCalled[0]>0 Then
				_ArrayDisplay($uniqueFuncsCalled, "active UDFs (called)")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No active, called UDFs found")
			EndIf

		Case 16
			If $unknownUDFs[0]>0 Then
				_ArrayDisplay($unknownUDFs, "undefined UDFs (called)")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No undefined, called UDFs found")
			EndIf

		Case 17
			If $dupes[0]>0 Then
				_ArrayDisplay($dupes, "multiple-defined UDFs")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No multiple-defined UDFs found")
			EndIf

		Case 18
			If $globals[0]>0 Then
				_ArrayDisplay($globals, "Globals")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No globals found")
			EndIf

		Case 19
			If $refglobals[0][0]>0 Then
				_ArrayDisplay($refglobals, "Non-native globals")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No non-native globals found")
			EndIf

		Case 20
			If $globalsinFuncs[0][0]>0 Then
				_ArrayDisplay($globalsinFuncs, "Non-native globals, defined only within UDFs")
			Else
				MsgBox(262144+8192+48,"Code Scanner","All globals are defined at least once outside UDFs")
			EndIf

		Case 21
			If $refglobals[0][0]>0 Then
				$tmpfile=_TempFile(@tempdir,"","au3",8)
				If FileWrite($tmpfile,$globaldeflist)=0 Then Return
				Sleep(250)	; handle release grace period
				If FileExists(@WindowsDir & "\notepad.exe") Then
					RunWait(@WindowsDir & "\notepad.exe " & $tmpfile,@ScriptDir)
				Else
					ShellExecuteWait($tmpfile,"",@ScriptDir)	; other default editor?
				EndIf
			FileDelete($tmpfile)
			Else
				MsgBox(262144+8192+48,"Code Scanner","No non-native globals found")
			EndIf

		Case 22
			If $refindex[0][0]>0 Then
				_ArrayDisplay($refindex, "Referenced locations and calling statistics")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No referenced locations found")
			EndIf

		Case 23
			If $references[0][0]>0 Then
				_ArrayDisplay($references, "Tracked features, All")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No tracked features found")
			EndIf

		Case 24
			If $AU3FunctionsUsed[0]>0 Then
				_ArrayDisplay($AU3FunctionsUsed, "Native AutoIt Functions, All")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No native AutoIt Functions found")
			EndIf

		Case 25
			If $variablesUsed[0]>0 Then
				_ArrayDisplay($variablesUsed, "Variables, sequential")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No variables found")
			EndIf

		Case 26
			If $stringsUsed[0]>0 Then
				_ArrayDisplay($stringsUsed, "Strings, sequential")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No strings found")
			EndIf

		Case 27
			If $loops[0][0]>0 Then
				_ArrayDisplay($loops, "Loops")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No loops found")
			EndIf

		Case 28
			If $Exitpoints[0][0]>0 Then
				_ArrayDisplay($Exitpoints, "Exit points")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No exit point(s) found")
			EndIf

		Case 29
			If $AU3FunctionsCalled[0]>0 Then
				_ArrayDisplay($AU3FunctionsCalled, "Native AutoIt Functions, Called")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No Called native AutoIt Functions found")
			EndIf

		Case 30
			If $mainCodeSections[0][0]>0 Then
				_ArrayDisplay($mainCodeSections, "Main Code Sections")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No main code sections found")
			EndIf

		Case 31
			If $Entrypoints[0][0]>0 Then
				_ArrayDisplay($Entrypoints, "Entry points")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No entry point(s) found")
			EndIf

		Case 32
			If $stringsUsedsorted[0]>0 Then
				_ArrayDisplay($stringsUsedsorted, "Strings, sorted")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No strings found")
			EndIf

		Case 33
			If $variablesUsedsorted[0]>0 Then
				_ArrayDisplay($variablesUsedsorted, "Variables, sorted")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No variables found")
			EndIf

		Case 34
			If $globalsRedundant[0]>0 Then
				_ArrayDisplay($globalsRedundant, "Globals, redundant")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No redundant globals found")
			EndIf

		Case 35
			If $variableIsArray[0]>0 Then
				_ArrayDisplay($variableIsArray, "Array variables")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No array variables found")
			EndIf

		Case 36
			If $macrosUsed[0]>0 Then
				_ArrayDisplay($macrosUsed, "Macros, All")
			Else
				MsgBox(262144+8192+48,"Code Scanner","No macros found")
			EndIf
	EndSwitch

EndFunc


Func _Treeview($pass, $resortree=False)

	If $showprogress=True Then
		SplashTextOn("","Building Tree..." ,250,40,-1,-1,1+32,"Verdana",10)
		$EscPressed=False
		HotKeySet("{Esc}", "_CaptureEsc")
	EndIf

	Global $tree
	Local $GUI, $hItem,$viewsize=450,$boxheight=150,$suffix="(sequential)"
	If $resortree=True Then $suffix="(sorted)"
	$iStyle = BitOR($TVS_HASBUTTONS, $TVS_HASLINES, $TVS_LINESATROOT, $TVS_DISABLEDRAGDROP, $TVS_SHOWSELALWAYS, $TVS_NOTOOLTIPS)
	If $pass=1 Then
		$GUI = GUICreate("Code Scanner Treeview: #Includes Architecture  " & $suffix, $viewsize, $viewsize+$boxheight)
		$tree=$treeIncl
		$cursource=$includes[1]		; full path
	ElseIf $pass=2 then
		$GUI = GUICreate("Code Scanner Treeview: UDF Calls Architecture  " & $suffix, $viewsize, $viewsize+$boxheight)
		$tree=$treeFunc
		$cursource=$rootfile			; filename only
	Else
		Return
	EndIf

	$hTreeView = _GUICtrlTreeView_Create($GUI, 2, 2, $viewsize-4, $viewsize-4, $iStyle, $WS_EX_CLIENTEDGE)
	$hEdit = GUICtrlCreateEdit("Please wait...", 2, $viewsize+4, $viewsize-4, $boxheight-8, bitor($ES_MULTILINE,$ES_READONLY,$WS_VSCROLL))
	GUICtrlSetColor($hEdit,0x000080)
	GUICtrlSetFont($hEdit,10,600)

	_GUICtrlTreeView_BeginUpdate($hTreeView)
	$hItem = _GUICtrlTreeView_Add($hTreeView, 0, $cursource)

	For $bc =1 To $tree[0]
		$curbranch=$tree[$bc]

		; identify new branch to add
		$curinclude=StringTrimLeft($curbranch,StringInStr($curbranch,$separator,0,-1)+StringLen($separator)-1)

		; Settings-determined pruning
		If $showfirstduplication=False And StringInStr($curinclude,$duplicatestag) Then ContinueLoop
		If $pass=2 And $showAU3native=False Then
			$notag=$curinclude
			$pos=StringInStr($curinclude,$tagmarker)
			If $pos>0 Then $notag=StringLeft($curinclude,$pos-1)
			If _ArraySearch($AU3Functions,$notag)>0 Then	ContinueLoop
		EndIf

		; create a branch search key
		$cursource=StringReplace(StringLeft($curbranch,StringInStr($curbranch,$separator,0,-1)),$separator,"|")

		; graft at right place
		$hItem=_GUICtrlTreeView_FindItemEx($hTreeView, $cursource)

		If $hItem>0 Then _GUICtrlTreeView_AddChild($hTreeView, $hItem, $curinclude)

		If $showprogress=True and Mod($bc,20)=0 Then
			If $EscPressed=True Then
				SplashOff()
				GUIDelete($GUI)
				Return
			EndIf
			SplashTextOn("","Building Tree (" & Floor(100*$bc/$tree[0]) & "% done)...",250,40,-1,-1,1+32,"Verdana",10)
		EndIf
	Next
	If $showprogress=True Then HotKeySet("{Esc}")

	_GUICtrlTreeView_Expand($hTreeView)
	_GUICtrlTreeView_EndUpdate($hTreeView)

	If $resortree=True Then
		$hItem = _GUICtrlTreeView_GetFirstItem($hTreeView)
		$dllhandle=DllOpen("user32.dll")
		While $hItem <> 0
			DllCall($dllhandle,'int','SendMessage', 'hwnd',$hTreeView, 'uint',$TVM_SORTCHILDREN, 'wparam',1, 'lparam',$hItem)	; wparam=1: recursive sorting
			$hItem = _GUICtrlTreeView_GetNext($hTreeView, $hItem)
		WEnd
		DllClose($dllhandle)
	EndIf

	; move view to top
	$hItem=_GUICtrlTreeView_GetFirstItem($hTreeView)
	_GUICtrlTreeView_SelectItem($hTreeView,$hItem)

	$finditem = GUICtrlCreateDummy()
	$findnext = GUICtrlCreateDummy()
	$findprev = GUICtrlCreateDummy()
	$treeviewhome = GUICtrlCreateDummy()
	$treeviewexit = GUICtrlCreateDummy()
	Local $AccelKeys[6][2] = [["^{f}", $finditem],["{F3}", $findnext],["+{F3}", $findprev],["!{F3}", $findprev],["{Home}", $treeviewhome],["{Esc}", $treeviewexit]]
	GUISetAccelerators($AccelKeys)

	GUISetState()
	SplashOff()
	GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
	WinActivate($GUI)

	$tree_info="Select any branch to highlight duplicates and display info." & _
		@CRLF & @CRLF & "Press <Ctrl><F>  to find String, then <F3> / <Shif><F3> to select Next / Previous occurrence;" & @CRLF  & _
							"<Home> to re-select root file;" & @CRLF & _
							"<Esc> to return to Main Menu." & @CRLF & @CRLF
	If $pass=1 Then
		$tree_info&="Toggle Show/Hide duplicates in Settings Panel"
	Else
		$tree_info&="Toggle Show/Hide duplicates and native Autoit functions in Settings Panel"
	EndIf
	GUICtrlSetData($hEdit,$tree_info)

	$treeviewsearchstring=""
	Global $itemtext=""
	Global $selection_changed=False
	While True
		If $selection_changed=True then
			$pos=stringinstr($itemtext,$tagmarker)
			If $pos>0 Then $itemtext=StringLeft($itemtext,$pos-1)
			$selected_item=_GUICtrlTreeView_GetSelection($hTreeView)

			$dupcounter=0
			$hItem = _GUICtrlTreeView_GetFirstItem($hTreeView)
         For $i = 0 To _GUICtrlTreeView_GetCount($hTreeView) - 1
				$curitem=_GUICtrlTreeView_GetText($hTreeView,$hItem)
				$pos=StringInStr($curitem,$tagmarker)
				If $pos>0 Then $curitem=StringLeft($curitem,$pos-1)
				_GUICtrlTreeView_SetBold($hTreeView,$hItem,($curitem=$itemtext And $hItem<>$selected_item))
				If Stringinstr($curitem,$itemtext) Then $dupcounter+=1
            $hItem = _GUICtrlTreeView_GetNext($hTreeView, $hItem)
			Next

			GUICtrlSetData($hEdit,_BuildProfile($pass,$dupcounter)) ;& " " & $tree[$index])
			$selection_changed=False
		EndIf

		Local $msg=GUIGetMsg()
		Select
			Case $msg = $GUI_EVENT_CLOSE
				ExitLoop
			Case $msg = $treeviewexit
				ExitLoop
			Case $msg = $treeviewhome
				$hItem=_GUICtrlTreeView_GetFirstItem($hTreeView)
				_GUICtrlTreeView_SelectItem($hTreeView,$hItem)
			Case $msg = $finditem

				$treeviewsearchstring=InputBox("Treeview search","Search string: ","","",200,140)
				If @error Or $treeviewsearchstring="" Then
					$treeviewsearchstring=""
					ContinueLoop
				EndIf

				$hItem = _GUICtrlTreeView_FindItem($hTreeView, $treeviewsearchstring,1)
				If $hItem Then
					$firstitem=$hItem
					$lastitemfound=$hItem
					_GUICtrlTreeView_SelectItem($hTreeView,$hItem)
				Else
					GUICtrlSetData($hEdit,"Search string not found:" & @CRLF & @CRLF & $treeviewsearchstring)
				EndIf

			Case $msg = $findnext
				If $treeviewsearchstring<>"" And $lastitemfound<>"" Then
					$prevlastitem=$lastitemfound
					_GUICtrlTreeView_SelectItem($hTreeView,$lastitemfound)
					$hItem = _GUICtrlTreeView_GetNextVisible($hTreeView, $lastitemfound)
					While $hItem
						If StringInStr(_GUICtrlTreeView_GetText($hTreeView, $hItem),$treeviewsearchstring) Then
							$lastitemfound=$hItem
							ExitLoop
						EndIf
						$hItem = _GUICtrlTreeView_GetNextVisible($hTreeView, $hItem)
					WEnd
					If $lastitemfound<>$prevlastitem Then
						_GUICtrlTreeView_SelectItem($hTreeView,$lastitemfound)
					Else			; wrap-around
						_GUICtrlTreeView_SelectItem($hTreeView,$firstitem)
						$lastitemfound=$firstitem
					EndIf
				EndIf

			Case $msg = $findprev
				If $treeviewsearchstring<>"" And $lastitemfound<>"" Then
					$prevlastitem=$lastitemfound
					_GUICtrlTreeView_SelectItem($hTreeView,$lastitemfound)
					$hItem = _GUICtrlTreeView_GetPrevVisible($hTreeView, $lastitemfound)
					While $hItem
						If StringInStr(_GUICtrlTreeView_GetText($hTreeView, $hItem),$treeviewsearchstring) Then
							$lastitemfound=$hItem
							ExitLoop
						EndIf
						$hItem = _GUICtrlTreeView_GetPrevVisible($hTreeView, $hItem)
					WEnd
					; sorry, no reverse wrap-around
					If $lastitemfound<>$prevlastitem Then	_GUICtrlTreeView_SelectItem($hTreeView,$lastitemfound)
				EndIf

		EndSelect
	WEnd
	GUIDelete($GUI)

EndFunc


Func _BuildProfile($pass,$dupcounter)

	If $showprogress=True Then SplashTextOn("","Gathering data..." ,200,40,-1,-1,1+32,"Verdana",10)
	$root_selected=(_GUICtrlTreeView_GetText($hTreeView,_GUICtrlTreeView_GetFirstItem($hTreeView))=$itemtext)
	If $root_selected then
		$descrip="Root file selected: " & $itemtext & @CRLF & @CRLF
		$curfile="file"
	Else
		$descrip="Selected branch: " & $itemtext & @CRLF & @CRLF
	EndIf

	$nativeAU3=False

	If $pass=1 Then		; dealing with #include or root file
		If Not $root_selected Then	$curfile="#include file"

		$contains="#include"
		$action="includes"
		$actionpassive="included"
		If Not $root_selected Then
			If FileExists($itemtext) Then		;$itemtext contains full path
				$descrip&="This "&$curfile&" exists in the designated path." & @CRLF
			Else
				$descrip&="This "&$curfile&" is NOT FOUND in the designated path." & @CRLF
			EndIf

			If _ArraySearch($includesRedundant,$itemtext,1)>0 Then		;$itemtext contains full path
				$descrip&="This "&$curfile&" is REDUNDANT in the current build." & @CRLF
			Else
				$descrip&="This "&$curfile&" is required in the current build." & @CRLF
			EndIf
		EndIf

		If _ArraySearch($includeonce,$itemtext,1)>0 Then		;$itemtext contains full path
			$descrip&="This "&$curfile&" contains compiler directive: #include-once" & @CRLF
		Else
			$descrip&="This "&$curfile&" does not contain compiler directive: #include-once" & @CRLF
		EndIf

		$descrip&=@CRLF & "Number of occurrences in Treeview: " & $dupcounter & @CRLF

		$index=_ArraySearch($include_stats,$itemtext,0,0,0,0,1,1)
		If $index>0 Then
			$descrip&="Number of lines: " & $include_stats[$index][2] & @CRLF
			$descrip&="Number of #includes: " & $include_stats[$index][3] & @CRLF
			$descrip&="Number of defined Globals: " & $include_stats[$index][7] & @CRLF
			$descrip&="Number of func definitions: " & $include_stats[$index][4] & @CRLF
			$descrip&="Number of incoming function calls: " & $include_stats[$index][5] & @CRLF
			$descrip&="Number of outgoing function calls: " & $include_stats[$index][6] & @CRLF
			$descrip&="Number of main code sections: " & $include_stats[$index][9] & @CRLF
		EndIf

	ElseIf $pass=2 Then		; dealing with function

		If Not $root_selected Then	$curfile="function"
		$contains="function"
		$action="calls"
		$actionpassive="called"

		$index= -1
		If _ArraySearch($AU3Functions,$itemtext,1)>0 Then
			$descrip&="This is a NATIVE AutoIt function; consult the Autoit documentation for details." & @CRLF& @CRLF
			$nativeAU3=true
		Else
			For $rc=1 To $refindex[0][0]
				If StringInStr($refindex[$rc][0],$itemtext) Then
					$index=$rc
					ExitLoop
				EndIf
			next
		EndIf

		If Not $root_selected Then
			If _ArraySearch($dupes,$itemtext,1)>0 Then
				$descrip&="This function is NON-UNIQUE; multiple definitions are included:" & @CRLF
				For $rc=1 To $problems[0][0]
					If $problems[$rc][3]="func def" And $problems[$rc][4]=$itemtext Then _
						$descrip&= "source file: " & $problems[$rc][1] & " line: " & $problems[$rc][2] &  _
							";" & @CRLF & "parameters: " & $problems[$rc][5] & @CRLF & @CRLF
				Next
			ElseIf _ArraySearch($unknownUDFs,$itemtext)>0 Then
				$descrip&="This UDF is UNDEFINED in the current build." & @CRLF
			Else
				If Not $nativeAU3 Then $descrip&="This UDF is uniquely defined in the current build." & @CRLF
				If $index>0 Then
					$descrip&="It is defined in: " & StringLeft($refindex[$index][0],StringInStr($refindex[$index][0]," UDF:")-1) & _
						"," & @CRLF & @TAB & "lines: " & $refindex[$index][3] & " to " & $refindex[$index][4] & " inclusive." & @CRLF & @CRLF
					$descrip&="Expected parameters: (" & $references[$refindex[$index][1]][5] &")" & @CRLF & @CRLF
					$descrip&="Number of incoming function calls: " & $refindex[$index][5] & @CRLF
					$descrip&="Number of outgoing function calls: " & $refindex[$index][6] & @CRLF
				EndIf
			EndIf

			$descrip&="Number of occurrences in Treeview: " & $dupcounter & @CRLF & @CRLF

			$list=_ArrayFindAll($references,$itemtext,1,0,0,0,4)
			If Not @error And IsArray($list) Then
				$descrip&="The selected function is called in the following source file(s):" & @CRLF
				For $rc = 0 To UBound($list)-1
					If $references[$rc][3]<>"func def" And $references[$rc][3]<>"func end" Then
						$descrip&=@TAB & $references[$list[$rc]][1]& ", line: " & $references[$list[$rc]][2] & @CRLF
					EndIf
				Next
			EndIf
		EndIf
	EndIf

	Local $calling[1],$called[1]
	For $rc=1 To $tree[0]
		$curbranch=StringSplit($tree[$rc],"|")
		If IsArray($curbranch) Then
			If StringInStr($curbranch[$curbranch[0]],$itemtext) And $curbranch[0]>1 Then _ArrayAdd($calling,StringStripWS($curbranch[$curbranch[0]-1],3),0,Chr(0))
			If StringInStr($curbranch[$curbranch[0]-1],$itemtext) Then _ArrayAdd($called,StringStripWS($curbranch[$curbranch[0]],3),0,Chr(0))
		EndIf
	Next

	; remove duplicates
	For $rc=1 To UBound($calling)-1
		$pos=StringInStr($calling[$rc],$tagmarker)
		If $pos>0 Then $calling[$rc]=StringLeft($calling[$rc],$pos-1)
	Next
	For $rc=1 To UBound($called)-1
		$pos=StringInStr($called[$rc],$tagmarker)
		If $pos>0 Then $called[$rc]=StringLeft($called[$rc],$pos-1)
	Next
	If UBound($calling)>1 Then _ArrayUniqueFast($calling,1,UBound($calling)-1)
	If UBound($called)>1 Then _ArrayUniqueFast($called,1,UBound($called)-1)
	$calling[0]=UBound($calling)-1
	$called[0]=UBound($called)-1

	If $calling[0]>0  And Not $root_selected Then
		$descrip&= @CRLF & "The selected "&$curfile&" is "&$actionpassive&" by the following "&$curfile&"(s):" & @CRLF
		For $rc=1 To $calling[0]
			If Not StringInStr($calling[$rc],$tagmarker) Then $descrip&=@TAB & $calling[$rc] & @CRLF
		Next
	Else
		$descrip&= @CRLF & "The selected "&$curfile&" is not "&$actionpassive&" in other "&$curfile&"s." & @CRLF
	EndIf

	If $nativeAU3=False Then
		If $called[0]>0 Then
			$descrip&= @CRLF & "The selected "&$curfile&" itself "&$action&" the following "&$contains&"(s):" & @CRLF
			For $rc=1 To $called[0]
				If Not StringInStr($called[$rc],$tagmarker) Then $descrip&=@TAB & $called[$rc] & @CRLF
			Next
		Else
			$descrip&= @CRLF & "The selected "&$curfile&" "&$action&" no other "&$curfile&"s." & @CRLF
		EndIf
	EndIf

	Local $list[2]
	If Not $root_selected Then
		$descrip&=@CRLF & "Nesting sequence:" & @CRLF
		$hItem=_GUICtrlTreeView_GetSelection($hTreeView)
		$list[1]=_GUICtrlTreeView_GetText($hTreeView,$hItem)
		If StringInStr($list[1],$tagmarker) Then $list[1]=StringLeft($list[1],StringInStr($list[1],$tagmarker)-1)
		While $hItem <> _GUICtrlTreeView_GetFirstItem($hTreeView)
			$hItem=_GUICtrlTreeView_GetParentHandle($hTreeView,$hItem)
			If $hItem=0 Then ExitLoop
			_ArrayAdd($list,_GUICtrlTreeView_GetText($hTreeView,$hItem),0,Chr(0))
		WEnd
		$descrip&="Root: " & @TAB & _GUICtrlTreeView_GetText($hTreeView,$hItem) & ":" & @CRLF
		For $rc=UBound($list)-2 To 1 Step -1
			$descrip&="  ==>" & @TAB & $list[$rc] & @CRLF
		Next
	EndIf

	SplashOff()
	Return $descrip

EndFunc

; blatantly copied from treeview Helptext example code
; event tracking is left in for possible future/user adaptation
Func WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $iwParam
	Local $hWndFrom, $iIDFrom, $iCode, $tNMHDR, $hWndTreeview
	$hWndTreeview = $hTreeView
	If Not IsHWnd($hTreeView) Then $hWndTreeview = GUICtrlGetHandle($hTreeView)

	$tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	$hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
	$iIDFrom = DllStructGetData($tNMHDR, "IDFrom")
	$iCode = DllStructGetData($tNMHDR, "Code")
	Switch $hWndFrom
		Case $hWndTreeview
			Switch $iCode		; left all these options in in case of adding functionality later
				Case $NM_CLICK ; The user has clicked the left mouse button within the control
					_DebugPrint("$NM_CLICK" & @LF & "--> hWndFrom: " & @TAB & $hWndFrom & @LF & _
							"-->IDFrom: " & @TAB & $iIDFrom & @LF & _
							"-->Code: " & @TAB & $iCode)
;~ 					Return 1 ; nonzero to not allow the default processing
					Return 0 ; zero to allow the default processing
				Case $NM_DBLCLK ; The user has double-clicked the left mouse button within the control
					_DebugPrint("$NM_DBLCLK" & @LF & "--> hWndFrom: " & @TAB & $hWndFrom & @LF & _
							"-->IDFrom: " & @TAB & $iIDFrom & @LF & _
							"-->Code :" & @TAB & $iCode)
;~ 					Return 1 ; nonzero to not allow the default processing
					Return 0 ; zero to allow the default processing
				Case $NM_RCLICK ; The user has clicked the right mouse button within the control
					_DebugPrint("$NM_RCLICK" & @LF & "--> hWndFrom: " & @TAB & $hWndFrom & @LF & _
							"-->IDFrom: " & @TAB & $iIDFrom & @LF & _
							"-->Code: " & @TAB & $iCode)
;~ 					Return 1 ; nonzero to not allow the default processing
					Return 0 ; zero to allow the default processing
				Case $NM_RDBLCLK ; The user has clicked the right mouse button within the control
					_DebugPrint("$NM_RDBLCLK" & @LF & "--> hWndFrom: " & @TAB & $hWndFrom & @LF & _
							"-->IDFrom: " & @TAB & $iIDFrom & @LF & _
							"-->Code: " & @TAB & $iCode)
;~ 					Return 1 ; nonzero to not allow the default processing
					Return 0 ; zero to allow the default processing
				Case $NM_KILLFOCUS ; control has lost the input focus
					_DebugPrint("$NM_KILLFOCUS" & @LF & "--> hWndFrom: " & @TAB & $hWndFrom & @LF & _
							"-->IDFrom: " & @TAB & $iIDFrom & @LF & _
							"-->Code: " & @TAB & $iCode)
					; No return value
				Case $NM_RETURN ; control has the input focus and that the user has pressed the key
					_DebugPrint("$NM_RETURN" & @LF & "--> hWndFrom: " & @TAB & $hWndFrom & @LF & _
							"-->IDFrom: " & @TAB & $iIDFrom & @LF & _
							"-->Code: " & @TAB & $iCode)
;~ 					Return 1 ; nonzero to not allow the default processing
					Return 0 ; zero to allow the default processing
				Case $NM_SETFOCUS ; control has received the input focus
					_DebugPrint("$NM_SETFOCUS" & @LF & "--> hWndFrom: " & @TAB & $hWndFrom & @LF & _
							"-->IDFrom: " & @TAB & $iIDFrom & @LF & _
							"-->Code: " & @TAB & $iCode)
					; No return value
				Case $TVN_BEGINDRAGA, $TVN_BEGINDRAGW
					_DebugPrint("$TVN_BEGINDRAG")
				Case $TVN_BEGINLABELEDITA, $TVN_BEGINLABELEDITW
					_DebugPrint("$TVN_BEGINLABELEDIT")
				Case $TVN_BEGINRDRAGA, $TVN_BEGINRDRAGW
					_DebugPrint("$TVN_BEGINRDRAG")
				Case $TVN_DELETEITEMA, $TVN_DELETEITEMW
					_DebugPrint("$TVN_DELETEITEM")
				Case $TVN_ENDLABELEDITA, $TVN_ENDLABELEDITW
					_DebugPrint("$TVN_ENDLABELEDIT")
				Case $TVN_GETDISPINFOA, $TVN_GETDISPINFOW
					_DebugPrint("$TVN_GETDISPINFO")
				Case $TVN_GETINFOTIPA, $TVN_GETINFOTIPW
					_DebugPrint("$TVN_GETINFOTIP")
				Case $TVN_ITEMEXPANDEDA, $TVN_ITEMEXPANDEDW
					_DebugPrint("$TVN_ITEMEXPANDED")
				Case $TVN_ITEMEXPANDINGA, $TVN_ITEMEXPANDINGW
					_DebugPrint("$TVN_ITEMEXPANDING")
				Case $TVN_KEYDOWN
					_DebugPrint("$TVN_KEYDOWN")
				Case $TVN_SELCHANGEDA, $TVN_SELCHANGEDW
					$itemtext=_GUICtrlTreeView_GetText($hTreeView, _GUICtrlTreeView_GetSelection($hTreeView))
					$selection_changed=True
				Case $TVN_SELCHANGINGA, $TVN_SELCHANGINGW
					_DebugPrint("$TVN_SELCHANGING")
				Case $TVN_SETDISPINFOA, $TVN_SETDISPINFOW
					_DebugPrint("$TVN_SETDISPINFO")
				Case $TVN_SINGLEEXPAND
					_DebugPrint("$TVN_SINGLEEXPAND")
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_NOTIFY


Func _DebugPrint($s_text, $line = @ScriptLineNumber)
	If $diagnostics=True Then ConsoleWrite("-->Line(" & StringFormat("%04d", $line) & "): " & @TAB & $s_text & @LF )
EndFunc   ;==>_DebugPrint


Func _IOError($errormsg="unknown error")
	SplashOff()
	ProgressOff()
	If $runquiet=False Then MsgBox(262144+8192+16,"Code Scanner","Fatal I/O error: " & $errormsg)
	Exit (-10)
EndFunc


Func _ProgressBusy($title="",$maintext="",$subtext="",$xpos=-1,$ypos=-1)
	Global $PBGUI = GUICreate($title, 300, 120, $xpos,$ypos,BitOR($WS_DLGFRAME,$DS_SETFOREGROUND))
	Global $PBmaintexthandle=GUICtrlCreateLabel($maintext,20, 5, 260, 20)
	Global $PBsubtexthandle=GUICtrlCreateLabel($subtext,20, 55, 260, 20)
	GUICtrlSetFont($PBmaintexthandle,10,600)
	GUICtrlCreateProgress(20, 30, 260, 20, $PBS_MARQUEE)
	_SendMessage(GUICtrlGetHandle(-1), $PBM_SETMARQUEE, True, 30)
	GUISetState()
	Return $PBGUI
EndFunc


Func _Settings()

	$Settings = GUICreate("CodeScanner Settings", 340, 460)

	$CBwidth=17
	$CBheight=25
	$labelheight=17
	$labelmargin=7
	$groupwidth=320
	$groupheight=110

	$groupleft=10
	$grouptop=10
	$groupCBleft=$groupleft+20
	$grouplabeleft=$groupleft+40
	$groupCBspacing=25

	GUICtrlCreateGroup("Processing", $groupleft, $grouptop, $groupwidth, $groupheight)

	$tooltip="Use slower FileReadLine I/O that supports UTF16 source files"
	$Checkbox_US = GUICtrlCreateCheckbox("Checkbox_US", $groupCBleft, $grouptop+$groupCBspacing, $CBwidth, $CBheight)
	If $UnicodeSupport=True Then
		GUICtrlSetstate(-1,$GUI_CHECKED)
	Else
		GUICtrlSetstate(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label1a = GUICtrlCreateLabel("Unicode Support", $grouplabeleft, $labelmargin+$grouptop+$groupCBspacing, 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Do not skip native AutoIt *Constants.au3 files"
	$Checkbox_IC = GUICtrlCreateCheckbox("Checkbox_IC", $groupCBleft, $grouptop+($groupCBspacing*2), $CBwidth, $CBheight)
	If $includeConstants=True Then
		GUICtrlSetstate(-1,$GUI_CHECKED)
	Else
		GUICtrlSetstate(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label1b = GUICtrlCreateLabel("Include Constants", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*2), 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Write meta-code files out to DataDump subdirectory" & @CRLF & "(Note: this adjusts several other required settings)"
	$Checkbox_WMC = GUICtrlCreateCheckbox("Checkbox_WMV", $groupCBleft, $grouptop+($groupCBspacing*3), $CBwidth, $CBheight)
	If $WriteMetaCode=True Then
		GUICtrlSetstate(-1,$GUI_CHECKED)
	Else
		GUICtrlSetstate(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label1c = GUICtrlCreateLabel("Write MetaCode", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*3), 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$groupleft=10
	$grouptop=130
	$groupwidth=320
	$groupheight=110
	$groupCBleft=$groupleft+20
	$grouplabeleft=$groupleft+40
	$groupCBspacing=25

	GUICtrlCreateGroup("Tracking", $groupleft, $grouptop, $groupwidth, $groupheight)

	$tooltip="Store each native AutoIt function call, with parameters" & @CR & "Performance penalty: LARGE"
	$Checkbox_TAU3C = GUICtrlCreateCheckbox("Checkbox_AU3C", $groupCBleft, $grouptop+$groupCBspacing, $CBwidth, $CBheight)
	If $TrackAU3Calls=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label3a = GUICtrlCreateLabel("Track AU3 calls", $grouplabeleft, $labelmargin+$grouptop+$groupCBspacing,100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Store each user-defined function call, with parameters" & @CR & "Performance penalty: LARGE"
	$Checkbox_TUDFC = GUICtrlCreateCheckbox("Checkbox_UDFC", $groupCBleft, $grouptop+($groupCBspacing*2), $CBwidth, $CBheight)
	If $TrackUDFCalls=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label3b = GUICtrlCreateLabel("Track UDF calls", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*2),100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Store all For/Next, While/Wend, and Do/Until constructs" & @CR & "Performance penalty: SMALL"
	$Checkbox_TL = GUICtrlCreateCheckbox("Checkbox_TL", $groupCBleft, $grouptop+($groupCBspacing*3), $CBwidth, $CBheight)
	If $TrackLoops=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label3c = GUICtrlCreateLabel("Track loops", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*3),100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)


	$groupleft=180
	$groupCBleft=$groupleft+20
	$grouplabeleft=$groupleft+40
	$groupCBspacing=25

	$tooltip="Store all variables and enumerate their references" & @CR & "Performance penalty: MODERATE"
	$Checkbox_EV = GUICtrlCreateCheckbox("Checkbox_EV", $groupCBleft, $grouptop+$groupCBspacing, $CBwidth, $CBheight)
	If $ExtractVars=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label3d = GUICtrlCreateLabel("Extract Variables", $grouplabeleft, $labelmargin+$grouptop+$groupCBspacing,100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Store all ""strings"" and enumerate their references" & @CR & "Performance penalty: SMALL"
	$Checkbox_ES = GUICtrlCreateCheckbox("Checkbox_ES", $groupCBleft, $grouptop+($groupCBspacing*2), $CBwidth, $CBheight)
	If $ExtractStrings=True Then
		GUICtrlSetstate(-1,$GUI_CHECKED)
	Else
		GUICtrlSetstate(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label3e = GUICtrlCreateLabel("Extract Strings", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*2), 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Store all macros and enumerate their references" & @CR & "Performance penalty: SMALL"
	$Checkbox_EM = GUICtrlCreateCheckbox("Checkbox_EM", $groupCBleft, $grouptop+($groupCBspacing*3), $CBwidth, $CBheight)
	If $ExtractMacros=True Then
	GUICtrlSetstate(-1,$GUI_CHECKED)
	Else
		GUICtrlSetstate(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label3f = GUICtrlCreateLabel("Extract Macros", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*3), 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$groupleft=10
	$grouptop=250
	$groupCBleft=$groupleft+20
	$grouplabeleft=$groupleft+40
	$groupCBspacing=25

	GUICtrlCreateGroup("Display", $groupleft, $grouptop, $groupwidth, $groupheight)

	$tooltip="Display progress bars and splash texts while processing"
	$Checkbox_SP = GUICtrlCreateCheckbox("Checkbox_SP", $groupCBleft, $grouptop+$groupCBspacing, $CBwidth, $CBheight)
	If $showprogress=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label2a = GUICtrlCreateLabel("Show Progress", $grouplabeleft, $labelmargin+$grouptop+$groupCBspacing, 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Display duplicate branch stubs in TreeViews"
	$Checkbox_SFD = GUICtrlCreateCheckbox("Checkbox_SFD", $groupCBleft, $grouptop+($groupCBspacing*2), $CBwidth, $CBheight)
	If $showfirstduplication=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label2b = GUICtrlCreateLabel("Show duplicates", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*2),100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Display native AutoIt functions in TreeViews"
	$Checkbox_SAU3 = GUICtrlCreateCheckbox("Checkbox_SAU3", $groupCBleft, $grouptop+($groupCBspacing*3), $CBwidth, $CBheight)
	If $showAU3native=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label2c = GUICtrlCreateLabel("Show AU3 functions", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*3),100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$groupleft=180
	$groupCBleft=$groupleft+20
	$grouplabeleft=$groupleft+40
	$groupCBspacing=25

	$tooltip="Expand ""Results by Subject"" display options in Main Menu"
	$Checkbox_RBS = GUICtrlCreateCheckbox("Checkbox_RBS", $groupCBleft, $grouptop+$groupCBspacing, $CBwidth, $CBheight)
	If $showResultsBySubject=True Then
		GUICtrlSetState(-1,$GUI_CHECKED)
	Else
		GUICtrlSetState(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label2d = GUICtrlCreateLabel("Results by Subject", $grouplabeleft, $labelmargin+$grouptop+$groupCBspacing,100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Expand ""Results by Format"" display options in Main Menu"
	$Checkbox_RBF = GUICtrlCreateCheckbox("Checkbox_RBF", $groupCBleft, $grouptop+($groupCBspacing*2), $CBwidth, $CBheight)
	If $showResultsByFormat=True Then
		GUICtrlSetstate(-1,$GUI_CHECKED)
	Else
		GUICtrlSetstate(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label2e = GUICtrlCreateLabel("Results by Format", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*2), 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$tooltip="Expand MetaCode options in Main Menu"
	$Checkbox_MC = GUICtrlCreateCheckbox("Checkbox_MC", $groupCBleft, $grouptop+($groupCBspacing*3), $CBwidth, $CBheight)
	If $showMetaCode=True Then
		GUICtrlSetstate(-1,$GUI_CHECKED)
	Else
		GUICtrlSetstate(-1,$GUI_UNCHECKED)
	EndIf
	GUICtrlSetTip(-1,$tooltip)
	$Label2f = GUICtrlCreateLabel("MetaCode Options", $grouplabeleft, $labelmargin+$grouptop+($groupCBspacing*3), 100, $labelheight)
	GUICtrlSetTip(-1,$tooltip)

	$Edit1 = GUICtrlCreateEdit("", 12, 370, 320, 40, BitOR($ES_AUTOHSCROLL,$ES_READONLY,$WS_HSCROLL))
	GUICtrlSetData(-1, $AutoItIncludeFolder)
	GUICtrlSetBkColor(-1, 0xFFFFFF)
	GUICtrlSetTip(-1,"AutoIt default Include path, where" & @CR & "<angle-bracketed_include.au3> files are first sought.")

	$buttontop=420

	$Button_Cancel = GUICtrlCreateButton("Return", 10, $buttontop, 85, 28)
	GUICtrlSetTip(-1,"Return to main menu with current settings")
	$Button_Path = GUICtrlCreateButton("Include Path", 126, $buttontop, 85, 28)
	GUICtrlSetTip(-1,"Change AutoIt default Include path")
	$Button_Store = GUICtrlCreateButton("Store", 245, $buttontop, 85, 28)
	GUICtrlSetTip(-1,"Write current settings to INI file and Return")

	GUISetState(@SW_SHOW)

	While 1
		$nMsg = GUIGetMsg()
		Select
			; buttons
			Case $nMsg=$GUI_EVENT_CLOSE Or $nMsg=$Button_Cancel
				Exitloop
			Case $nMsg=$Button_Path
				_GetAutoItIncludeFolder(False)	; false flag = do not check default locations first, go straight to folderselect
				ControlSetText($Settings,"",$Edit1,$AutoItIncludeFolder,1)
			Case $nMsg=$Button_Store
				_WriteIniFile()
				ExitLoop

			; processing checkboxes
			Case $nMsg=$Checkbox_US Or $nMsg=$Label1a
				$UnicodeSupport=Not $UnicodeSupport
				If $UnicodeSupport=True Then
					GUICtrlSetstate($Checkbox_US,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_US,$GUI_UNCHECKED)
				EndIf
			Case $nMsg=$Checkbox_IC Or $nMsg=$Label1b
				$includeConstants=Not $includeConstants
				If $includeConstants=True Then
					GUICtrlSetstate($Checkbox_IC,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_IC,$GUI_UNCHECKED)
				EndIf
				If $includeConstants=False Then
					$WriteMetaCode=False
					GUICtrlSetstate($Checkbox_WMC,$GUI_UNCHECKED)
				EndIf

			Case $nMsg=$Checkbox_WMC Or $nMsg=$Label1c
				$WriteMetaCode=Not $WriteMetaCode
				If $WriteMetaCode=True Then
					GUICtrlSetstate($Checkbox_WMC,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_WMC,$GUI_UNCHECKED)
				EndIf
				If $WriteMetaCode=True Then
					$includeConstants=True	; switching any of these off hereafter
					$trackAU3calls=True		;	will reset $WriteMetaCode again
					$trackUDFcalls=True
					$ExtractVars=True
					$ExtractStrings=True
					$ExtractMacros=True
					$showMetaCode=True
					GUICtrlSetstate($Checkbox_IC,$GUI_CHECKED)
					GUICtrlSetstate($Checkbox_TAU3C,$GUI_CHECKED)
					GUICtrlSetstate($Checkbox_TUDFC,$GUI_CHECKED)
					GUICtrlSetstate($Checkbox_EV,$GUI_CHECKED)
					GUICtrlSetstate($Checkbox_ES,$GUI_CHECKED)
					GUICtrlSetstate($Checkbox_MC,$GUI_CHECKED)
					GUICtrlSetstate($Checkbox_EM,$GUI_CHECKED)
				Else
					$showMetaCode=False
					GUICtrlSetstate($Checkbox_MC,$GUI_UNCHECKED)
				EndIf

			; display checkboxes
			Case $nMsg=$Checkbox_SP Or $nMsg=$Label2a
				$showprogress=Not $showprogress
				If $showprogress=True Then
					GUICtrlSetState($Checkbox_SP,$GUI_CHECKED)
				Else
					GUICtrlSetState($Checkbox_SP,$GUI_UNCHECKED)
				EndIf
			Case $nMsg=$Checkbox_SFD Or $nMsg=$Label2b
				$showfirstduplication=Not $showfirstduplication
				If $showfirstduplication=True Then
					GUICtrlSetState($Checkbox_SFD,$GUI_CHECKED)
				Else
					GUICtrlSetState($Checkbox_SFD,$GUI_UNCHECKED)
				EndIf
			Case $nMsg=$Checkbox_SAU3 Or $nMsg=$Label2c
				$ShowAU3native=Not $ShowAU3native
				If $ShowAU3native=True Then
					GUICtrlSetState($Checkbox_SAU3,$GUI_CHECKED)
				Else
					GUICtrlSetState($Checkbox_SAU3,$GUI_UNCHECKED)
				EndIf

			Case $nMsg=$Checkbox_RBS Or $nMsg=$Label2d
				$showResultsBySubject=Not $showResultsBySubject
				If $showResultsBySubject=True Then
					GUICtrlSetState($Checkbox_RBS,$GUI_CHECKED)
				Else
					GUICtrlSetState($Checkbox_RBS,$GUI_UNCHECKED)
				EndIf
			Case $nMsg=$Checkbox_RBF Or $nMsg=$Label2e
				$showResultsByFormat=Not $showResultsByFormat
				If $showResultsByFormat=True Then
					GUICtrlSetState($Checkbox_RBF,$GUI_CHECKED)
				Else
					GUICtrlSetState($Checkbox_RBF,$GUI_UNCHECKED)
				EndIf
			Case $nMsg=$Checkbox_MC Or $nMsg=$Label2f
				$showMetaCode=Not $showMetaCode
				If $showMetaCode=True Then
					GUICtrlSetState($Checkbox_MC,$GUI_CHECKED)
				Else
					GUICtrlSetState($Checkbox_MC,$GUI_UNCHECKED)
				EndIf

			; tracking checkboxes
			Case $nMsg=$Checkbox_TAU3C Or $nMsg=$Label3a
				$TrackAU3Calls=Not $TrackAU3Calls
				If $TrackAU3Calls=True Then
					GUICtrlSetstate($Checkbox_TAU3C,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_TAU3C,$GUI_UNCHECKED)
				EndIf
				If $TrackAU3Calls=False Then
					$WriteMetaCode=False
					GUICtrlSetstate($Checkbox_WMC,$GUI_UNCHECKED)
				EndIf

			Case $nMsg=$Checkbox_TUDFC Or $nMsg=$Label3b
				$TrackUDFCalls=Not $TrackUDFCalls
				If $TrackUDFCalls=True Then
					GUICtrlSetstate($Checkbox_TUDFC,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_TUDFC,$GUI_UNCHECKED)
				EndIf
				If $TrackUDFCalls=False Then
					$WriteMetaCode=False
					GUICtrlSetstate($Checkbox_WMC,$GUI_UNCHECKED)
				EndIf

			Case $nMsg=$Checkbox_TL Or $nMsg=$Label3c
				$TrackLoops=Not $TrackLoops
				If $TrackLoops=True then
					GUICtrlSetstate($Checkbox_TL,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_TL,$GUI_UNCHECKED)
				EndIf

			Case $nMsg=$Checkbox_EV Or $nMsg=$Label3d
				$ExtractVars=Not $ExtractVars
				If $ExtractVars=True Then
					GUICtrlSetstate($Checkbox_EV,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_EV,$GUI_UNCHECKED)
				EndIf
				If $ExtractVars=False Then
					$WriteMetaCode=False
					GUICtrlSetstate($Checkbox_WMC,$GUI_UNCHECKED)
				EndIf

			Case $nMsg=$Checkbox_ES Or $nMsg=$Label3e
				$ExtractStrings=Not $ExtractStrings
				If $ExtractStrings=True Then
					GUICtrlSetstate($Checkbox_ES,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_ES,$GUI_UNCHECKED)
				EndIf
				If $ExtractStrings=False Then
					$WriteMetaCode=False
					GUICtrlSetstate($Checkbox_WMC,$GUI_UNCHECKED)
				EndIf

			Case $nMsg=$Checkbox_EM Or $nMsg=$Label3f
				$ExtractMacros=Not $ExtractMacros
				If $ExtractMacros=True Then
					GUICtrlSetstate($Checkbox_EM,$GUI_CHECKED)
				Else
					GUICtrlSetstate($Checkbox_EM,$GUI_UNCHECKED)
				EndIf

				If $ExtractMacros=False Then
					$WriteMetaCode=False
					GUICtrlSetstate($Checkbox_WMC,$GUI_UNCHECKED)
				EndIf

		EndSelect
	WEnd
	GUIDelete($Settings)
	Global $TrackCalls=($TrackAU3Calls Or $TrackUDFCalls)

	; expand/collapse branches?
	_GUICtrlTreeView_Expand($hTreeViewmenu,$RBShandle,$showResultsBySubject)
	_GUICtrlTreeView_Expand($hTreeViewmenu,$RBFhandle,$showResultsByFormat)
	_GUICtrlTreeView_Expand($hTreeViewmenu,$MChandle,$showMetaCode)

EndFunc

#endregion	GUI-related UDFs

;=============================================================================================================

#region	Code Analysis

Func _AnalyseCode()

	$procname="_AnalyseCode"
	Global $tstart=TimerInit()
	If $uselogfile Then _FileWriteLog($fhlog,$procname & " started...")

	_ProcessIncludes()	; main engine
	_BuildIncTree()		; store #includes hierarchy
	_BuildRefindex()		; store refs[] start+end of each tracked feature
	_TrueFirstEntrypoint(); determine actual start of main code (i.e., excl. definitions and compiler directives)
	_BuildFuncTree()		; store UDFs hierarchy
	_ReportIssues()		; write report, update stats

	If $WriteMetaCode=True Then _WriteCSDataDump(False)	; false = mini dump
	If $uselogfile Then _FileWriteLog($fhlog,$procname & " finished." & @CRLF & @CRLF)

EndFunc


Func _ProcessIncludes()

	$procname="_ProcessIncludes"
	If $showprogress=True Then ProgressOn("Code Scanner: " & $trimmedroot,"Processing source files","Please wait...")

	$WriteMetaCodeFail=False
	If $WriteMetaCode=True And $includeConstants=False Then
		$includeConstants=True
		_WriteIniFile()
	EndIf

	$filecount=0
	While $filecount<$includes[0]
		$filecount+=1
		$fname=StringTrimLeft($includes[$filecount],StringInStr($includes[$filecount],"\",0,-1))
		$trimmedfname=$fname		; default (if it fits)
		If StringLen($fname)>25 Then $trimmedfname=StringLeft($fname,12) & "..." & StringRight($fname,12)
		If $showprogress=True Then ProgressSet(100*($filecount-1)/$includes[0],"Scanning " & $trimmedfname & "...")
		If $uselogfile Then _FileWriteLog($fhlog,$procname & ": scanning " & $includes[$filecount])

		; process file
		$UTC_switch=$UnicodeSupport
		$filedone=_ScanFile($filecount)						; 2nd param identifies pass
		If Not $filedone And $UTC_switch<>$UnicodeSupport Then _ScanFile($filecount)		; UnicodeSupport WAS off, is now on, so try once more

		; does current source file contain main code whose last line is an implicit exitpoint that needs to be included?
		$lastsectionentry=UBound($mainCodeSections)-1
		If $filecount=$mainCodeSections[$lastsectionentry][0] Then		; final exitpoint to add, if implicit
			$lastmainlinenr=$mainCodeSections[$lastsectionentry][3]	; last line of last section
			If _ArraySearch($Exitpoints,$lastmainlinenr,1,0,0,0,1,2)<1 Then	; add only if not already stored as explicit exitpoint
				_AddMCS2Exitpoints($lastsectionentry)	; add entry to both $Exitpoints and $references
			EndIf
		EndIf
	WEnd

	If $showprogress=True Then	ProgressOn("Code Scanner: " & $trimmedroot,"Post-Processing Include files","Please wait...")
	If $uselogfile Then _FileWriteLog($fhlog,$procname & " post-processing included files...")

	; update array specs
	$mainCodeSections[0][0]=UBound($mainCodeSections)-1
	$Exitpoints[0][0]=UBound($Exitpoints)-1
	$include_lines[0]=$includes[0]

	If $ExtractStrings=True Then
		$stringsUsed[0]=UBound($stringsUsed)-1		; do NOT sort these; {string###}: ### = array index
		$stringsUsedSorted=$stringsUsed
		$stringsUsedsorted[0]=""
		_ArraySort($stringsUsedSorted)
		$stringsUsedsorted[0]=$stringsUsed[0]
	EndIf

	If $ExtractVars=True Then
		$variablesUsed[0]=UBound($variablesUsed)-1		; do NOT sort these; {var###}: ### = array index

		$variablesUsedSorted=$variablesUsed
		$variablesUsedsorted[0]=""
		_ArraySort($variablesUsedSorted)
		$variablesUsedsorted[0]=$variablesUsed[0]

		$variableIsArray[0]=""
		_ArraySort($variableIsArray)
		$variableIsArray[0]=UBound($variableIsArray)-1
	EndIf

	$macrosUsed[0]=""
	_ArraySort($macrosUsed)
	$macrosUsed[0]=UBound($macrosUsed)-1

	$globals[0]=""
	_ArraySort($globals)
	$globals[0]=UBound($globals)-1

	If $diagnostics=True Then ConsoleWrite(@CRLF & $includes[0] & " file(s) processed." & @CRLF)
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": " & $includes[0] & " file(s) processed.")

	; build list of #include pairs (parent | child) and mark duplicate UDF defs
	Global $parent[1],$child[1]
	Local $loopstartref[1],$loopnesting[1]
	Global $loopmismatch=0,$loop_ID=0

	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": evaluating references...")
	For $rc=1 To $references[0][0]

		If $showprogress=True And Mod($rc,100)=0 Then ProgressSet(100*($rc-1)/$references[0][0],"Evaluating references...")

		; build foundation arrays for includes tree
		If $references[$rc][3]="#include" And $references[$rc][0]=True Then
			_ArrayAdd($parent,$references[$rc][1],0,Chr(0))
			_ArrayAdd($child,$references[$rc][4],0,Chr(0))
		EndIf

		; store (nested) loops
		If $TrackLoops=True Then
			If StringLeft($references[$rc][3],5)="Loop " Then
				If StringMid($references[$rc][3],6,5)="Start" Then
					$loop_ID+=1
					_ArrayAdd($loopnesting,$loop_ID,0,Chr(0))
					_ArrayAdd($loopstartref,$rc,0,Chr(0))
					_Add2Loops($loopnesting,$rc,$loop_ID)				; write new nesting level

				ElseIf StringMid($references[$rc][3],6,3)="End" Then
					$looptrouble=False
					$startref=_arraypop($loopstartref)
					$curID=_ArrayPop($loopnesting)				; decrement nesting
					If $curID="" Then
						$curID="???"
						$looptrouble=True	; ID not found
					EndIf

					_Add2Loops($loopnesting,$rc,$curID)		; write popped nesting level
					$lastloop=UBound($loops)-1

					If $looptrouble=False Then		; ID is valid, so must occur earlier
						$IDtag="#" & $curID & " "	; trailing space required

						Switch $loops[$lastloop][4]
							Case "Next"
								$loopstart="For"
							Case "WEnd"
								$loopstart="While"
							Case "Until"
								$loopstart="Do"
						EndSwitch

						; track down the prior associated Loop Start
						For $cc=$lastloop-1 To 1 Step -1
							If StringInStr($loops[$cc][3],$IDtag) Then
								If $loops[$cc][4]<>$loopstart Then	; right ID, wrong pair
									$loops[$cc][0]=False
									$looptrouble=True
									If $references[$startref][0]=True Then _
										_Add2Problems($startref,$references[$startref][3],$references[$startref][4])
									ExitLoop
								EndIf
							EndIf
						Next
					EndIf

					If $looptrouble=True Then	; invalid ID, wrong pairing
						$loopmismatch+=1
						$loops[$lastloop][0]=False
						_Add2Problems($rc,$references[$rc][3],$references[$rc][4])
					EndIf
				Endif
			Endif
		EndIf		; Loop tracking

		If $references[$rc][0]=False Then

			; UDF defs can be flagged false for two reasons: duplication and being unresolved
			; duplicates
			If $references[$rc][3]="func def" And $references[$rc][5]<>$paramsunresolvedtag Then
				$curfunc=$references[$rc][4]
				$func_duplicated+=1
				If $diagnostics=True Then ConsoleWrite("looking for duplicates of: " & $curfunc & @CR)

				For $cc=1 To $rc-1	; rescan prior defs only
					If $references[$cc][4]=$curfunc Then	; rarest condition first
						If  $references[$cc][3]="func def" Then
							If $references[$cc][0]=True Then $func_duplicated+=1	; only if not already marked
							_Add2Problems($cc,"func def",$curfunc)

							If $diagnostics=True Then ConsoleWrite(@TAB & "found duplicate in: " & $references[$cc][1] & ", line: " & $references[$cc][2]&@CR)
						Endif
					EndIf
				Next
			EndIf

			; resolving unknown UDF calls (happens when call precedes definition)
			If $references[$rc][3]=$func_unknown_tag Then
				$curfunc=$references[$rc][4]
				$funcdef_ID=_ArraySearch($functionsDefined,$curfunc,1)	; separate index used to standardise output
				If $funcdef_ID>0 Then
					$curfunc=$functionsDefined[$funcdef_ID]	; standardise capitalisation
					$references[$rc][0]=True
					$references[$rc][3]="UDF call"
					$references[$rc][4]=$curfunc	; standardise capitalisation
					_AddFunCall($curfunc,False)	; add to $functionsCalled

					$index=_ArraySearch($unknownUDFs,$curfunc)
					If $index>0 Then _ArrayDelete($unknownUDFs,$index)
				Else		; add to the list of undefined UDFs if truly absent
					If _ArraySearch($unknownUDFs,$curfunc,1)<1 Then _ArrayAdd($unknownUDFs,$curfunc,0,Chr(0))
					_Add2Problems($rc,$func_unknown_tag,$curfunc)
				EndIf
			EndIf

		EndIf
	Next

	If $showprogress=True Then
		ProgressSet(100, "Done", "Complete")
		Sleep(500)
	EndIf

	If $TrackLoops=True Then
		$lastloop=UBound($loops)-1
		$loops[0][0]=$lastloop
		$loopsleft=UBound($loopnesting)-1
		If $loopsleft>0 Then
			$loopmismatch+=$loopsleft
			For $rc=1 To $loopsleft
				$IDtag="#" & $loopnesting[$rc] & " "
				For $cc=$lastloop-1 To 1 Step -1	; backward scan is likely faster than forward
					If StringInStr($loops[$cc][3],$IDtag) Then
						$loops[$cc][0]=False
						ExitLoop
					EndIf
				Next
				$pc=$loopstartref[$rc]
				_Add2Problems($pc,$references[$pc][3],$references[$pc][4])
			Next
		EndIf
	EndIf

	$pairs=UBound($parent)-1
	$parent[0]=$pairs
	$child[0]=$pairs
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": references evaluated.")

	$includeonce[0]=""
	_ArraySort($includeonce)
	$includeonce[0]=UBound($includeonce)-1

	$functionsDefined[0]=UBound($functionsDefined)-1	; keep unsorted

	$unknownUDFs[0]=""
	_ArraySort($unknownUDFs)
	$unknownUDFs[0]=UBound($unknownUDFs)-1
	If $unknownUDFs[0]=1 And $unknownUDFs[1]="" Then
		_ArrayDelete($unknownUDFs,1)
		$unknownUDFs[0]=0
	EndIf

	$AU3FunctionsUsed[0]=""
	_ArraySort($AU3FunctionsUsed)
	$AU3FunctionsUsed[0]=UBound($AU3FunctionsUsed)-1
	$FunctionsUsed[0]=UBound($FunctionsUsed)-1		; sequential, UDFs found
	$FunctionsCalled[0]=UBound($FunctionsCalled)-1	; sequential, active UDFs

	If $showprogress=True Then ProgressOff()

EndFunc


Func _Add2Problems($rc,$param3,$param4)

	$references[$rc][0]=False	; set error flag
	$refcount=$problems[0][0]+1
	; avoid listing the same line more than once
	For $pc=1 To $refcount-1
		If $problems[$pc][1]=$references[$rc][1] And _
			$problems[$pc][2]=$references[$rc][2] And _
			$problems[$pc][3]=$param3 And _
			$problems[$pc][4]=$param4 And _
			$problems[$pc][5]=$references[$rc][5] Then Return
	Next

	ReDim $problems[$refcount+1][6]
	$problems[$refcount][0]=False
	$problems[$refcount][1]=$references[$rc][1]
	$problems[$refcount][2]=$references[$rc][2]
	$problems[$refcount][3]=$param3
	$problems[$refcount][4]=$param4
	$problems[$refcount][5]=$references[$rc][5]
	$problems[0][0]=$refcount
EndFunc


Func _Add2Loops(ByRef $loopnesting,$rc,$ID)
	$refcount=$loops[0][0]+1
	ReDim $loops[$refcount+1][6]
	$loops[$refcount][0]=$references[$rc][0]
	$loops[$refcount][1]=$references[$rc][1]
	$loops[$refcount][2]=$references[$rc][2]
	$loops[$refcount][3]=$references[$rc][3] & " #" & $ID & " "	; trailing space required to avoid: partial overlap = full match
	$loops[$refcount][4]=$references[$rc][4]
	$loops[$refcount][5]=$references[$rc][5]
	$loops[0][0]=$refcount
EndFunc



Func _Add2Exitpoints($rc)	; straight copy from $references[][]
	$refcount=$Exitpoints[0][0]+1
	ReDim $Exitpoints[$refcount+1][6]
	$Exitpoints[$refcount][0]=True
	$Exitpoints[$refcount][1]=$references[$rc][1]
	$Exitpoints[$refcount][2]=$references[$rc][2]
	$Exitpoints[$refcount][3]=$references[$rc][3]
	$Exitpoints[$refcount][4]=$references[$rc][4]
	$Exitpoints[$refcount][5]=$references[$rc][5]
	$Exitpoints[0][0]=$refcount
EndFunc


Func _AddMCS2Exitpoints($rc)	; straight copy from $MainCodeSections[][]

	$curfile=$mainCodeSections[$rc][1]
	$linecount=$mainCodeSections[$rc][3]
	$params=$mainCodeSections[$rc][4]

	$refcount=$Exitpoints[0][0]+1
	ReDim $Exitpoints[$refcount+1][6]
	$Exitpoints[$refcount][0]=($curfile=$includes[1]) ; marked as False if implicit Exit is not in root file
	$Exitpoints[$refcount][1]=$curfile
	$Exitpoints[$refcount][2]=$linecount
	$Exitpoints[$refcount][3]="Exit"
	$Exitpoints[$refcount][4]=$lastmainlinetag
	$Exitpoints[$refcount][5]=$lastmainline
	$Exitpoints[0][0]=$refcount

	_AddRef(True,$curfile,$linecount,"Exit",$lastmainlinetag,$params)

EndFunc


Func _ScanFile($fileIndex)			; the heart of the machine

	If $fileIndex>$includes[0] Then Return

	$curfile=$includes[$fileIndex]
	$fsize=FileGetSize($curfile)	; also returns 0 if file does not exist
	If $fsize=0 Then
		_ArrayAdd($include_lines,0,0,Chr(0))
		Return
	EndIf

	; screen update progress
	If $diagnostics=True Then ConsoleWrite("Scanning file: " & $curfile & " (" & $fsize & " bytes)" & @CRLF)

	If $UnicodeSupport=False Then
		$buffer = DllStructCreate('byte[' & $fsize+2 & ']')
		$basepointer=DllStructGetPtr($buffer)
		$tail = DllStructCreate("byte[2]", $basepointer+$fsize)
		DllStructSetData($tail,1,@CRLF)	; ensure last line is terminated with expected marker

		$bytesread=0
		$hFile=_WinAPI_CreateFile($curfile, 2, 2)
		If $hFile=0 Then _IOError("unable to open " & $curfile & " for reading")
		If _WinAPI_ReadFile($hFile, $basepointer, $fsize, $bytesread)=False Then _IOError("read error in " & $curfile)
		_WinAPI_CloseHandle($hFile)
		If $bytesread<$fsize Then _IOError("read error in " & $curfile & @CR & "File size: " & $fsize & @CR & "Bytes read: " & $bytesread)
		$fsize+=2	; adjust for suffix 0D0A in struct (so last line with content is always processed)
	Else
		$fh=FileOpen($curfile)
		If @error Or $fh=-1 Then
			If $runquiet=False Then MsgBox(262144+8192+16,"Fatal Error","unable to access file " & $curfile)
			Exit (-12)
		EndIf
	EndIf

	If $WriteMetaCode=True Then
		$metafile=$CS_dumppath & "MCF" & $fileIndex & ".txt"
		$MChandle=FileOpen($metafile,2+8)	; create dir + file if absent, erase any previous contents
		If $MChandle=-1 Then
			$WriteMetaCode=False
			$WriteMetaCodeFail=True
		EndIf
	EndIf

	$funcdef_ID=0
	$newglobals=0
	$commentedout_with_cs=0
	$truelinecount=0
	$addlines=0
	$lseek=0
	$cumuline=""
	$cumulinewithstrings=""
	$recordedstring=""
	$insideUDFdef=False
	$prevmaincode=False
	$firstmainline="<undefined>"
	$lastmainline="<undefined>"
	Global $filelinetag="; {file:" & $fileindex & "}{line:"

	; read in lines of text until EOF
	While $lseek<$fsize

		If $UnicodeSupport=False Then		; ASCII processing
			$line = _GetnextlineASCII($basepointer,$lseek,$fsize,$fileIndex)	; increments $truelinecount
		Else										; Unicode processing
			$line = _GetnextlineUTF($fh,$fileIndex,$fsize,$lseek)		; increments $truelinecount
		EndIf
		If @error Then ExitLoop

		If Mod($truelinecount,200)=0 Then
			If $diagnostics=True Then ConsoleWrite("Lines read: " & $truelinecount &"..." & @CRLF)
			ProgressSet(Floor(100*($fileIndex-1)/$includes[0]),"Scanning " & $trimmedfname & " ("& Floor(100*$lseek/$fsize) & "% done)...")
		EndIf

		; skip special lines completely
		If $line="" Or StringLeft($line,1)=";" Then ContinueLoop
		If StringLeft($line,7)="#Region" Or StringLeft($line,10)="#EndRegion" Then ContinueLoop

		; used to retain original strings for _AddInclude()
		$linewithstrings=$line

		; remove all text strings before checking for #cs/#ce and tracking tags
		$line=""
		$quotationmarks=False
		$apostrophes=False

		If $ExtractStrings=True And $commentedout_with_cs=0 Then
			$recordstring=False
			$recordedstring=""
			For $rc=1 To StringLen($linewithstrings)
				$curchar=Asc(StringMid($linewithstrings,$rc,1))
				Switch $curchar
					Case 34 ;'"'	quotation mark
						If $apostrophes=False Then $quotationmarks = Not $quotationmarks

						If $quotationmarks=True And $recordedstring="" Then
							$line &= "{string"
							$recordstring=True
						EndIf
						$recordedstring &= Chr($curchar)
						ContinueLoop

					Case 39	;"'"	apostrophe
						If $quotationmarks=False Then $apostrophes = Not $apostrophes

						If $apostrophes=True  And $recordedstring="" Then
							$line &= "{string"
							$recordstring=True
						EndIf
						$recordedstring &= Chr($curchar)
						ContinueLoop

					Case Else
						If $quotationmarks=False And $apostrophes=False Then
							If $recordstring=True Then
								$recordstring=False
								$stringcounter+=1
								_ArrayAdd($stringsUsed,$recordedstring,0,Chr(0))
								$recordedstring=""
								$line &= $stringcounter & "}"
							EndIf
							if $curchar=59 Then ExitLoop	; ";"		early-out (rest is comments)
							$line &= Chr($curchar)
						Else
							$recordedstring &= Chr($curchar)	; keep string-recording
						EndIf
				EndSwitch
			Next

			If $recordstring=True Then	; last string
				$stringcounter+=1
				_ArrayAdd($stringsUsed,$recordedstring,0,Chr(0))
				$line &= $stringcounter & "}"
			EndIf

		Else		; $ExtractStrings=false

			For $rc=1 To StringLen($linewithstrings)
				$curchar=Asc(StringMid($linewithstrings,$rc,1))
				Switch $curchar
					Case 34 ;'"'
						If $apostrophes=False Then $quotationmarks = Not $quotationmarks
						If $quotationmarks=True Then $line &= "{string}"
						ContinueLoop
					Case 39	;"'"
						If $quotationmarks=False Then $apostrophes = Not $apostrophes
						If $apostrophes=True Then $line &= "{string}"
						ContinueLoop
					Case Else
						If $quotationmarks=False And $apostrophes=False Then
							if $curchar=59 Then	ExitLoop		; ";"		early-out (rest is comments)
							$line &= Chr($curchar)
						EndIf
				EndSwitch
			Next

		EndIf

		; find smallest non-zero position for each marker
		$pos_cs1=Stringinstr($line,"#cs")
		$pos_cs2=Stringinstr($line,"#comments-start")
		$pos_ce1=Stringinstr($line,"#ce")
		$pos_ce2=Stringinstr($line,"#comments-end")

		; comments-marker(s) found
		If $pos_cs1+$pos_ce1+$pos_cs2+$pos_ce2>0 Then
			If $pos_cs1=0 or $pos_cs2=0 Then
				$pos_cs=_Max($pos_cs1,$pos_cs2)
			Else
				$pos_cs=_Min($pos_cs1,$pos_cs2)
			EndIf
			If $pos_ce1=0 or $pos_ce2=0 Then
				$pos_ce=_Max($pos_ce1,$pos_ce2)
			Else
				$pos_ce=_Min($pos_ce1,$pos_ce2)
			EndIf

			; Assumption: #ce occurs once, at start of line
			; NB rest of line should still be ignored (even if stray #ce; SciTE displays this wrong)
			If $pos_ce>0 Then
				$commentedout_with_cs=_Max(0,$commentedout_with_cs-1)	; keep track of nesting level, but skip stray #ce's
				ContinueLoop
			EndIf

			; Assumption: #cs occurs once per line, can start anywhere
			; NB valid code may precede it on same line
			If $pos_cs>0 Then
				$commentedout_with_cs+=1	; keep track of nesting level
				If $commentedout_with_cs>1 Then ContinueLoop	; already in comments before
				$line=StringStripWS(StringLeft($line,$pos_cs-1),2+4)	; there may be valid code preceding #cs on same line
			EndIf
			If StringLen($line)=0 Then ContinueLoop
		Else
			If $commentedout_with_cs>0 Then ContinueLoop
		EndIf			; line contains comments-markers

		; defer processing if multiline
		$pos=StringInStr($line,"_",0,-1)
		$underscore_found=($pos>0 And $pos>StringLen($line)-2)
		$priorcharvalid=False
		If $underscore_found Then $priorcharvalid= $validprefix[Asc(StringMid($line,$pos-1,1))]

		If Not ($underscore_found And $priorcharvalid) Then
			$cumuline&=$line
			$cumulinewithstrings&=$linewithstrings
		Else	; underscore in last or penultimate position, following a valid break-character
			$addlines+=1
			$cumuline&=StringLeft($line,$pos-1)
			$pos=StringInStr($line,"_",0,-1)
			$cumulinewithstrings&=StringLeft($linewithstrings,$pos-1)
			ContinueLoop
		EndIf
		$linestart=$truelinecount-$addlines

		; these tracking tags should be the first word of a line
		; NB case-insensitive scan
		$skipwritemeta=False
		$compilerdirective=(StringLeft($cumuline,1)="#")
		$maincode=Not $compilerdirective	; initial settting, adjusted below
		Select
			Case StringLeft($cumuline,13)="#include-once"
				_AddIncludeOnce($curfile)
				$skipwritemeta=True

			Case StringLeft($cumuline,9)="#include "
				$include_index=_AddInclude($curfile,$linestart,$cumulinewithstrings)	; parse original line WITH strings
				If $include_index>1 Then $cumuline="#include {incl" & $include_index & "}"

			case StringLeft($cumuline,5)="Func "
				$funcdef_ID=_AddFunc($curfile,$linestart,$cumuline)
				$insideUDFdef=True
				$maincode=False		; added for consistency only

			case StringLeft($cumuline,7)="EndFunc"
				_AddEndFunc($curfile,$linestart,$newfunc)	; parses last-defined funcname
				$insideUDFdef=False
				$maincode=False
				$funcdef_ID=0

			Case StringLeft($cumuline,7)="Global "
				$maincode=_AddGlobal($fileindex,$curfile,$linestart,stringtrimleft($cumuline,7))
				$skipwritemeta=True	; handled separately by _AddGlobal()

			Case StringInStr($cumuline,"Exit")
				_AddExit($curfile,$linestart,$cumulinewithstrings,$insideUDFdef)
		EndSelect

		If $TrackLoops=True And $compilerdirective=False Then
			Select
			Case StringLeft($cumuline,3)="For"
				_AddFor($curfile,$linestart,StringTrimLeft($cumuline,4))
			Case StringLeft($cumuline,4)="Next"
				_AddNext($curfile,$linestart)

			Case StringLeft($cumuline,5)="While"
				_AddWhile($curfile,$linestart,stringtrimleft($cumuline,6))
			Case StringLeft($cumuline,4)="WEnd"
				_AddWend($curfile,$linestart)

			Case StringLeft($cumuline,2)="Do"
				_AddDo($curfile,$linestart)
			Case StringLeft($cumuline,5)="Until"
				_AddUntil($curfile,$linestart,stringtrimleft($cumuline,6))
			EndSelect
		EndIf
		If $TrackCalls=True And $compilerdirective=False Then
			If StringInStr($cumuline,"(")>0 And StringLeft($cumuline,5)<>"Func " Then _Scan4Func($curfile,$linestart, $cumuline)
		EndIf

		; extract all variable names
		; NB unlike MCwords() in MCF.au3 (which moves globals from redundant->used),
		;	this routine skips global vars defined in the current source line
		If $ExtractVars=True And $compilerdirective=False Then
			$varlist=StringSplit($cumuline,"$")
			If Not @error Then				; delimiters found
				For $cc=2 To $varlist[0]	; skip anything preceding the first "$"
					$curvar=StringRegExpReplace($varlist[$cc],"[^a-zA-Z0-9_]"," ",1) & " "
					$pos=StringInStr($curvar," ")-1	; always found (added suffix)
					$nextchars=StringMid($varlist[$cc],$pos,2)
					If StringInStr($nextchars,"(") Then ContinueLoop	; skip object-functions with $-prefix

					$curvar="$" & StringLeft($curvar,$pos)
					$index=_ArraySearch($newglobals,$curvar,1)	; exclude vars defined in this very line as globals
					If $index<1 Then	; valid var
						$index=_ArraySearch($variablesUsed,$curvar,1)
						If $index<1 Then
							_ArrayAdd($variablesUsed,$curvar,0,Chr(0))
							$index=UBound($variablesUsed)-1
						EndIf
						$varlist[$cc]="{var" & $index & "}" & StringTrimLeft($varlist[$cc],$pos)
						If StringInStr($nextchars,"[") Then
							If _ArraySearch($variableIsArray,$curvar,1)<1 then	_ArrayAdd($variableIsArray,$curvar,0,Chr(0))
						EndIf
					EndIf
				Next
				$cumuline=_ArrayToString($varlist,"$",1)
				$cumuline=StringReplace($cumuline,"${var","{var")
			EndIf
		EndIf

		; extract all macros
		If $ExtractMacros=True And $compilerdirective=False Then
			$macroslist=StringSplit($cumuline,"@")
			If Not @error Then				; delimiters found
				For $cc=2 To $macroslist[0]	; skip anything preceding the first "@"
					$curmacro=StringRegExpReplace($macroslist[$cc],"[^a-zA-Z0-9_]"," ",1) & " "
					$curmacro="@" & StringLeft($curmacro,StringInStr($curmacro," ")-1)
					$index=_ArraySearch($macros,$curmacro,1)
					If $index>0 Then
						If _ArraySearch($macrosUsed,$curmacro,1)<1 Then _ArrayAdd($macrosUsed,$curmacro,0,Chr(0))
						$macroslist[$cc]="{macro" & $index & "}" & StringTrimLeft($macroslist[$cc],StringLen($curmacro)-1)
					EndIf
				Next
				$cumuline=_ArrayToString($macroslist,"@",1)
				$cumuline=StringReplace($cumuline,"@{macro","{macro")
			EndIf
		EndIf

		; store current line as main code if not UDF def or #compiler-directive
		If $maincode=True And $insideUDFdef=False Then
			If $prevmaincode=False Then	; new maincode section => new entry
				$prevmaincode=True
				$refcount=$mainCodeSections[0][0]+1
				ReDim $mainCodeSections[$refcount+1][6]
				$mainCodeSections[$refcount][0]=$fileIndex
				$mainCodeSections[$refcount][1]=$curfile
				$mainCodeSections[$refcount][2]=$linestart
				$mainCodeSections[0][0]=$refcount

				; store as entrypoint if it's the first MCS for this source file
				If $firstmainline="<undefined>" Then
					$firstmainline=$cumuline
					_AddEntry($curfile,$linestart,$cumulinewithstrings)
				EndIf

			EndIf
			$mainCodeSections[$refcount][3]=$linestart	; update lastline of existing entry
			$mainCodeSections[$refcount][4]=$cumulinewithstrings
			$lastmainline=$cumulinewithstrings
		Else
			$maincode=False
			$prevmaincode=False
		EndIf

		; store all MCtags used inside UDF def in $MCinFuncDef[#] (# = $FunctionsDefined[#])
		; MCF needs this to recursively build a complete calling tree, including potential calls (when funcnames are parsed as string parameter)
		If $WriteMetaCode=True Then
			If $insideUDFdef=True Then
				$split=StringSplit($cumuline,"}")
				$MCtag=""
				For $cc=1 To $split[0]-1
					$pos=StringInStr($split[$cc],"{",0,-1)
					If $pos>0 Then $MCtag&=StringTrimLeft($split[$cc],$pos-1)
				Next
				If $funcdef_ID>0 Then $MCinFuncDef[$funcdef_ID]&=$MCtag
			EndIf
			If $skipwritemeta=false Then
				If FileWrite($MChandle,$cumuline & " " & $filelinetag & $linestart & "}" & @CRLF)=-1 Then
					$WriteMetaCode=False
					$WriteMetaCodeFail=True
				EndIf
			EndIf
		EndIf

		; reset linespecs
		$newglobals=0
		$addlines=0
		$cumuline=""
		$cumulinewithstrings=""
	WEnd

	If $MChandle<>"" And $MChandle<>-1 Then FileClose($MChandle)
	If @error=99 Then Return False	; special case: UnicodeSupport switched on for retry

	; store size of each #include
	$totalines+=$truelinecount
	_ArrayAdd($include_lines,$totalines,0,Chr(0))

	Return True

EndFunc


Func _AddIncludeonce($newinclude)

	; add to list if absent
	If _ArraySearch($includeonce,$newinclude,1)<1 Then
		_ArrayAdd($includeonce,$newinclude,0,Chr(0))
		$includeonce[0]=UBound($includeonce)-1
	EndIf

EndFunc


Func _AddInclude($curfile,$linecount,$line)
; assumes first string in line identifies the #include file
; accepted delimiters: double-quotes, single-quotes, or angled brackets (paired, not mixed)

	$include_index=-1
	$params="<n\a>"
	$pos1=StringInStr($line,'"',0,1)
	$pos2=StringInStr($line,'"',0,2)
	$pos3=StringInStr($line,"'",0,1)
	$pos4=StringInStr($line,"'",0,2)
	$pos5=StringInStr($line,"<",0,1)
	$pos6=StringInStr($line,">",0,1)

	Select
		case $pos1*$pos2>0 And $pos3*$pos4=0 and $pos5*$pos6=0
			$newinclude=StringStripWS(StringMid($line,$pos1+1,$pos2-$pos1-1),3)
			$bracketed=False
		Case $pos1*$pos2=0 And $pos3*$pos4>0 and $pos5*$pos6=0
			$newinclude=StringStripWS(StringMid($line,$pos3+1,$pos4-$pos3-1),3)
			$bracketed=False
		Case $pos1*$pos2=0 And $pos3*$pos4=0 and $pos5*$pos6>0
			$newinclude=StringStripWS(StringMid($line,$pos5+1,$pos6-$pos5-1),3)
			$bracketed=True
		Case Else
			Return -1	; some other format we currently cannot deal with?
	EndSelect
	If StringInStr($newinclude,"constants")=True Then
		If $includeConstants=False And $WriteMetaCode=False Then Return False
	EndIf

	; extend path if need be
	$curpath=StringLeft($curfile,StringInStr($curfile,"\",0,-1))
	$expanded=False

	If StringLeft($newinclude,2)=".\" Then
		$newinclude=$curpath & StringTrimLeft($newinclude,2)
		$expanded=True
	ElseIf StringLeft($newinclude,3)="..\" Then
		$newinclude=StringLeft($curfile,StringInStr($curfile,"\",0,-2)) & StringTrimLeft($newinclude,3)
		$expanded=True
	EndIf

	If $bracketed=True Then
		If FileExists($AutoItIncludeFolder & $newinclude) Then
			$newinclude=$AutoItIncludeFolder & $newinclude
		Else
			For $rc=1 To $extrapaths[0]
				If FileExists($extrapaths[$rc] & $newinclude) Then
					$newinclude=$extrapaths[$rc] & $newinclude
					ExitLoop
				EndIf
			Next
			If $rc>$extrapaths[0] Then	$newinclude= $curpath & $newinclude	; add sourcecode's path and hope for the best
		EndIf

	ElseIf Not $expanded Then							; #include not angle-bracketed
		If FileExists($curpath & $newinclude) Then
			$newinclude=$curpath	& $newinclude
		Else
			For $rc=1 To $extrapaths[0]
				If FileExists($extrapaths[$rc] & $newinclude) Then
					$newinclude=$extrapaths[$rc] & $newinclude
					ExitLoop
				EndIf
			Next

			If $rc>$extrapaths[0] And FileExists($AutoItIncludeFolder & $newinclude) Then _
				$newinclude=$AutoItIncludeFolder & $newinclude	; add default autoit3\include path and hope for the best

		EndIf
	Endif

	; add to list of includes if absent
	$okay=(FileExists($newinclude)=True)
	If $okay Then
		$include_index=_ArraySearch($includes,$newinclude,1)
		If $include_index<1 Then
			_ArrayAdd($includes,$newinclude,0,Chr(0))
			$includes[0]=UBound($includes)-1
			$include_index=$includes[0]

			; store separately if not in the default path
			If StringInStr($newinclude,$AutoItIncludeFolder)=0 Then
				_ArrayAdd($myincludes,$newinclude,0,Chr(0))
				$myincludes[0]=UBound($myincludes)-1
			EndIf
			If $diagnostics=True Then ConsoleWrite("New include added to list: " & $newinclude & " (nr " & $includes[0] & ")" & @CRLF)
		EndIf
	Else
		$newinclude=$line
		$params=$filenotfoundtag
		$include_notfound+=1
		If _ArraySearch($incl_notfound,$newinclude,1)<1 Then
			_ArrayAdd($incl_notfound,$newinclude,0,Chr(0))
			$incl_notfound[0]=UBound($incl_notfound)-1
			If $diagnostics=True Then ConsoleWrite("New lost include added to list: " & $newinclude & " (nr " & $incl_notfound[0] & ")" & @CRLF)
		EndIf

		If $diagnostics=True Then _
			MsgBox(262144+8192+48,"Error","unable to find #include referenced in: " & @CRLF& @CRLF & _
								"Source file: " & $curfile & @CRLF & _
								"Line number: " & $linecount & @CRLF & @CRLF & _
								"Content: " & @CRLF & $newinclude)
	EndIf

	; keep track of where it is being referenced/defined
	_AddRef($okay,$curfile,$linecount,"#include",$newinclude,$params)
	Return $include_index

EndFunc


Func _AddGlobal($filecount,$curfile,$linecount,$line)

	$globaLabel="Global"						; type in $refs[]
	$insertPrefix=""
	Select
		Case StringLeft($line,6)="Const "
			$line=StringTrimLeft($line,6)
			$insertPrefix="Const "
		Case StringLeft($line,5)="Enum "	; can be none or one, but not both
			$line=StringTrimLeft($line,5)
			$insertPrefix="Enum "
			$globaLabel="Global Enum"		; type in $refs[]
			If StringLeft($line,5)="Step " Then
				$pos=StringInStr($line," ",6)
				If $pos>0 Then
					$insertPrefix&=StringLeft($line,$pos-1)
					$line=StringTrimLeft($line,$pos)
				EndIf
			EndIf
	EndSelect

	If StringInStr($line,"(")=0 and StringInStr($line,"[")=0 Then
		$sections=StringSplit($line,",")
	Else
		$nesting=0
		$nestingsq=0
		$newline=""

		For $rc=1 To StringLen($line)
			$curchar=StringMid($line,$rc,1)
			Switch $curchar
				Case "("
					$nesting+=1
				Case ")"
					$nesting=_max(0,$nesting-1)
				Case "["
					$nestingsq+=1
				Case "]"
					$nestingsq=_max(0,$nestingsq-1)
				Case ","
					If $nesting+$nestingsq=0 Then $curchar=Chr(255)
				EndSwitch
			$newline&=$curchar
		Next
		$sections=StringSplit($newline,Chr(255))
	EndIf

	Global $newglobals[1]
	For $rc=1 To $sections[0]
		$insertdims=""
		$line=StringStripWS($sections[$rc],1+2)
		if StringLeft($line,1)<>"$" Then ContinueLoop
		$pos1=StringInStr($line,"[")
		If $pos1>0 Then
			$nestingsq=1
			For $cc=$pos1 To StringLen($line)
				$curchar=StringMid($line,$cc,1)
				Switch $curchar
					Case "["
						$nestingsq+=1
					Case "]"
						$nestingsq-=1
						If $nestingsq=0 Then
							$insertdims=StringMid($line,$pos1,1+$cc-$pos1)
							ExitLoop
						EndIf
				EndSwitch
			Next
		EndIf

		$pos=StringInStr($line,"=")
		If $pos=0 Then
			$var=StringStripWS($line,1+2)
			$params="{none}"
			$isMainCode=False
		Else
			$var=StringStripWS(StringLeft($line,$pos-1),1+2)
			$params=StringStripWS(StringTrimLeft($line,$pos),1+2)
			$isMainCode=(StringInStr(_MCwords($params,True),"{func")>0)	; assignment involves function call
		EndIf

		If $insertdims<>"" Then $var=StringLeft($line,$pos1-1)	; correction for arrays

		$refrecord=_AddRef(True,$curfile,$linecount,$GlobaLabel,$var & $insertdims,$params)
		_ArrayAdd($newglobals,$var,0,Chr(0))

		If $WriteMetaCode=True Then _
			FileWrite($MChandle,"Global " & $insertPrefix & "$*" & $insertdims & " " & $filelinetag & $linecount & "}{ref" & $refrecord & "}" & @CRLF)

		; make a separate listing of our own globals
		If _ArraySearch($myincludes,$curfile,1)>0 Then
			$refcount=$refglobals[0][0]+1
			ReDim $refglobals[$refcount+1][6]
			$refglobals[$refcount][0]=True
			$refglobals[$refcount][1]=$curfile
			$refglobals[$refcount][2]=$linecount
			$refglobals[$refcount][3]=$GlobaLabel	; "Global" or "Global Enum"
			$refglobals[$refcount][4]=$var
			$refglobals[$refcount][5]=$params
			$refglobals[0][0]=$refcount
		EndIf

		; to identify potential conflicting (re)definitions in different locations
		$newglobal=$curfile & " Global def: " & $var
		If _ArraySearch($globals,$newglobal,1)<1 Then _ArrayAdd($globals,$var,0,Chr(0))
	Next
	$globals[0]=UBound($globals)-1
	$newglobals[0]=UBound($newglobals)-1

	Return $isMainCode
EndFunc


Func _AddFunc($curfile,$linecount, ByRef $line)

	$okay=True
	$params="{none}"
	$pos0=StringInStr($line,'func ',0,1)
	$pos1=StringInStr($line,'(',0,1)		; leftmost parenthesis
	$pos2=StringInStr($line,')',0,-1)	; rightmost parenthesis

	If $pos1*$pos2>0 And $pos1<$pos2 Then	; both nonzero and in right order
		$newfunc=StringStripWS(StringMid($line,$pos0+5,$pos1-6),1+2)
		If $pos2>$pos1+1 Then $params=StringStripWS(StringMid($line,$pos1+1,$pos2-$pos1-1),3)
	Else
		$newfunc=$line
		$params=$paramsunresolvedtag
		$okay=False
		$func_paramsunresolved+=1
	EndIf

	; add to list of func defs if valid and absent
	$func_ID=0
	If $okay=True Then
		$func_ID=_AddFunCall($newfunc,True)	; true = store in $functionsDefined
		$line="Func {funcU" & $func_ID & "} (" & $params & ")"
		If $diagnostics=True Then ConsoleWrite("New func def added to list: " & $newfunc & " (nr " & $functionsDefined[0] & ")" & @CRLF)
	EndIf

	; keep track where it is being referenced/defined
	_AddRef($okay,$curfile,$linecount,"func def",$newfunc,$params)

	Return $funcdef_ID	; this global is (re)defined in AddFunCall; returned explicitly for code clarity
EndFunc


Func _AddEndFunc($curfile,$linecount,$line)
	_AddRef(True,$curfile,$linecount,"func end",$line,"<n/a>")
EndFunc


Func _AddFor($curfile,$linecount,$line)
	$curline=StringStripWS($line,1+2)
	$status=(StringLen($curline)>0 And (StringInStr($curline," To ") Or StringInStr($curline," In ")))
	If $status=False Then
		$loopmissingparams+=1
		$curline="<missing range>"
	EndIf
	_AddRef($status,$curfile,$linecount,"Loop Start","For",$curline)
EndFunc


Func _AddNext($curfile,$linecount)
	_AddRef(True,$curfile,$linecount,"Loop End ","Next","<n/a>")
EndFunc


Func _AddWhile($curfile,$linecount,$line)
	$curline=StringStripWS($line,1+2)
	$status=(StringLen($curline)>0)
	If $status=False Then
		$loopmissingparams+=1
		$curline="<missing condition>"
	EndIf
	_AddRef($status,$curfile,$linecount,"Loop Start","While",$curline)
EndFunc


Func _AddWend($curfile,$linecount)
	_AddRef(True,$curfile,$linecount,"Loop End ","WEnd","<n/a>")
EndFunc


Func _AddDo($curfile,$linecount)
	_AddRef(True,$curfile,$linecount,"Loop Start","Do","<n/a>")
EndFunc


Func _AddUntil($curfile,$linecount,$line)
	$curline=StringStripWS($line,1+2)
	$status=(StringLen($curline)>0)
	If $status=False Then
		$loopmissingparams+=1
		$curline="<missing condition>"
	EndIf
	_AddRef($status,$curfile,$linecount,"Loop End ","Until",$curline)
EndFunc


Func _AddExit($curfile,$linecount,$line,$insideUDFdef)
	$curline=" " & $line & " "
	$pos=StringInStr($curline,"Exit")
	While $pos>0 And $pos<StringLen($line)
		$prevchar=StringMid($curline,$pos-1,1)
		$nextchar=StringMid($curline,$pos+4,1)
		$startofword=($prevchar=" " Or $prevchar="(")
		$endofword=($nextchar=" " Or $nextchar="(" Or $nextchar=")")

		If $startofword And $endofword Then
			$exitag="<explicit>"
			If $insideUDFdef=True Then	$exitag="<explicit, in UDF>"
			_AddRef(True,$curfile,$linecount,"Exit",$exitag,$line)
			_Add2Exitpoints(UBound($references)-1)
			ExitLoop
		EndIf
		$pos=StringInStr($curline,"Exit",0,1,$pos+1)
	WEnd
EndFunc


Func _AddEntry($curfile,$linecount,$line)

	_AddRef(True,$curfile,$linecount,"Main Code","Entry point",$line)

	$refcount=$Entrypoints[0][0]+1
	ReDim $Entrypoints[$refcount+1][6]
	$Entrypoints[$refcount][0]=($curfile=$includes[1])
	$Entrypoints[$refcount][1]=$curfile
	$Entrypoints[$refcount][2]=$linecount
	$Entrypoints[$refcount][3]="Main Code"
	$Entrypoints[$refcount][4]="Entry point"
	$Entrypoints[$refcount][5]=$line
	$Entrypoints[0][0]=$refcount

EndFunc


Func _AddRef($okay,$curfile,$linecount,$reftype,$ref,$params="")

	$refcount=$references[0][0]+1
	ReDim $references[$refcount+1][6]
	$references[$refcount][0]=$okay
	$references[$refcount][1]=$curfile
	$references[$refcount][2]=$linecount
	$references[$refcount][3]=$reftype
	$references[$refcount][4]=$ref
	$references[$refcount][5]=$params
	$references[0][0]=$refcount

	; unknown funcs are likely to be identified in post-processing, so don't store these yet
	If Not $okay And $references[$refcount][3]<>$func_unknown_tag Then _Add2Problems($refcount,$reftype,$ref)
	Return $refcount
EndFunc


Func _SwitchUnicodeOn()
	$UnicodeSupport=True
	If $useINIsettings=True Then
		$INIvars[1][1]=$UnicodeSupport	; ensure this hardcoded index matches the one in _ReadINIFile()
		IniWriteSection($inifile,"Booleans",$INIvars)
	EndIf
EndFunc


Func _GetnextlineASCII($basepointer, ByRef $lseek,$fsize,$index)

	$line=""
	$linebuffer = DllStructCreate("byte["&_Min(4096,$fsize-$lseek)&"]", $basepointer + $lseek)
	$newline=BinaryToString(DllStructGetData($linebuffer, 1))

	$pos=StringInStr($newline,@CRLF)
	If $pos=0 Then							; EOL not found
		If $UnicodeSupport=False And $truelinecount+1=0 Then	; probably not an ASCII file
			If $runquiet=True Then
				_SwitchUnicodeOn()
				Return SetError(99,0,"")		; flag to retry scanning with UTF switched on
			Else
				If MsgBox(262144+8192+16+5,"Code Scanner","File read error: maximum linelength exceeded in " & _
					$includes[$index] & ", line: " & $truelinecount & @CR & @CR & _
					"Note: Unicode Support is currently switched off;" & @CR & "would you like to Retry scanning with this option enabled?")=4 Then
						_SwitchUnicodeOn()
						Return SetError(99,0,"")		; flag to retry scanning with UTF switched on
				Else
					Exit (0)	; user pressed "Cancel" button, so abort
				EndIf
			EndIf
		Else
			_IOError("maximum linelength exceeded in " & $includes[$index] & ", line: " & $truelinecount+1)
		EndIf
	EndIf

	$line=StringStripWS(StringReplace(StringLeft($newline,$pos-1),@TAB," "),1+2+4)

	$lseek+=$pos+1	; stringinstr=base-1, lseek offset = base-0, so shift=pos+2-1
	$truelinecount+=1

	Return $line

EndFunc


Func _GetnextlineUTF($fh,$index,$fsize, ByRef $lseek)

	$line=""
	$line=FileReadLine($fh)		; automatically handles various UTF formats
	If @error Then Return ""

	$line=StringStripWS(StringReplace($line,@TAB," "),1+2+4)

	$lseek=FileGetPos($fh)
	$truelinecount+=1
	If Mod($truelinecount,200)=0 Then
		If $diagnostics=True Then ConsoleWrite("Lines read (UTF): " & $truelinecount &"..." & @CRLF)

		$pct1=Floor(100*$index/$includes[0])
		$pct2=Floor(100*FileGetPos($fh)/$fsize)
		ProgressSet($pct1,"Scanning " & $trimmedfname & " ("& $pct2 & "% done)...")
	EndIf

	Return $line

EndFunc


Func _BuildIncTree()

	If $pairs=0 Then Return

	If $showprogress=True Then SplashTextOn("","Resolving Includes hierarchy..." ,300,40,-1,-1,1+32,"Verdana",10)
	Global $includedonceasparent[1]
	Global $includedonceaschild[1]
	$includedonceasparent[0]=0
	$includedonceaschild[0]=0

	Global $treeIncl[2]
	$treeIncl[1]=$parent[1] & $separator & $child[1]
	_AddIncludedonceAsParent($parent[1])
	_AddIncludedonceAsChild($child[1])

	; create nesting level 0
	For $pc=2 To $pairs
		If $parent[$pc]=$parent[1] Then			; process root parent only
			$newpair=$parent[$pc] & $separator & $child[$pc]
			If _ArraySearch($treeIncl,$newpair,1)<1 Then
				_ArrayAdd($treeIncl,$newpair,0,Chr(0))
				_AddIncludedonceAsChild($child[$pc])
			EndIf
		EndIf
	Next
	$treeIncl[0]=UBound($treeIncl)-1
	$samecount=0
	$largercount=0
	$nestinglevel=1
	$itemsadded=$treeIncl[0]
	If $diagnostics=True Then ConsoleWrite("Building tree, nesting level " & $nestinglevel & "; items added: " & $itemsadded & @CRLF )

	While $itemsadded=True
		$prevadded=$itemsadded
		$itemsadded=0
		$nestinglevel+=1
		For $tc=1 To $treeIncl[0]
			$curbranch=$treeIncl[$tc]
			$curparent=StringTrimLeft($curbranch,StringInStr($curbranch,$separator,0,-1)+StringLen($separator)-1)

			$includeonlyonce =(_ArraySearch($includeonce,$curparent,1)>0)
			$notyetincludedonceasparent =(_ArraySearch($includedonceasparent,$curparent)<1)
			$addthisparent	=( $includeonlyonce=false Or ($includeonlyonce=True And ($notyetincludedonceasparent=True)))

			If $addthisparent=True Then
				_AddIncludedonceAsParent($curparent)
				For $pc=1 To $pairs
					If $parent[$pc]=$curparent then
						$curchild=$child[$pc]
						$includeonlyonce2		=(_ArraySearch($includeonce,$curchild,1)>0)
						$notyetincludedonceaschild	=(_ArraySearch($includedonceaschild,$curchild,1)<1)
						$addthischild=($includeonlyonce2=false Or ($includeonlyonce2=True And ($notyetincludedonceaschild=True)))

							$duplicationflag=""
							;If $addthischild=False and $showfirstduplication=True Then $duplicationflag=$duplicatestag
							If $addthischild=False Then $duplicationflag=$duplicatestag
							$newbranch=$curbranch & $separator & $curchild & $duplicationflag
							If _ArraySearch($treeIncl,$newbranch,1)<1 Then
								_ArrayAdd($treeIncl,$newbranch,0,Chr(0))
								$itemsadded+=1
							EndIf
							_AddIncludedonceAsChild($curchild)

					EndIf
				Next
			EndIf
		Next
		$treeIncl[0]=UBound($treeIncl)-1
		If $diagnostics=True Then ConsoleWrite("Building tree, nesting level " & $nestinglevel & "; items added: " & $itemsadded & @CRLF )
		Select
			Case $prevadded=$itemsadded
				$samecount+=1
			Case $prevadded>$itemsadded
				$largercount+=1
		EndSelect
		If $samecount+$largercount>50 Then
			SplashOff()
			If $runquiet=False Then
				MsgBox(262144+8192+16,"Halting execution","#includes hierarchy does not converge")
				_ArrayDisplay($treeIncl)
			EndIf
			Exit (-13)
		EndIf
	WEnd

	SplashOff()
	If $diagnostics=True Then
		ConsoleWrite(@CR & @CR)
		_ArrayDisplay($treeIncl,"#includes hierarchy")
	EndIf

EndFunc


Func _AddIncludedonceAsParent($newinclude)

	; consider only if marked as #include-once
	If _ArraySearch($includeonce,$newinclude,1)<1 Then Return

	; add to list if absent
	If _ArraySearch($includedonceasparent,$newinclude,1)<1 Then
			_ArrayAdd($includedonceasparent,$newinclude,0,Chr(0))
			$includedonceasparent[0]=UBound($includedonceasparent)-1
	EndIf

EndFunc


Func _AddIncludedonceAsChild($newinclude)

	; consider only if marked as #include-once
	If _ArraySearch($includeonce,$newinclude,1)<1 Then Return

	; add to list if absent
	If _ArraySearch($includedonceaschild,$newinclude)<1 Then
			_ArrayAdd($includedonceaschild,$newinclude,0,Chr(0))
			$includedonceaschild[0]=UBound($includedonceaschild)-1
	EndIf

EndFunc


Func _AddFuncAsParent($newfunc)

	; add to list if absent
	If _ArraySearch($includedonceasparent,$newfunc,1)<1 Then
			_ArrayAdd($includedonceasparent,$newfunc,0,Chr(0))
			$includedonceasparent[0]=UBound($includedonceasparent)-1
	EndIf

EndFunc


Func _AddFuncAsChild($newfunc)

	; add to list if absent
	If _ArraySearch($includedonceaschild,$newfunc,1)<1 Then
			_ArrayAdd($includedonceaschild,$newfunc,0,Chr(0))
			$includedonceaschild[0]=UBound($includedonceaschild)-1
	EndIf

EndFunc


Func _Scan4Func($curfile,$linecount, ByRef $cumuline)
; we only get here if either $trackAU3calls or $trackUDFcalls is true (both are true if WriteMetaCode=True)

	$line=$cumuline
	$newline=""
	$previousword=""
	$params=""
	For $pos=1 To StringLen($line)
		$curchar=StringMid($line,$pos,1)
		If $validprefix[Asc($curchar)]=False Then
			$newline&=$curchar
		Else					; add extra spacers around valid prefix chars
			Switch $curchar
				Case "{"
					$newline&=" " & $curchar	; do not add spacers inside our own tags
				Case "}"
					$newline&= $curchar & " "	; do not add spacers inside our own tags
				Case Else
					$newline&=" " & $curchar & " "
			EndSwitch
		EndIf
	Next
	$line=StringStripWS($newline,1+2+4) & " "	; remove multispace, add one trailing space (see below)

	$cumuloffset=0
	$splitline=StringSplit($line," ")
	For $rc=1 To $splitline[0]-1
		$curoffset=StringLen($splitline[$rc])+1
		$cumuloffset+=$curoffset	; $pos in line of next word after $previousword

		If $splitline[$rc+1]<>"(" Then ContinueLoop
		$previousword=$splitline[$rc]

		; skip AutoIt-internal (keywords and operators) and object-related functions (e.g., $*.ExecQuery())
		If _ArraySearch($AU3operators,$previousword,1)>0 Then ContinueLoop
		If StringLeft($previousword,1)="$" Or StringInStr($previousword,".") Then ContinueLoop

		; found a function call we might want to track
		$totalcalls+=1

		; determine parameters
		; $pos1 = position of first opening bracket after current function
		$pos1=$cumuloffset+1		; nope, undefined UDF (for now, may be defined later)
		$bracketnesting=1
		For $pos2=$pos1+1 To StringLen($line)
			$curchar=Asc(StringMid($line,$pos2,1))
			Switch $curchar
				Case 40	;$curchar='('
					$bracketnesting+=1
				Case 41	;$curchar=")"
					$bracketnesting-=1
					If $bracketnesting=0 Then ExitLoop	; $pos2 = closing bracket associated with current opening bracket
			EndSwitch
		next

		; $line has added trailing space so position of last closing bracket of UDF cannot be last
		$okay=($pos2<StringLen($line))	; bracket nesting error?
		If $okay Then
			$params=StringStripWS(StringMid($line,$pos1+1,$pos2-$pos1-1),1+2+4)
			If $params="" Then $params="{none}"
		Else
			$params=$line	; unresolved parameters, so store entire line for analysis
			$func_paramsunresolved+=1
		EndIf

		; is it an AutoIt function?
		$parsedfunc=False
		$AU3_index=_ArraySearch($AU3Functions,$previousword,1)	; always identify to distinguish from undeclared UDFs below
		If $TrackAU3Calls=True And $AU3_index<>-1 Then
			If _ArraySearch($AU3FunctionsUsed,$previousword,1)<1 Then _ArrayAdd($AU3FunctionsUsed,$previousword,0,Chr(0))
			_AddRef($okay,$curfile,$linecount,"AU3 call",$AU3Functions[$AU3_index],$params)
			$splitline[$rc]="{funcA" & $AU3_index & "}"

			; special case: parsing another function call?
			Switch $previousword
				Case "AdlibEnable"		; no func params allowed
					$funcparamID=1
				Case "AdlibRegister"		; no func params allowed
					$funcparamID=1
				Case "AdlibUnRegister"	; no func params allowed
					$funcparamID=1
				Case "Call"					; UDF only, unknown number of func params may follow
					$funcparamID=1
				Case "GUICtrlSetOnEvent"; no func params allowed
					$funcparamID=2
				Case "GUIRegisterMsg"	; UDF only, <=4 predefined func params, none is parsed
					$funcparamID=2
				Case "GUISetOnEvent"		; no func params allowed
					$funcparamID=2
				Case "HotKeySet"			; no func params allowed
					$funcparamID=2
				Case "OnAutoItExitRegister"			; no func params allowed
					$funcparamID=1
				Case "OnAutoItExitUnRegister"			; no func params allowed
					$funcparamID=1
				Case Else
					ContinueLoop
			EndSwitch
			$parsedfunc=True

			; retrieve the func parameter from $stringsUsed
			$split=StringSplit($params,",")
			If $split[0]=1 And $funcparamID>1 Then ContinueLoop

			If StringInStr($split[$funcparamID],"$") Or StringInStr($split[$funcparamID],"&") Then ContinueLoop	; $variable-content based, so may be defined only at run-time
			$pos1=StringInStr($split[$funcparamID],"{string")
			If $pos1<1 Then ContinueLoop

			$pos2=StringInStr($split[$funcparamID],"}",0,1,$pos1)
			$stringref=StringMid($split[$funcparamID],$pos1+7,$pos2-$pos1-7)
			$prevcall=$previousword
			$previousword=$stringsUsed[$stringref]

			If StringLeft($previousword,1)='"' Or StringLeft($previousword,1)="'" Then _
				$previousword=StringTrimLeft(StringTrimRight($previousword,1),1)
			If StringStripWS($previousword,1+2)="" Then ContinueLoop

			Switch $prevcall
				Case "Call"	; may have unknown number of trailing parameters following function param
					$params=""
					For $cc=2 To $split[0]
						$params&=$split[$cc] & ","
					Next
					$params=StringTrimRight($params,1)	; remove last comma
					If $params="" Then $params="{none}"
					$AU3_index=-1	; flag to proceed with UDF processing

				Case "GUIRegisterMsg" ; up to 4 predefined params, none is parsed
					$params="{none}"
					$AU3_index=-1	; flag to proceed with UDF processing

				Case Else	; any func, no params
					$AU3_index=_ArraySearch($AU3Functions,$previousword,1)	; always identify to distinguish from undeclared UDFs below
					If $AU3_index<>-1 Then
						If _ArraySearch($AU3FunctionsUsed,$previousword,1)<1 Then _ArrayAdd($AU3FunctionsUsed,$previousword,0,Chr(0))
						_AddRef($okay,$curfile,$linecount,"AU3 call",$AU3Functions[$AU3_index],"{none}") ; params forced (none accepted)
						$splitline[$rc]="{funcA" & $AU3_index & "}"
						ContinueLoop
					EndIf
					$params="{none}"			; no func params allowed
			EndSwitch
		EndIf					; is it an AU3func?

		; if not AU3-related, is it one of our own UDFs?
		If $AU3_index=-1 And $TrackUDFCalls=True Then
			$func_index=_ArraySearch($functionsUsed,$previousword,1)	; separate index used to standardise output
			If $func_index>0 Then
				$previousword=$functionsUsed[$func_index]	; standardise capitalisation
				_AddRef($okay,$curfile,$linecount,"UDF call",$previousword,$params)
			Else
				_AddRef(False,$curfile,$linecount,$func_unknown_tag,$previousword,$params)
			EndIf
			$func_ID=_AddFunCall($previousword,(StringLeft($cumuline,5)="Func "))	; if no def, store in functionsCalled too
			If $parsedfunc=False Then
				$splitline[$rc]="{funcU" & $func_ID & "}"	; parsed func would overprint earlier-defined funcA
			EndIf	; string# <= funcU# replacement is handled by MCF in Single-Build (because some instances (like object-methods) are not caught here)
		EndIf

	Next
	$cumuline=_ArrayToString($splitline," ",1)

EndFunc


Func _BuildRefindex()

	If $showprogress=True Then _
		$PBhandle=_ProgressBusy("Code Scanner: " & $trimmedroot,"Building Index" ,"Please wait...")

	$totaldex=$includes[0]+$functionsDefined[0]
	Global $startofuncs=$includes[0]+1

	ReDim $include_stats[1+$includes[0]][11]
	$include_stats[0][0]=$includes[0]

	ReDim $refindex[$totaldex+1][7]
	$refindex[0][0]=$totaldex

	; prezero
	For $rc=1 To $includes[0]
		$include_stats[$rc][2]=0
		$include_stats[$rc][3]=0
		$include_stats[$rc][4]=0
		$include_stats[$rc][7]=0
		$include_stats[$rc][10]=0
	Next

	For $rc=1 To $totaldex
		$refindex[$rc][1]=0
		$refindex[$rc][2]=0
		$refindex[$rc][3]=0
		$refindex[$rc][4]=0
		$refindex[$rc][5]=0
		$refindex[$rc][6]=0
	Next

	For $rc=1 To $includes[0]
		$refindex[$rc][0]=$includes[$rc]
		$include_stats[$rc][2]=$include_lines[$rc]
		$include_stats[$rc][8]=(_ArraySearch($myincludes,$includes[$rc],1)<1)
		$include_stats[$rc][9]=0
	Next

	For $rc=1 To $MainCodeSections[0][0]
		$index=$MainCodeSections[$rc][0]
		$include_stats[$index][9]+=1
	Next

	$insideUDFdef=False
	$curfunc="<invalid>"
	$cursource1="<invalid>"				; to trigger reloadvars at start
	$cursource2="<invalid>"				; to trigger reloadvars at start
	For $rc=1 To $references[0][0]	; #includes and UDF defs

		If $references[$rc][1]=$cursource1 Then
			$refindex[$sourcedex][2]=$rc		; record number in $references[]; keeps updating
		Else
			$cursource1=$references[$rc][1]
			$sourcedex=_ArraySearch($includes,$cursource1,1)
			$include_stats[$sourcedex][0]=$references[$rc][0]	; valid
			$include_stats[$sourcedex][1]=$cursource1
			$refindex[$sourcedex][1]=$rc		; record number in $references[]
			$refindex[$sourcedex][2]=$rc		; record number in $references[]; keeps updating
			$refindex[$sourcedex][3]=1
			$refindex[$sourcedex][4]=$include_stats[$sourcedex][2]
			$insideUDFdef=False
		EndIf

		If $references[$rc][3]="#include" Then
			$include_stats[$sourcedex][3]+=1
			$index=_ArraySearch($includes,$references[$rc][4],1)
			If $index>0 Then $include_stats[$index][10]=$rc	; store the $references[] record where the #include was tracked
		EndIf

		If StringLeft($references[$rc][3],6)="Global" Then
			$include_stats[$sourcedex][7]+=1
			$curglobal=$references[$rc][4]
			$pos=StringInStr($curglobal,"[")
			If $pos>1 Then $curglobal=StringLeft($curglobal,$pos-1)
			If $insideUDFdef=False Then
				_ArrayAdd($globalglobals,$curglobal,0,Chr(0))	; may produce some doubles (unimportant)
			Else
				$refcount=$globalsinFuncs[0][0]+1
				ReDim $globalsinFuncs[$refcount+1][5]
				$globalsinFuncs[$refcount][0]=False
				$globalsinFuncs[$refcount][1]=$cursource1
				$globalsinFuncs[$refcount][2]=$references[$rc][2]
				$globalsinFuncs[$refcount][3]=$curfunc	; filled below
				$globalsinFuncs[$refcount][4]=$references[$rc][4]
				$globalsinFuncs[0][0]=$refcount
			EndIf

			If $ExtractVars=True Then
				If StringInStr($references[$rc][3],"Enum")<1 Then
					If _ArraySearch($variablesUsed,$curglobal,1)=-1 Then _ArrayAdd($globalsRedundant,$curglobal,0,Chr(0))
				EndIf
			EndIf

			; check next $ref[] records with same file+linenr for function calls, and add these to $functionsCalled;
			; these are missed in BuildFuncTree because global defs fall outside the Main Code,
			; but should be included for MCF post-processing
			If $TrackCalls=True Then
				$curlinenr=$references[$rc][2]
				For $cc=$rc+1 To $references[0][0]
					If $references[$cc][2]<>$curlinenr Then ExitLoop	; least likely condition first
					If $references[$cc][1]<>$cursource1 Then ExitLoop
					If $references[$cc][3]="UDF call" Then
						_ArrayAdd($functionsCalled,$references[$cc][4],0,Chr(0))	; remove brackets
						$curfunc=$cursource1 & " UDF: " & $references[$cc][4]
						_ArrayAdd($uniquefuncsAll,$curfunc,0,Chr(0))
						_ArrayAdd($uniqueFuncsCalled,$curfunc,0,Chr(0))
					EndIf
				Next
			EndIf

		EndIf		; global

		; store UDFs (fills $curfunc)
		If $references[$rc][3]="func def" Then
			$curfunc=$references[$rc][4]
			$funcdex=_ArraySearch($functionsDefined,$curfunc,1)+$startofuncs-1
			$refindex[$funcdex][0]=$references[$rc][1] & " UDF: " & $curfunc		; line number in source code
			$refindex[$funcdex][1]=$rc
			$refindex[$funcdex][3]=$references[$rc][2]		; first line number of UDF def in source code
			$include_stats[$sourcedex][4]+=1						; UDF def count per #include
			$insideUDFdef=True
		EndIf

		If $references[$rc][0]=True And $references[$rc][3]="func end" Then
			$curfunc=$references[$rc][4]
			$funcdex=_ArraySearch($functionsDefined,$curfunc,1)+$startofuncs-1
			$refindex[$funcdex][2]=$rc
			$refindex[$funcdex][4]=$references[$rc][2]		; last line number of UDF def in source code
			$insideUDFdef=False
		EndIf
	Next
	$refindex[0][0]=UBound($refindex)-1
	$globalglobals[0]=UBound($globalglobals)-1

	; compare lists of globals defined inside vs outside resp.,
	; and remove the latter from the former if present in both,
	; so $globalsinFuncs afterwards contains only $vars undefined outside of UDFs
	For $rc= $globalsinFuncs[0][0] To 1 Step -1	; backwards to keep index from shifting
		$curglobal=$globalsinFuncs[$rc][4]
		$pos=StringInStr($curglobal,"[")
		If $pos>1 Then $curglobal=StringLeft($curglobal,$pos-1)
		If _ArraySearch($globalglobals,$curglobal,1)>0 Then _ArrayDelete($globalsinFuncs,$rc)
	Next
	$globalsinFuncs[0][0]=UBound($globalsinFuncs)-1	; update
	$globalsRedundant[0]=UBound($globalsRedundant)-1
	$FunctionsCalled[0]=UBound($FunctionsCalled)-1

	If $showprogress=True Then GUIDelete($PBhandle)

EndFunc


Func _TrueFirstEntrypoint()

	$trueFirstEntrypoint=-1		; index to $entrypoints[][]
	For $rc=1 To $Entrypoints[0][0]

		If $Entrypoints[$rc][1]=$includes[1] then
			$trueFirstEntrypoint=$rc		; first to be processed, if present
		Else

			; check if directly or indirectly included
			; NB can be included more than once, but only the first instance is relevant
			; find in include hierarchy tree
			$index=_ArraySearch($treeIncl,$Entrypoints[$rc][1],0,0,0,1)	; stringinstr
			If $index=-1 Then ContinueLoop

			$split=StringSplit($treeIncl[$index],$separator,1)	; split first-found branch
			If @error Then ContinueLoop
			If $split[0]<2 Then ContinueLoop
			$cursource=$split[2]		; get the #include nearest to root level
			$index=_ArraySearch($include_stats,$cursource,0,0,0,0,1,1)
			If $index=-1 Then ContinueLoop

			; find where in the rootfile this #include is introduced
			$refrec=$include_stats[$index][10]	; record in $references tracking the #include or its highest parent
			If $refrec<1 Then ContinueLoop

			$linecount=$references[$refrec][2]	; line nr in root file of highest parent #include containing our entrypoint sourcefile as include

			; if this line precedes the current-best candidate, update
			If $trueFirstEntrypoint=-1 Then
				$trueFirstEntrypoint=$rc
			Else
				If $linecount<$Entrypoints[$trueFirstEntrypoint][2] Then $trueFirstEntrypoint=$rc
			EndIf
		EndIf
	Next

EndFunc


Func _BuildFuncTree()	; requires prior call to _BuildRefindex()

	If $showprogress=True Then _
		$PBhandle=_ProgressBusy("Code Scanner: " & $trimmedroot,"Resolving UDF hierarchy" ,"Please wait...")

	Global $treeFunc[1]
	Global $includedonceasparent[1]
	Global $includedonceaschild[1]
	Global $AU3FunctionsCalled[1]
	$includedonceasparent[0]=0
	$includedonceaschild[0]=0
	$prevsource=""
	$sourceindex=-1
	For $rc=1 To $references[0][0]
		If $references[$rc][1]<>$prevsource Then
			$prevsource=$references[$rc][1]
			$sourceindex=_ArraySearch($includes,$references[$rc][1],1)
			$MCSoffset=_ArraySearch($mainCodeSections,$sourceindex,1,0,0,0,1,0)
			If $MCSoffset<1 Then
				If $sourceindex>0 Then $rc=$refindex[$sourceindex][2]	; skip to last line of current include in $references if current inclue does not have MCS
				ContinueLoop	; no main code sections in this include
			EndIf
		EndIf

		; NB restricting analysis to MainCodeSections implies that UDFs that are called
		; only to define globals will not show up in the UDF hierarchy tree;
		; however, MCF processing *does* take them into account
		$curline=$references[$rc][2]	; get sourcecode line # of current func call
		$maincode=False
		For $cc=$MCSoffset To $mainCodeSections[0][0]	; check whether it's in the main code
			If $mainCodeSections[$cc][0]<>$sourceindex Then ExitLoop	; early out
			If $curline>=$mainCodeSections[$cc][2] And $curline<=$mainCodeSections[$cc][3] Then
				$maincode=True
				ExitLoop
			EndIf
		Next

		If $maincode=true And StringInStr($references[$rc][3]," call") Then		; initially process only main code in root file
			$newpair=$rootfile & $separator & $references[$rc][4]
			If _ArraySearch($treeFunc,$newpair,1)<1 Then
				_ArrayAdd($treeFunc,$newpair,0,Chr(0))

				If StringLeft($references[$rc][3],3)="AU3" Then
					_ArrayAdd($AU3FunctionsCalled,$references[$rc][4],0,Chr(0))	; stores only maincode-related AU3 calls
				EndIf

				; update call tallies
				$curchild=$references[$rc][4]
				$funcdexchild=_ArraySearch($functionsDefined,$curchild,1)+$startofuncs-1
				$funcdestin=StringLeft($refindex[$funcdexchild][0],StringInStr($refindex[$funcdexchild][0]," UDF:")-1)
				$destindex=_ArraySearch($includes,$funcdestin,1)

				; update incoming/outgoing calls tallies
				$refindex[1][6]+=1													; increment outgoing for rootfile
				If $destindex>-1 Then $refindex[$destindex][5]+=1			; increment incoming for destination include
				If $funcdexchild>-1 Then $refindex[$funcdexchild][5]+=1	;	"incoming calls"
				; NB $funcdexparent does not exist, as child is called from root's main code
				; so incoming<>outgoing calls for UDFs, by definition
				_AddFuncAsChild($references[$rc][4])
			EndIf
		EndIf
	Next
	$treeFunc[0]=UBound($treeFunc)-1

	$nestinglevel=0
	$itemsadded=1
	$samecount=0
	$largercount=0
	$startprocessinghere=1
	If $diagnostics=True Then ConsoleWrite("Building tree, nesting level " & $nestinglevel & "; items added: " & $itemsadded & @CRLF )

	While $itemsadded=True
		$prevadded=$itemsadded
		$itemsadded=0
		$nestinglevel+=1
		For $tc=$startprocessinghere To $treeFunc[0]
			$curbranch=$treeFunc[$tc]
			$curparent=StringTrimLeft($curbranch,StringInStr($curbranch,$separator,0,-1)+StringLen($separator)-1)
			$addthisparent	=(_ArraySearch($includedonceasparent,$curparent,1)<1)

			If $addthisparent=True Then
				_AddFuncAsParent($curparent)

				; find sourcecode + linenumber range of new parent func def
				$funcdexparent=_ArraySearch($functionsDefined,$curparent,1)+$startofuncs-1
				$funcsource=StringLeft($refindex[$funcdexparent][0],StringInStr($refindex[$funcdexparent][0]," UDF:")-1)
				$funcdefstart=$refindex[$funcdexparent][3]
				$funcdefinish=$refindex[$funcdexparent][4]

				; is this UDF okay?
				$funcdefstatus=$references[$refindex[$funcdexparent][1]][0]

				; find the parent sourcecode's range to scan for new calls in $references[]
				$sourcedex=_ArraySearch($includes,$funcsource,1)
				If $sourcedex<1 Then ContinueLoop
				$refscanstart	=$refindex[$sourcedex][1]		; start record number in $references[]
				$refscanfinish	=$refindex[$sourcedex][2]		; end   record number in $references[]
				If $refscanstart*$refscanfinish=0 Then ContinueLoop	; no function calls in this sourcecode

				; find all func calls within this range and process as children,
				; and add to todo-list
				For $pc=$refscanstart To $refscanfinish	; scan within pass-2 func calls only

					; is call made from within our parent function? (is call's line number within its bounds?)
					If StringInStr($references[$pc][3]," call") And $references[$pc][2]>$funcdefstart And $references[$pc][2]<$funcdefinish Then
						$curchild=$references[$pc][4]	; UDF call is made from within parent func def
						$funcdexchild=_ArraySearch($functionsDefined,$curchild,1)+$startofuncs-1
						$funcdestin=StringLeft($refindex[$funcdexchild][0],StringInStr($refindex[$funcdexchild][0]," UDF:")-1)
						$destindex=_ArraySearch($includes,$funcdestin,1)

						; update incoming/outgoing calls tallies
						$refindex[$sourcedex][6]+=1				; we only get here if $sourcedex=valid, so no need to check
						If $destindex>-1 Then $refindex[$destindex][5]+=1
						If $funcdexchild>-1 Then $refindex[$funcdexchild][5]+=1	;	"incoming calls"
						If $funcdexparent>-1 Then $refindex[$funcdexparent][6]+=1	;	"outgoing calls"
						$addthischild=(_ArraySearch($includedonceaschild,$curchild,1)<1)	; by definition always filled with at least one entry

						$duplicationflag=""
						If $addthischild=False Then $duplicationflag	=$duplicatestag

						; recursion tag trumps duplication tag
						If $curparent=$curchild then $duplicationflag=$recursiontag
						If $funcdefstatus=False Then $duplicationflag  &= $unresolvedUDFtag

						; add branch
						$newbranch=$curbranch & $separator & $curchild & $duplicationflag
						If _ArraySearch($treeFunc,$newbranch,1)<1 Then
							_ArrayAdd($treeFunc,$newbranch,0,Chr(0))
							$itemsadded+=1
						EndIf
						_AddFuncAsChild($curchild)			; bookkeeping for duplication detection
					EndIf
				Next
			EndIf
		Next
		$startprocessinghere=$treeFunc[0]+1
		$treeFunc[0]=UBound($treeFunc)-1

		If $diagnostics=True Then ConsoleWrite("Building tree, nesting level " & $nestinglevel & "; items added: " & $itemsadded & @CRLF )
		Select
			Case $prevadded=$itemsadded
				$samecount+=1
			Case $prevadded>$itemsadded
				$largercount+=1
		EndSelect
		If $samecount+$largercount>100 Then
			SplashOff()
			If $runquiet=False Then
				MsgBox(262144+8192+16,"Halting execution","UDF hierarchy does not converge")
				_ArrayDisplay($treeIncl)
			EndIf
			Exit (-14)
		EndIf
	WEnd

	; copy stats
	For $rc=1 To $includes[0]
		$include_stats[$rc][5]=$refindex[$rc][5]
		$include_stats[$rc][6]=$refindex[$rc][6]
	Next

	; create lists of unique UDFs (called, calling, all)
	For $rc=$includes[0]+1 To $refindex[0][0]		; skip #include stats at top
		$curfunc=$refindex[$rc][0]
		If $refindex[$rc][6]>0 Then	; UDF has outgoing calls
			_ArrayAdd($uniquefuncsAll,$curfunc,0,Chr(0))
			_ArrayAdd($uniqueFuncsCalling,$curfunc,0,Chr(0))
		EndIf
		If $refindex[$rc][5]>0 Then	; UDF has incoming calls
			_ArrayAdd($uniquefuncsAll,$curfunc,0,Chr(0))
			_ArrayAdd($uniqueFuncsCalled,$curfunc,0,Chr(0))
			$curfunc=StringTrimLeft($curfunc,StringInStr($curfunc," UDF: ")+5)
			$index=_ArraySearch($FunctionsCalled,$curfunc,1)
			If $index<1 Then
				_ArrayAdd($FunctionsCalled,$curfunc,0,Chr(0))	; sequential, UDFs
				$index=UBound($FunctionsCalled)-1
			EndIf
		EndIf
	Next

	; create unique lists
	If UBound($uniquefuncsAll)>1 Then
		_ArrayDelete($uniquefuncsAll,0)
		_ArraySort($uniquefuncsAll)
		_ArrayUniqueFast($uniquefuncsAll,0,UBound($uniquefuncsAll)-1)
	EndIf

	If UBound($uniqueFuncsCalled)>1 Then
		_ArrayDelete($uniqueFuncsCalled,0)
		_ArraySort($uniqueFuncsCalled)
		_ArrayUniqueFast($uniqueFuncsCalled,0,UBound($uniqueFuncsCalled)-1)
	EndIf

	If UBound($uniqueFuncsCalling)>1 Then
		_ArrayDelete($uniqueFuncsCalling,0)
		_ArraySort($uniqueFuncsCalling)
		_ArrayUniqueFast($uniqueFuncsCalling,0,UBound($uniqueFuncsCalling)-1)
	EndIf

	If UBound($functionsCalled)>1 Then
		_ArrayDelete($functionsCalled,0)
		_ArraySort($functionsCalled)
		_ArrayUniqueFast($functionsCalled,0,UBound($functionsCalled)-1)
	EndIf

	; identify any redundant #includes (no incoming calls, no globals)
	For $rc=2 To $includes[0]	; no globals, no main code, and never called = dead weight (skips root file)
		If $include_stats[$rc][7]=0 And $include_stats[$rc][5]=0 And $include_stats[$rc][9]=0 Then
			$include_deadweight+=1
			$include_stats[$rc][0]=False
			_ArrayAdd($includesRedundant,$includes[$rc],0,Chr(0))

			$newproblems=$problems[0][0]+1
			ReDim $problems[$newproblems+1][6]
			$problems[0][0]=$newproblems
			$problems[$newproblems][0]=False
			$problems[$newproblems][1]=$includes[$rc]
			$problems[$newproblems][2]="<n/a>"
			$problems[$newproblems][3]="redundant #incl"
			$problems[$newproblems][4]="no globals"
			$problems[$newproblems][5]="no incoming calls, no main code"
		EndIf
	Next
	_ArraySort($includesRedundant)
	$includesRedundant[0]=UBound($includesRedundant)-1

	; collect all AU3 functions that were actually called
	_ArrayDelete($includedonceaschild,0)
   _ArrayTrim($includedonceaschild,2,1)	; remove trailing brackets
	For $rc=UBound($includedonceaschild)-1 To 0 Step -1
		If _arraysearch($AU3Functions,$includedonceaschild[$rc],1)=-1 Then _ArrayDelete($includedonceaschild,$rc)
	Next
	_ArrayConcatenate($AU3FunctionsCalled,$includedonceaschild)
	_arraysort($AU3FunctionsCalled)

	_ArrayUniqueFast($AU3FunctionsCalled,1,UBound($AU3FunctionsCalled)-1)
	If $AU3FunctionsCalled[0]=1 Then
		If $AU3FunctionsCalled[1]="" Then
			_ArrayDelete($AU3FunctionsCalled,1)
			$AU3FunctionsCalled[0]=0
		EndIf
	EndIf

	If $showprogress=True Then GUIDelete($PBhandle)

EndFunc


Func _ReportIssues()

	$procname="_ReportIssues"
	If $showprogress=True Then _
		$PBhandle=_ProgressBusy("Code Scanner: " & $trimmedroot,"Writing report" ,"Please wait...")

	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": compiling report data...")

	; generate non-native globals definition list
	If $refglobals[0][0]>0 Then
		$globaldeflist= "; CODE SCANNER List of "&$refglobals[0][0]&" non-native Globals" & @CRLF & _
			"; extracted from: " & $includes[1] & @CRLF & _
			"; on "  & @YEAR& "-" & @MON & "-" & @MDAY & ", at " & @HOUR & ":" & @MIN& ":" & @SEC & @CRLF & @CRLF
		$curinclude=""
		For $rc=1 To $refglobals[0][0]
			If $curinclude<>$refglobals[$rc][1] Then
				$curinclude=$refglobals[$rc][1]
				$globaldeflist&=@CRLF & "; Source file: " &$curinclude &@CRLF
			EndIf
			$index=_arraysearch($globalsinFuncs,$refglobals[$rc][4],0,0,0,0,1,4)
			If $index<1 Then
				$globaldeflist&="Global " & $refglobals[$rc][4] & @TAB & " ; line " & $refglobals[$rc][2] & @CRLF
			Else
				$globaldeflist&="Global " & $refglobals[$rc][4] & @TAB & " ; line " & $refglobals[$rc][2] & ", within func def: " &$globalsinFuncs[$index][3]& @CRLF
			EndIf
		Next
	EndIf

	; create stats for TreeviewMenu
	Global $stats="Root File: " & $includes[1] & @CRLF
	$stats&="Processing time: " & Round(TimerDiff($tstart)*.001,1) & " seconds" & @CRLF & @CRLF	; rootfile = includes[1]
	$stats&="Number of incorporated Includes: " & $includes[0]-1 & @CRLF	; rootfile = includes[1]
	$stats&="Number of Lines processed: " & $totalines & @CRLF
	$stats&="Number of unique native AutoIt functions: " & $AU3FunctionsUsed[0] & @CRLF
	$stats&="Number of unique native AutoIt functions Called: " & $AU3FunctionsCalled[0] & @CRLF
	$stats&="Number of UDF definitions: " & $functionsDefined[0] & @CRLF
	$stats&="Number of Active UDFs: " & $uniquefuncsAll[0] & @CRLF
	$stats&="Number of Calls: " & $totalcalls & @CRLF
	$stats&="Number of Variables: " & $variablesUsed[0] & @CRLF
	$stats&="Number of Globals: " & $globals[0] & @CRLF
	$stats&="Number of UDFonly-defined Globals: " & $globalsinFuncs[0][0] & @CRLF
	$stats&="Number of Loops: " & $loop_ID & @CRLF
	$stats&="Number of Main Code Sections: " & $mainCodeSections[0][0] & @CRLF
	$stats&="Number of Exit points: " & $Exitpoints[0][0] & @CRLF & @CRLF& @CRLF

	Global $settingslist="Settings" & @CRLF
	If $includeConstants=True Then
		$settingslist&="ON : Include native [...]Constants.au3 files"  & @CRLF
	Else
		$settingslist&="OFF: Include native [...]Constants.au3 files"  & @CRLF
	EndIf
	If $TrackAU3Calls=True Then
		$settingslist&="ON : Track native AutoIt function calls" & @CRLF
	Else
		$settingslist&="OFF: Track native AutoIt function calls" & @CRLF
	EndIf
	If $TrackUDFCalls=True Then
		$settingslist&="ON : Track UDF function calls" & @CRLF
	Else
		$settingslist&="OFF: Track UDF function calls" & @CRLF
	EndIf
	If $TrackLoops=True Then
		$settingslist&="ON : Track loop structures" & @CRLF
	Else
		$settingslist&="OFF: Track loop structures" & @CRLF
	EndIf
	If $ExtractVars=True Then
		$settingslist&="ON : Extract variable names" & @CRLF
	Else
		$settingslist&="OFF: Extract variable names" & @CRLF
	EndIf
	If $ExtractStrings=True Then
		$settingslist&="ON : Extract literal strings" & @CRLF
	Else
		$settingslist&="OFF: Extract literal strings" & @CRLF
	EndIf
	If $ExtractMacros=True Then
		$settingslist&="ON : Extract macros" & @CRLF
	Else
		$settingslist&="OFF: Extract macros" & @CRLF
	EndIf
	$settingslist&= @CRLF & @CRLF

	; create list of potential issues
	Global $report=""
	$report&= "____________" & @CRLF &  "CODE SCANNER Start of Report" & @CRLF & @CRLF
	$report&= "Analysis of: " & $rootfile & @CRLF & "on "  & @YEAR& "-" & @MON & "-" & @MDAY & ", at " & @HOUR & ":" & @MIN& ":" & @SEC & @CRLF & @CRLF

	$report&= $settingslist

	If $problems[0][0]>0 Then
		$stats2="Number of *potential* issues: " & $problems[0][0] & @CRLF & @CRLF
		$stats2&="Number of #includes not found: " & $include_notfound & @CRLF
		$stats2&="Number of redundant #includes: " & $include_deadweight & @CRLF
		$stats2&="Number of duplicate func defs: " & $func_duplicated & @CRLF
		$stats2&="Number of unresolved func parameters: " & $func_paramsunresolved & @CRLF
		$stats2&="Number of unknown functions called: " & $unknownUDFs[0] & @CRLF
		$stats2&="Number of Loop nesting issues: " & $loopmismatch +$loopmissingparams & @CRLF& @CRLF& @CRLF
		$stats&=$stats2
		$report&=$stats2

		If $include_notfound>0 then
			$report&= "Includes not found: " & @CRLF
			For $rc=1 To $problems[0][0]
				If $problems[$rc][3]="#include" Then $report&= ("source file: " & $problems[$rc][1] & _
					" line: " & $problems[$rc][2] & "; reference: " & @CRLF & $problems[$rc][4] & @CRLF& @CRLF)
			Next
		EndIf

		If $include_deadweight>0 Then
			$marked=False
			$report&= "Possibly redundant #includes (no globals, no incoming calls, no main code): " & @CRLF & @CRLF
			For $rc=1 To $problems[0][0]
				If $problems[$rc][3]="redundant #incl" Then
					$curinclude=$problems[$rc][1]
					$inroot=False
					$inincludes=False
					$found_in="Found in: " & @CRLF
					For $cc=1 To $references[0][0]	; mark with * if in rootfile only (safe to delete)
						If $references[$cc][3]="#include" And $references[$cc][4]=$curinclude Then
							If $references[$cc][1]=$includes[1] Then
								$inroot=True
							Else
								$inincludes=True
							EndIf
							$found_in&=@TAB & $references[$cc][1] & ", line: " & $references[$cc][2] & @CRLF
						EndIf
					Next
					$marker=""
					If $inroot=True And $inincludes=False Then
						$marker="* "
						$marked=True
					EndIf
					$report&= $marker & $curinclude & @CRLF &$found_in & @CRLF
				EndIf
			Next
			If $marked=True Then $report&= "* = occurs in root file only; can safely be removed"
		EndIf

		Global $dupes[1]
		If $func_duplicated>0 then

			$report&= @CRLF&@CRLF& @CRLF & "Duplicate func defs: " & @CRLF& @CRLF
			For $rc=1 To $problems[0][0]
				If $problems[$rc][3]="func def" Then _ArrayAdd($dupes,$problems[$rc][4],0,Chr(0))
			Next
			_ArrayUniqueFast($dupes,0,UBound($dupes)-1)	; first reduce
			$dupes[0]=""
			_ArraySort($dupes)				; then sort remainder
			$dupes[0]=UBound($dupes)-1

			For $cc=1 To $dupes[0]
				If $dupes[$cc]="" Then ContinueLoop
				$report&=$dupes[$cc] & @CRLF
				For $rc=1 To $problems[0][0]
					If $problems[$rc][3]="func def" And $problems[$rc][4]=$dupes[$cc] Then _
						$report&= "defined in source file: " & $problems[$rc][1] & " line: " & $problems[$rc][2] &  _
								";" & @CRLF & "Func def: " & $problems[$rc][4] & ", parameters: " & $problems[$rc][5] & @CRLF & @CRLF
				Next
				$report&="Calls made:" & @CRLF
				$callsmade=0
				$startat=_ArraySearch($references,$dupes[$cc],1,0,0,0,1,4)
				While $startat>0
					$report&= @TAB & "in source file: " & $references[$startat][1] & " line: " & $references[$startat][2] &  _
								";" & @CRLF & @TAB & "parameters: " & $references[$startat][5] & @CRLF & @CRLF
					$callsmade+=1
					$startat=_ArraySearch($references,$dupes[$cc],$startat+1,0,0,0,1,4)
				WEnd
				If $callsmade=0 Then $report&= "<none>" &@CRLF
			Next
			$report&= @CRLF

		Else
			$dupes[0]=0
		EndIf

		If $func_paramsunresolved>0 then
			$report&= @CRLF& @CRLF & "Unresolved func parameters: " & @CRLF& @CRLF
			For $rc=1 To $problems[0][0]
				If StringTrimLeft($problems[$rc][3],3)=" call" Then $report&= "source file: " & $problems[$rc][1] & _
					" line: " & $problems[$rc][2] & ";" & @CRLF & "func call: " & $problems[$rc][4] & ", parameters: " & $problems[$rc][5] & @CRLF & @CRLF
			Next
		EndIf

		If $unknownUDFs[0]>0 then
			$report&= @CRLF& @CRLF & "Undefined functions called: " & @CRLF& @CRLF
			For $rc=1 To $problems[0][0]
				If $problems[$rc][3]=$func_unknown_tag Then $report&= "source file: " & $problems[$rc][1] & _
					" line: " & $problems[$rc][2] & ";" & @CRLF & "func call: " & $problems[$rc][4] & ", parameters: " & $problems[$rc][5] & @CRLF & @CRLF
			Next
		EndIf

		If $loopmismatch+$loopmissingparams>0 Then
			$report&= @CRLF& @CRLF & "Regarding Loops:"& @CRLF
			$report&= "Number of mismatched pairs of Loop commands: " & $loopmismatch	& @CRLF
			$report&= "Number of Loop commands without parameters: " & $loopmissingparams	& @CRLF
			$report&= "Loop statements with issues (see array Loops for details):" & @CRLF
			For $rc=1 To $loops[0][0]
				$report&= "source file: " & $loops[$rc][1] & _
					" line: " & $loops[$rc][2] & ";" & @CRLF & $loops[$rc][3] & ": " &$loops[$rc][4] & @CRLF
			Next
			$report&= @CRLF & @CRLF
		EndIf

	Else
		$report&= @CRLF & "Congratulations! No issues detected." & @CRLF
		$stats&="Congratulations! No issues detected." & @CRLF

		ReDim $problems[2][6]
		$problems[1][1]="No problemo"

	EndIf
	If $WriteMetaCodeFail=True Then $stats&= @CRLF & "Note: Writing out metacode files has failed due to a file I/O error." & @CRLF
	$stats&= @CRLF & "Activate the Report Summary for additional information." & @CRLF

	$no_funcdef_or_incl=0
	$lst1=""
	For $rc=1 To $includes[0]
		If $refindex[$rc][1]=0 Then		; nothing found = no line refs
			$no_funcdef_or_incl+=1
			$lst1 &= $refindex[$rc][0] & @CRLF
		EndIf
	Next

	$no_funcalls=0
	$lst2=""
	For $rc=1 To $includes[0]
		If $refindex[$rc][3]=0 Then		; nothing found = no line refs
			$no_funcalls+=1
			$lst2 &= $refindex[$rc][0] & @CRLF
		EndIf
	Next

	$report&= @CRLF & @CRLF & "Some additional observations (provided for info only):" & @CRLF & @CRLF

	If $trueFirstEntrypoint>0 Then
		$report&="Main code starts here:" & @CRLF
		$report&= $Entrypoints[$trueFirstEntrypoint][1] & ", line " & $Entrypoints[$trueFirstEntrypoint][2] & ": " & $Entrypoints[$trueFirstEntrypoint][5] & @CRLF
		If $Entrypoints[$trueFirstEntrypoint][1]<>$includes[1] Then _
			$report&= @CRLF & "WARNING: this Entry point is located OUTSIDE the root file." & @CRLF
	Else
		$report&= "WARNING: No unambiguous Entry point could be determined." & @CRLF
	EndIf
	$report&= @CRLF

	if $no_funcdef_or_incl=0 Then
		$report&= "All #included files contain at least one UDF definition or #include."
	Else
		$report&= "The following independent #include(s) contain(s) no UDF definition or #include:" & @CRLF & @CRLF & $lst1
	EndIf
	$report&= @CRLF

	if $no_funcalls=0 Then
		$report&= "All #included files contain at least one UDF call."
	Else
		$report&= "The following independent #include(s) contain(s) no UDF calls:" & @CRLF & @CRLF & $lst2
	EndIf
	$report&= @CRLF

	If $globalsinFuncs[0][0]=0 Then
		$report&= "All globals are defined at least once outside UDFs."
	Else
		$report&= @CRLF & @CRLF & "Not all Globals are defined outside UDFs." & @CRLF
		$report&= "To fix this, generate the ""Globals, non-native, with refs"" Text file," & @CRLF
		$report&= "edit/save it, then add it as an #include in your root file." & @CRLF & @CRLF
		$report&= @CRLF & @CRLF & "The following globals are defined only within UDFs:" & @CRLF & @CRLF

		For $rc=1 To $globalsinFuncs[0][0]
			$report&=$globalsinFuncs[$rc][4] &", in " & _
						$globalsinFuncs[$rc][1] &", line: " & _
						$globalsinFuncs[$rc][2] &", UDF: " & _
						$globalsinFuncs[$rc][3]	& @CRLF
		Next
	EndIf
	$report&= @CRLF

	$rootimplicitexit=False
	$implicitexits=0
	$implist=""
	$marked=False
	$lastexit=$Exitpoints[0][0]
	For $rc=1 To $lastexit
		If $Exitpoints[$rc][4]=$lastmainlinetag Then
			$implicitexits+=1
			$marker="  "
			If $Exitpoints[$rc][0]=False Then
				$marked=true
				$marker="* "
			EndIf
			$implist&=$marker & $Exitpoints[$rc][1] & ", line " & $Exitpoints[$rc][2] & ": " & $Exitpoints[$rc][5] & @CRLF
			If $Exitpoints[$rc][1]=$includes[1] Then $rootimplicitexit=True
		EndIf
	Next
	If $marked=True Then $implist&=@CRLF & $marker & " = NOT in root file" & @CRLF

	If $rootimplicitexit=True Then	; not found
		$report&= "Last line of main code does NOT contain an explicit ""Exit"" command."
	Else
		$report&= "Last line of main code contains an explicit ""Exit"" command."
	EndIf
	$report&= @CRLF & @CRLF

	If $implicitexits>0 Then _
		$report&= "Number of implicit Exit lines found: " & $implicitexits & @CRLF  & @CRLF & $implist & @CRLF

	$report&= @CRLF & "CODE SCANNER End of Report" & @CRLF & "____________" & @CRLF
	If $showprogress=True Then GUIDelete($PBhandle)

	; store report in logfile if latter is enabled
	If $uselogfile Then _FileWriteLog($fhlog,$procname & ": report data compiled." & @CRLF & @CRLF & $report & @CRLF & @CRLF)

EndFunc

#region	Code Analysis

#region	Utilities

Func _FillAutoItFuncs()
; this list contains all language items to be skipped in UDF analysis when they immediately precede "("

   Local $sFileRead = FileRead(StringLeft($AutoItIncludeFolder,StringInStr($AutoItIncludeFolder,"\",0,-2)) & 'SciTE\api\au3.api')

	Global $AU3Functions=0
   Local  $sFunctions = ''
   __ParseAPI($sFileRead, $AU3Functions, $sFunctions, 'Functions', '(?m:^((?!_)\w+)\s+\()')

   Local $aKeywords = 0
	Local  $sKeywords = ''
   __ParseAPI($sFileRead, $aKeywords, $sKeywords, 'Keywords', '(?m:^(\w+)\?4)')

   Global $Macros = 0
	Local $sMacros=''
	__ParseAPI($sFileRead, $Macros, $sMacros, 'Macros', '(?m:^(@\w+)\?3)')

	; only the leftmost character of operators is stored
	Global $AU3operators[1]
	_ArrayAdd($AU3operators,"=",0,Chr(0))
	_ArrayAdd($AU3operators,">",0,Chr(0))
	_ArrayAdd($AU3operators,"<",0,Chr(0))
	_ArrayAdd($AU3operators,"+",0,Chr(0))
	_ArrayAdd($AU3operators,"-",0,Chr(0))
	_ArrayAdd($AU3operators,"*",0,Chr(0))
	_ArrayAdd($AU3operators,"/",0,Chr(0))
	_ArrayAdd($AU3operators,"^",0,Chr(0))
	_ArrayAdd($AU3operators,",",0,Chr(0))
	_ArrayAdd($AU3operators,"(",0,Chr(0))
	_ArrayAdd($AU3operators,"[",0,Chr(0))
	_ArrayAdd($AU3operators,"^",0,Chr(0))
	_ArrayAdd($AU3operators,"{",0,Chr(0))	; in regexp
	_ArrayAdd($AU3operators,"}",0,Chr(0))	; in regexp
	_ArrayAdd($AU3operators,")",0,Chr(0))	; in regexp
	_ArrayAdd($AU3operators,"]",0,Chr(0))	; in regexp
	_ArrayAdd($AU3operators,"|",0,Chr(0))	; in regexp
	_ArrayAdd($AU3operators,"\",0,Chr(0))	; in regexp
	_ArrayAdd($AU3operators,"?",0,Chr(0))
	_ArrayAdd($AU3operators,":",0,Chr(0))	; in ternary
	_ArrayAdd($AU3operators,"&",0,Chr(0))
	_ArrayAdd($AU3operators,"Not",0,Chr(0))	; these operators require a prior space separator
	_ArrayAdd($AU3operators,"Or",0,Chr(0))
	_ArrayAdd($AU3operators,"And",0,Chr(0))
	_ArrayAdd($AU3operators,"Enum",0,Chr(0))	; special case (strictly speaking not an operator)
	_ArrayConcatenate($AU3operators,$aKeywords,1)
	$AU3operators[0]=UBound($AU3operators)-1

	_ValidPrefix()	; moved to MCF #include

EndFunc


Func _GetAutoItIncludeFolder($checkdefaultsfirst=True)	; with improvements by AZJIO and BrewmanNH

	$newAutoItIncludeFolder=""
	If $checkdefaultsfirst=True Then
		; default location; edit (here or in INI file) if needed to avoid the following path query
		$newAutoItIncludeFolder=_GetAutoItPath() & "\Include\"	; AZJIO's UDF
		$fh=FileFindFirstFile($newAutoItIncludeFolder & "*.au3")
	Else
		$fh=-1	; trigger folderselect
	EndIf

	If @error Or $fh=-1 Then
		; using CLSID for My Computer, as suggested by BrewmanNH
		$newAutoItIncludeFolder=FileSelectFolder("CODE SCANNER: Please identify the AutoIt Include folder","::{20D04FE0-3AEA-1069-A2D8-08002B30309D}")
		If @error Or $newAutoItIncludeFolder="" Then
			If $runquiet=False Then MsgBox(262144+8192+48,"Unable to proceed","No valid |AutoIt Include directory selected",5)
			Return False
		EndIf
		$fh=FileFindFirstFile($newAutoItIncludeFolder & "\*.au3")
		If @error Or $fh=-1 Then
			If $runquiet=False Then MsgBox(262144+8192+48,"Unable to proceed","Problem accessing AutoIt Include directory " & $AutoItIncludeFolder,5)
			Return False
		EndIf
	EndIf

	Global $AutoItIncludeFolder=$newAutoItIncludeFolder
	If $AutoItIncludeFolder="" Then Return False

	If $diagnostics=True Then ConsoleWrite("Autoit Include folder: " & $AutoItIncludeFolder & @CR)
	Return True

EndFunc


Func _ReadIniFile()

	$section="Booleans"

	; process INI section
	Global $INIvars = IniReadSection($inifile, $section)
	If Not @error Then
		For $rc=1 To $INIvars[0][0]
			If $INIvars[$rc][1]="True" Or $INIvars[$rc][1]="False" Then
				If IsDeclared($INIvars[$rc][0]) Then Assign($INIvars[$rc][0],($INIvars[$rc][1]="True"),4)
			EndIf
		Next
		Global $TrackCalls=($TrackAU3Calls Or $TrackUDFCalls)
	EndIf

	; process INI section
	$section="Paths"
	$pathvars = IniReadSection($inifile, $section)
	If Not @error Then
		For $rc=1 To $pathvars[0][0]
			If FileExists($pathvars[$rc][1] & ".") And IsDeclared($pathvars[$rc][0]) Then _
				Assign($pathvars[$rc][0],$pathvars[$rc][1],4)
		Next
	EndIf

	If $AutoItIncludeFolder="" Or Not FileExists($AutoItIncludeFolder & ".") Then
		If _GetAutoItIncludeFolder(True)=False Then
			If $runquiet=False Then MsgBox(262144+8192+16,"Fatal Error","No valid AutoIt Include directory defined",8)
			Exit (-15)
		EndIf
	EndIf

	_WriteIniFile()

EndFunc


Func _WriteIniFile()

	; redefined because INI contents may differ between codescanner versions
	Global $INIvars[17][2]
	$INIvars[1][0]="UnicodeSupport"
	$INIvars[2][0]="IncludeConstants"
	$INIvars[3][0]="TrackAU3Calls"
	$INIvars[4][0]="TrackUDFCalls"
	$INIvars[5][0]="TrackLoops"
	$INIvars[6][0]="ExtractVars"
	$INIvars[7][0]="ExtractStrings"
	$INIvars[8][0]="ExtractMacros"
	$INIvars[9][0]="WriteMetaCode"
	$INIvars[10][0]="ShowProgress"
	$INIvars[11][0]="ShowResultsBySubject"
	$INIvars[12][0]="ShowResultsByFormat"
	$INIvars[13][0]="ShowMetaCode"
	$INIvars[14][0]="ShowFirstDuplication"
	$INIvars[15][0]="ShowAU3native"
	$INIvars[16][0]="Diagnostics"

	$INIvars[1][1]=$UnicodeSupport	; if first index is changed, also alter getnextlineASCII
	$INIvars[2][1]=$includeConstants
	$INIvars[3][1]=$TrackAU3Calls
	$INIvars[4][1]=$TrackUDFCalls
	$INIvars[5][1]=$TrackLoops
	$INIvars[6][1]=$ExtractVars
	$INIvars[7][1]=$ExtractStrings
	$INIvars[8][1]=$ExtractMacros
	$INIvars[9][1]=$WriteMetaCode
	$INIvars[10][1]=$showprogress
	$INIvars[11][1]=$showResultsBySubject
	$INIvars[12][1]=$showResultsByFormat
	$INIvars[13][1]=$showMetaCode
	$INIvars[14][1]=$showfirstduplication
	$INIvars[15][1]=$ShowAU3native
	$INIvars[16][1]=$diagnostics

	$INIvars[0][0]=UBound($INIvars)-1

	$section="Booleans"
	IniWriteSection($inifile,$section,$INIvars)

	; always written out again
	Global $pathvars[2][2]
	$pathvars[1][0]="AutoItIncludeFolder"	; default location for language-native <includes>
	$pathvars[1][1]=$AutoItIncludeFolder
	$pathvars[0][0]=UBound($INIvars)-1

	$section="Paths"
	IniWriteSection($inifile,$section,$pathvars)

EndFunc


Func _PrepGlobals()		; these globals are to be reset for every (re)scan

	; strings
	Global $report="Report not (yet) generated."
	Global $stats="Stats not (yet) generated."
	Global $settingslist="Settings List not (yet) generated."
	Global $newfunc="<undefined>"
	Global $trimmedfname="<undefined>"
	Global $globaldeflist="<undefined>"

	; counters, etc
	Global $filecount=0
	Global $pairs=0
	Global $startofuncs=0
	Global $totalines=0
	Global $totalcalls=0
	Global $sourcedex=0
	Global $truelinecount=0
	Global $addlines=0
	Global $include_notfound=0
	Global $include_deadweight=0
	Global $func_duplicated=0
	Global $func_paramsunresolved=0
	Global $stringcounter=0
	Global $loopmismatch=0
	Global $loopmissingparams=0
	Global $loop_ID=0
	Global $trueFirstEntrypoint=-1
	Global $WriteMetaCodeFail=False

	; arrays
	Global $stringsUsed[1]
	Global $stringsUsedSorted[1]
	Global $variableIsArray[1]
	Global $variablesUsed[1]
	Global $variablesUsedsorted[1]
	Global $AU3FunctionsUsed[1]	; found in main code or any UDF (not necessarily called)
	Global $AU3FunctionsCalled[1]	; called in main code or any Called UDF
	Global $FunctionsDefined[1]
	Global $FunctionsCalled[1]
	Global $FunctionsUsed[1]
	Global $macrosUsed[1]
	Global $MCinFuncDef[1]
	Global $dupes[1]
	Global $includes[2]		; root file = includes[1]
	Global $myincludes[2]	; root file = myincludes[1]
	Global $includeonce[1]
	Global $includesRedundant[1]
	Global $incl_notfound[1]
	Global $unknownUDFs[1]
	Global $include_lines[1]
	Global $globals[1]
	Global $globalsRedundant[1]
	Global $newglobals[1]
	Global $globalglobals[1]
	Global $internalfuncs[1]
	Global $uniquefuncsAll[1]
	Global $uniqueFuncsCalling[1]
	Global $uniqueFuncsCalled[1]
	Global $treeIncl[1]
	Global $treeFunc[1]

	$stringsUsed[0]=0
	$stringsUsedSorted[0]=0
	$variableIsArray[0]=0
	$variablesUsed[0]=0
	$variablesUsedSorted[0]=0
	$AU3FunctionsUsed[0]=0
	$AU3FunctionsCalled[0]=0
	$FunctionsCalled[0]=0
	$FunctionsDefined[0]=0
	$FunctionsUsed[0]=0
	$macrosUsed[0]=0
	$dupes[0]=1
	$includes[0]=1
	$MCinFuncDef[0]=0
	$myincludes[0]=1
	$includeonce[0]=0
	$includesRedundant[0]=0
	$incl_notfound[0]=0
	$unknownUDFs[0]=0
	$include_lines[0]=0
	$globals[0]=0
	$globalsRedundant[0]=0
	$newglobals[0]=0
	$globalglobals[0]=0
	$internalfuncs[0]=0
	$uniquefuncsAll[0]=0
	$uniqueFuncsCalling[0]=0
	$uniqueFuncsCalled[0]=0
	$treeIncl[0]=0
	$treeFunc[0]=0

	; 2-D arrays with predefined headers
	Global $mainCodeSections[1][5]	; continuous sections of code other than globals, #includes, and UDF definitions
	Global $references[1][6]		; main internal data storage for all types of tracked tags
	Global $globalsinFuncs[1][5]
	Global $include_stats[1][11]
	Global $refindex[1][7]

	_ArrayHeaders()	; fills row-zero variable names for 2-D arrays; do this before copying $references[][]

	Global $refglobals	=$references
	Global $problems		=$references
	Global $loops			=$references
	Global $Entrypoints	=$references
	Global $Exitpoints	=$references

EndFunc


Func _WriteCSDataDump($fulldump=true)

	If Not FileExists($rootpath & ".") Then
		If $runquiet=True Then Exit (-16)
		MsgBox(262144+8192+48,"Unable to proceed","Path not found: " & @CR & $rootpath,8)
		Return
	EndIf

	; create/clear dump subdir
	If Not FileExists($CS_dumppath & ".") Then
		If DirCreate($CS_dumppath)=0 Then
			If $runquiet=True Then Exit(-18)
			MsgBox(262144+8192+48,"Unable to proceed","Unable to create subdirectory:" & @CR & $CS_dumppath,8)
			Return
		EndIf
	EndIf

	If $ShowProgress=True Then _
		$PBhandle=_ProgressBusy("Code Scanner: " & $trimmedroot,"Writing Data" ,"Please wait...")

	; create readme.txt
	$dumptag ="; CODE SCANNER Output" & @CRLF & ";" & @CRLF
	$dumptag&="; Source Language: AutoIt" & @CRLF
	$dumptag&="; Extracted from : " & $includes[1] & @CRLF
	$dumptag&="; on             : "  & @YEAR& "-" & @MON & "-" & @MDAY & ", at " & @HOUR & ":" & @MIN& ":" & @SEC & @CRLF
	$dumptag&="; CodeScanner was itself running AutoIt version: " & @AutoItVersion & @CRLF & ";" & @CRLF
	$dumptag&="; {file#}   = $includes[#]" & @CRLF
	$dumptag&="; {funcA#}  = $AU3Functions[#]  (complete set)" & @CRLF
	$dumptag&="; {funcU#}  = $functionsUsed[#] (active subset = $functionsCalled[])" & @CRLF
	$dumptag&="; {incl#}   = $includes[#]      (complete set)" & @CRLF
	$dumptag&="; {macro#}  = $macros[#]        (complete set)" & @CRLF
	$dumptag&="; {string#} = $stringsUsed[#]" & @CRLF
	$dumptag&="; {ref#}    = $references[#]" & @CRLF
	$dumptag&="; {var#}    = $variablesUsed[#]" & @CRLF

	$readmefile=$CS_dumppath & "readme.txt"
	If FileExists($readmefile) Then FileDelete($readmefile)
	FileWrite($readmefile,$dumptag & $settingslist & @CRLF)

	If $fulldump=True Then
		FileWrite($CS_dumppath & "report.txt",$report)
		FileWrite($CS_dumppath & "globaldefs.au3",$globaldeflist)

		; dump 2-D arrays
		_FileWriteFromArray2D($CS_dumppath & "entrypoints.txt",$Entrypoints)
		_FileWriteFromArray2D($CS_dumppath & "exitpoints.txt",$Exitpoints)
		_FileWriteFromArray2D($CS_dumppath & "globalsinFuncs.txt",$globalsinFuncs)
		_FileWriteFromArray2D($CS_dumppath & "include_stats.txt",$include_stats)
		_FileWriteFromArray2D($CS_dumppath & "loops.txt",$loops)
		_FileWriteFromArray2D($CS_dumppath & "mainCodeSections.txt",$mainCodeSections)
		_FileWriteFromArray2D($CS_dumppath & "problems.txt",$problems)
		_FileWriteFromArray2D($CS_dumppath & "references.txt",$references)
		_FileWriteFromArray2D($CS_dumppath & "refGlobals.txt",$refglobals)
		_FileWriteFromArray2D($CS_dumppath & "refIndex.txt",$refindex)

		; dump 1-D arrays
		_FileWriteFromArray($CS_dumppath & "AU3Functions.txt",$AU3Functions,1)					; total language
		_FileWriteFromArray($CS_dumppath & "AU3FunctionsCalled.txt",$AU3FunctionsCalled,1)	; active calls
		_FileWriteFromArray($CS_dumppath & "AU3FunctionsUsed.txt",$AU3FunctionsUsed,1)		; occurring anywhere, may be inactive
		_FileWriteFromArray($CS_dumppath & "dupes.txt",$dupes,1)
		_FileWriteFromArray($CS_dumppath & "FunctionsCalled.txt",$FunctionsCalled,1)			; may be edited later
		_FileWriteFromArray($CS_dumppath & "FunctionsCalled_CS.txt",$FunctionsCalled,1)		; fixed CS output
		_FileWriteFromArray($CS_dumppath & "FunctionsDefined.txt",$FunctionsDefined,1)		; fixed CS output
		_FileWriteFromArray($CS_dumppath & "FunctionsUsed.txt",$FunctionsUsed,1)				; may be edited later
		_FileWriteFromArray($CS_dumppath & "FunctionsUsed_CS.txt",$FunctionsUsed,1)			; fixed CS output
		_FileWriteFromArray($CS_dumppath & "globals.txt",$globals,1)
		_FileWriteFromArray($CS_dumppath & "globalsRedundant.txt",$globalsRedundant,1)
		_FileWriteFromArray($CS_dumppath & "incl_notfound.txt",$incl_notfound,1)
		_FileWriteFromArray($CS_dumppath & "includeOnce.txt",$includeonce,1)
		_FileWriteFromArray($CS_dumppath & "includes.txt",$includes,1)
		_FileWriteFromArray($CS_dumppath & "includesRedundant.txt",$includesRedundant,1)
		_FileWriteFromArray($CS_dumppath & "macros.txt",$macros,1)
		_FileWriteFromArray($CS_dumppath & "macrosUsed.txt",$macrosUsed,1)
		_FileWriteFromArray($CS_dumppath & "macrosUsed_CS.txt",$macrosUsed,1)
		_FileWriteFromArray($CS_dumppath & "MCinFuncDef.txt",$MCinFuncDef,1)
		_FileWriteFromArray($CS_dumppath & "myIncludes.txt",$myincludes,1)
		_FileWriteFromArray($CS_dumppath & "stringsUsed.txt",$stringsUsed,1)						; may be edited later
		_FileWriteFromArray($CS_dumppath & "stringsUsed_CS.txt",$stringsUsed,1)					; fixed CS output
		_FileWriteFromArray($CS_dumppath & "stringsUsedSorted.txt",$stringsUsedsorted,1)
		_FileWriteFromArray($CS_dumppath & "treefunc.txt",$treeFunc,1)
		_FileWriteFromArray($CS_dumppath & "treeincl.txt",$treeIncl,1)
		_FileWriteFromArray($CS_dumppath & "uniqueFuncsAll.txt",$uniquefuncsAll,1)
		_FileWriteFromArray($CS_dumppath & "uniqueFuncsCalled.txt",$uniqueFuncsCalled,1)
		_FileWriteFromArray($CS_dumppath & "uniqueFuncsCalling.txt",$uniqueFuncsCalling,1)
		_FileWriteFromArray($CS_dumppath & "unknownUDFs.txt",$unknownUDFs,1)
		_FileWriteFromArray($CS_dumppath & "variableIsArray.txt",$variableIsArray,1)
		_FileWriteFromArray($CS_dumppath & "variablesUsed.txt",$variablesUsed,1)				; may be edited later
		_FileWriteFromArray($CS_dumppath & "variablesUsed_CS.txt",$variablesUsed,1)			; fixed CS output
		_FileWriteFromArray($CS_dumppath & "variablesUsedSorted.txt",$variablesUsedsorted,1)

		Local $filelist[44]
		$filelist[1]="entrypoints.txt"
		$filelist[2]="exitpoints.txt"
		$filelist[3]="globalsinFuncs.txt"
		$filelist[4]="include_stats.txt"
		$filelist[5]="loops.txt"
		$filelist[6]="mainCodeSections.txt"
		$filelist[7]="problems.txt"
		$filelist[8]="references.txt"
		$filelist[9]="refGlobals.txt"
		$filelist[10]="refIndex.txt"

		$filelist[11]="AU3Functions.txt"
		$filelist[12]="AU3FunctionsCalled.txt"
		$filelist[13]="AU3FunctionsUsed.txt"
		$filelist[14]="dupes.txt"
		$filelist[15]="FunctionsCalled.txt"
		$filelist[16]="FunctionsCalled_CS.txt"
		$filelist[17]="FunctionsDefined.txt"
		$filelist[18]="FunctionsUsed.txt"
		$filelist[19]="FunctionsUsed_CS.txt"
		$filelist[20]="globals.txt"
		$filelist[21]="globalsRedundant.txt"
		$filelist[22]="incl_notfound.txt"
		$filelist[23]="includeOnce.txt"
		$filelist[24]="includes.txt"
		$filelist[25]="includesRedundant.txt"
		$filelist[26]="macros.txt"
		$filelist[27]="macrosUsed.txt"
		$filelist[28]="macrosUsed_CS.txt"
		$filelist[29]="MCinFuncDef.txt"
		$filelist[30]="myIncludes.txt"
		$filelist[31]="stringsUsed.txt"
		$filelist[32]="stringsUsed_CS.txt"
		$filelist[33]="stringsUsedSorted.txt"
		$filelist[34]="treefunc.txt"
		$filelist[35]="treeincl.txt"
		$filelist[36]="uniqueFuncsAll.txt"
		$filelist[37]="uniqueFuncsCalled.txt"
		$filelist[38]="uniqueFuncsCalling.txt"
		$filelist[39]="unknownUDFs.txt"
		$filelist[40]="variableIsArray.txt"
		$filelist[41]="variablesUsed.txt"
		$filelist[42]="variablesUsed_CS.txt"
		$filelist[43]="variablesUsedSorted.txt"
		$filelist[0]=UBound($filelist)-1

		; all files HAVE to exist, but may be empty
		For $rc=1 To $filelist[0]
			$curfile=$CS_dumppath & $filelist[$rc]
			If Not FileExists($curfile) Then _FileCreate($curfile)
		Next

	Else	; mini dump for MetaCode processing

		_FileWriteFromArray2D($CS_dumppath & "references.txt",$references)

		_FileWriteFromArray($CS_dumppath & "AU3Functions.txt",$AU3functions,1)
		_FileWriteFromArray($CS_dumppath & "AU3operators.txt",$AU3operators,1)
		_FileWriteFromArray($CS_dumppath & "FunctionsCalled.txt",$FunctionsCalled,1)
		_FileWriteFromArray($CS_dumppath & "FunctionsCalled_CS.txt",$FunctionsCalled,1)
		_FileWriteFromArray($CS_dumppath & "FunctionsUsed.txt",$FunctionsUsed,1)
		_FileWriteFromArray($CS_dumppath & "FunctionsUsed_CS.txt",$FunctionsUsed,1)
		_FileWriteFromArray($CS_dumppath & "globalsRedundant.txt",$globalsRedundant,1)
		_FileWriteFromArray($CS_dumppath & "includeOnce.txt",$includeonce,1)
		_FileWriteFromArray($CS_dumppath & "includes.txt",$includes,1)
		_FileWriteFromArray($CS_dumppath & "macros.txt",$macros,1)
		_FileWriteFromArray($CS_dumppath & "macrosUsed.txt",$macrosUsed,1)
		_FileWriteFromArray($CS_dumppath & "macrosUsed_CS.txt",$macrosUsed,1)
		_FileWriteFromArray($CS_dumppath & "MCinFuncDef.txt",$MCinFuncDef,1)
		_FileWriteFromArray($CS_dumppath & "stringsUsed.txt",$stringsUsed,1)
		_FileWriteFromArray($CS_dumppath & "stringsUsed_CS.txt",$stringsUsed,1)
		_FileWriteFromArray($CS_dumppath & "treeincl.txt",$treeIncl,1)
		_FileWriteFromArray($CS_dumppath & "uniqueFuncsAll.txt",$uniquefuncsAll,1)
		_FileWriteFromArray($CS_dumppath & "variablesUsed.txt",$variablesUsed,1)
		_FileWriteFromArray($CS_dumppath & "variablesUsed_CS.txt",$variablesUsed,1)

		Local $filelist[21]
		$filelist[1]="references.txt"
		$filelist[2]="AU3Functions.txt"
		$filelist[3]="AU3operators.txt"
		$filelist[4]="FunctionsCalled.txt"
		$filelist[5]="FunctionsCalled_CS.txt"
		$filelist[6]="FunctionsUsed.txt"
		$filelist[7]="FunctionsUsed_CS.txt"
		$filelist[8]="globalsRedundant.txt"
		$filelist[9]="includeOnce.txt"
		$filelist[10]="includes.txt"
		$filelist[11]="macros.txt"
		$filelist[12]="macrosUsed.txt"
		$filelist[13]="macrosUsed_CS.txt"
		$filelist[14]="MCinFuncDef.txt"
		$filelist[15]="stringsUsed.txt"
		$filelist[16]="stringsUsed_CS.txt"
		$filelist[17]="treeincl.txt"
		$filelist[18]="uniqueFuncsAll.txt"
		$filelist[19]="variablesUsed.txt"
		$filelist[20]="variablesUsed_CS.txt"
		$filelist[0]=UBound($filelist)-1

		; all files HAVE to exist, but may be empty
		For $rc=1 To $filelist[0]
			$curfile=$CS_dumppath & $filelist[$rc]
			If Not FileExists($curfile) Then _FileCreate($curfile)
		Next

	EndIf

	If $showprogress=True Then GUIDelete($PBhandle)
	If $runquiet=True Or $fulldump=False Then Return

	If MsgBox(262144+8192+256+64+1,"CodeScanner","Data Dump written to subdirectory:" & @CR & $CS_dumppath & @CR & @CR & "Inspect now?")=1 Then
		Run("explorer.exe /e, " & '"' & $CS_dumppath & '"')
	EndIf

EndFunc


Func _FileWriteFromArray2D($File, ByRef $a_Array,$i_Base=0,$i_Ubound=0,$s_Delim="|")

	If $File="" Or (Not IsArray($a_Array)) Or UBound($a_Array,0)<>2 Or StringLen($s_Delim)=0 Then Return SetError(1,0,False)
	If $i_Ubound=0 Then $i_Ubound=UBound($a_Array,1)

	Local $recs=$i_Ubound-$i_Base-1
	If $recs<0 Then Return SetError(2,0,False)

	Local $cols=UBound($a_Array,2)-1
	If $cols<0 Then Return SetError(3,0,False)

	Local $tmp[1+$recs]

	For $rc=0 To $recs
		$tmp[$rc]=""
		For $cc=0 To $cols
			$tmp[$rc] &= $a_Array[$i_Base+$rc][$cc] & $s_Delim
		Next
	Next
	_ArrayTrim($tmp,StringLen($s_Delim),1)	; clip trailing delimiter
	_FileWriteFromArray($File,$tmp,0)

EndFunc


Func _CaptureEsc()
	If MsgBox(262144+8192+256+64+4,"CodeScanner","<Esc> pressed; Return to Main Menu?")=6 Then $EscPressed=True
EndFunc


Func _AddFunCall($curfunc,$IsDefined=False)

	$funcdef_ID=_ArraySearch($FunctionsDefined,$curfunc,1)
	If $IsDefined=True Then
		If $funcdef_ID<1 Then
			_ArrayAdd($FunctionsDefined,$curfunc,0,Chr(0))	; sequential, UDFs
			_ArrayAdd($MCinFuncDef,"",0,Chr(0))					; indexed MC storage
			$funcdef_ID=UBound($functionsDefined)-1
			$functionsDefined[0]=$funcdef_ID
			$MCinFuncDef[0]=$funcdef_ID
		EndIf
	Else
		If _ArraySearch($FunctionsCalled,$curfunc,1)<1 Then _ArrayAdd($FunctionsCalled,$curfunc,0,Chr(0))
	EndIf

	; found, not necessarily called or defined
	$index=_ArraySearch($FunctionsUsed,$curfunc,1)
	If $index<1 Then
		_ArrayAdd($FunctionsUsed,$curfunc,0,Chr(0))	; sequential, UDFs
		$index=UBound($FunctionsUsed)-1
	EndIf

	Return $index
EndFunc


;============================================================================================
; Incorporated UDFs by others

; By guinness, http://www.autoitscript.com/forum/topic/152146-au3-script-parsing-related-functions/
Func __ParseAPI(ByRef $sData, ByRef $aArray, ByRef $sString, $sParseName, $sParsePattern)
    $aArray = StringRegExp($sData, $sParsePattern, 3)
    _ArrayUniqueFast($aArray, 0, UBound($aArray) - 1)

	 Return	; rest of UDF not needed here
#cs
     $sString = 'Func _' & $sParseName & 'Strings() ; Compiled using au3.api from v' & @AutoItVersion & '.' & @CRLF & @TAB & 'Local $s' & $sParseName & ' = '''
    Local $sStringTemp = ''
    For $i = 1 To $aArray[0]
        If StringLen($sStringTemp) > 250 Then
            $sStringTemp = $sStringTemp & ''' & _' & @CRLF
            $sString &= $sStringTemp
            $sStringTemp = @TAB & @TAB & @TAB & ''''
        EndIf
        $sStringTemp &= $aArray[$i] & '|'
    Next
    If $sStringTemp Then
        $sString &= StringTrimRight($sStringTemp, StringLen('|')) & ''''
    EndIf
    $sString &= @CRLF & @TAB & 'Return $s' & $sParseName & @CRLF & 'EndFunc   ;==>_' & $sParseName & 'Strings'
#ce
EndFunc


; By Yashied, http://www.autoitscript.com/forum/topic/122192-arraysort-and-eliminate-duplicates/#entry849187
Func _ArrayUniqueFast(ByRef $aArray, $iStart, $iEnd)
    Local Const $iLocalVar = 1
    Local $sOutput = ''
    For $i = $iStart To $iEnd
        If IsDeclared($aArray[$i] & '$') = 0 Then
            Assign($aArray[$i] & '$', 0, $iLocalVar)
            $sOutput &= $aArray[$i] & @CRLF
        EndIf
    Next
    $sOutput = StringTrimRight($sOutput, StringLen(@CRLF))
    $aArray = StringSplit($sOutput, @CRLF, 1)
EndFunc   ;==>_ArrayUniqueFast


; By AZJIO, responding in the codescanner thread
Func _GetAutoItPath()	; edited
	Local $sPath = RegRead("HKLM\SOFTWARE\AutoIt v3\AutoIt", "InstallDir")
	If @error Or $sPath=0 Or Not FileExists($sPath & "\.") Then $sPath = @ProgramFilesDir & "\AutoIt3"
	If  Not FileExists($sPath & "\.") Then $sPath=""
	Return $sPath
EndFunc


; By PsaltyDS, http://www.autoitscript.com/forum/topic/108187-double-click-mouse-option-in-tree-view/
Func _WM_NOTIFY_TreeView($hWnd, $Msg, $wParam, $lParam)
	Local $tagNMHDR = "int hwndFrom; int idFrom; int code"
	Switch $wParam
		Case $idTV
			Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
			If @error Then Return
         If DllStructGetData($tNMHDR, "code") = $NM_DBLCLK Then
				$item_clicked=True
			EndIf
    EndSwitch
    $tNMHDR = 0
    Return $GUI_RUNDEFMSG
EndFunc



Func _CloseLogfile()

	If $uselogfile=True And $fhlog>0 Then FileClose($fhlog)

EndFunc

#endregion	Utilities