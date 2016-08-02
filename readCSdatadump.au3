; =======================================================================================================================
; Title .........: ReadCSDataDump
; AutoIt Version : 3.3.12
; Description ...: reads in Code Scanner's Data Dump variables (text and arrays)
; Author(s) .....: A.R.T. Jonkers (RTFC)
; Release........: 1.0
; Latest revision: 07 Jun 2014
; Related to.....: CodeScanner, by RTFC, see www.autoitscript.com/forum/topic/153368-code-scanner/
;                  MCF.au3 + MCFinclude.au3 (MCF package), see www.autoitscript.com/forum/topic/155537-mcf-metacode-file-udf/)
; ===============================================================================================================================
#include-once
#NoTrayIcon

#include <Array.au3>
#include <File.au3>

#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters= -q -w 1 -w 2 -w- 4 -w 6 -w- 7
#AutoIt3Wrapper_UseX64=N
#AutoIt3Wrapper_res_Compatibility=Vista,Windows7
#AutoIt3Wrapper_UseUPX=Y
#AutoIt3Wrapper_Run_Obfuscator=N
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#region globals

Global $report=""
Global $globaldeflist=""
Global $showprogress=True

; 2-D arrays
Global $entrypoints[1][1]
Global $exitpoints[1][1]
Global $globalsinFuncs[1][1]
Global $include_stats[1][1]
Global $loops[1][1]
Global $mainCodeSections[1][1]
Global $problems[1][1]
Global $references[1][1]
Global $refglobals[1][1]
Global $refindex[1][1]

; 1-D arrays
Global $AU3operators[1]
Global $AU3Functions[1]
Global $AU3FunctionsCalled[1]
Global $AU3FunctionsUsed[1]
Global $dupes[1]

Global $FuncEqualsString[1]
Global $FunctionsCalled[1]
Global $FunctionsCalled_CS[1]
Global $FunctionsDefined[1]
Global $FunctionsNew[1]
Global $FunctionsTransl[1]
Global $FunctionsUsed_CS[1]
Global $FunctionsUsed[1]

Global $globals[1]
Global $globalsRedundant[1]
Global $incl_notfound[1]
Global $includeonce[1]
Global $includes[1]

Global $macros[1]				; complete set
Global $macrosUsed[1]		; $macrosUsed_CS + those found in strings
Global $macrosUsed_CS[1]	; called

Global $MCinFuncDef[1]
Global $myincludes[1]

Global $phrases[1]
Global $phrasesEncryp[1]
Global $phrasesNew[1]
Global $phrasesUsed[1]
Global $phrasesUDF[1]

Global $IncludesRedundant[1]

Global $SelectedUDFname[1]
Global $SelectedUDFstatus[1]
Global $SelectedUDFfixed[1]

Global $stringsEncryp[1]
Global $stringsNew[1]
Global $stringsTransl[1]
Global $stringsUsed[1]
Global $stringsUsed_CS[1]
Global $stringsUsedSorted[1]

Global $treeFunc[1]
Global $treeIncl[1]
Global $uniquefuncsAll[1]
Global $uniqueFuncsCalled[1]
Global $uniqueFuncsCalling[1]
Global $unknownUDFs[1]

Global $variablesNew[1]
Global $variableIsArray[1]
Global $variablesUsed[1]
Global $variablesUsed_CS[1]
Global $variablesTransl[1]
Global $variablesUsedSorted[1]

#endregion globals


Func _ReadCSDataDump($CS_dumppath,$fulldump=True,$s_Delim="|")

	_BlankCSvars()

	If StringRight($CS_dumppath,1)<>"\" Then $CS_dumppath&="\"
	If Not FileExists($CS_dumppath & ".") Then Return SetError(1,0,False)

	If $showprogress=True Then SplashTextOn("","Reading CodeScanner Data..." ,250,40,-1,-1,1+32,"Verdana",10)

	; read text files
	$report=FileRead($CS_dumppath & "report.txt")
	$globaldeflist=Fileread($CS_dumppath & "globaldefs.au3")

	; 2-D arrays
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "entrypoints.txt",$entrypoints,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "exitpoints.txt",$exitpoints,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "globalsinFuncs.txt",$globalsinFuncs,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "include_stats.txt",$include_stats,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "loops.txt",$loops,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "mainCodeSections.txt",$mainCodeSections,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "problems.txt",$problems,$s_Delim)
									_FileReadToArray2D($CS_dumppath & "references.txt",$references,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "refGlobals.txt",$refglobals,$s_Delim)
	If $fulldump=True Then	_FileReadToArray2D($CS_dumppath & "refIndex.txt",$refindex,$s_Delim)

	; 1-D arrays
									_FileReadToArray1D($CS_dumppath & "AU3Functions.txt",$AU3Functions)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "AU3FunctionsCalled.txt",$AU3FunctionsCalled)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "AU3FunctionsUsed.txt",$AU3FunctionsUsed)
									_FileReadToArray1D($CS_dumppath & "AU3operators.txt",$AU3operators)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "dupes.txt",$dupes)

									_FileReadToArray1D($CS_dumppath & "FuncEqualsString.txt",$FuncEqualsString)	; CC output
									_FileReadToArray1D($CS_dumppath & "FunctionsCalled.txt",$FunctionsCalled)
									_FileReadToArray1D($CS_dumppath & "FunctionsCalled_CS.txt",$FunctionsCalled_CS)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "FunctionsDefined.txt",$FunctionsDefined)
									_FileReadToArray1D($CS_dumppath & "FunctionsNew.txt",$FunctionsNew)				; CC output
									_FileReadToArray1D($CS_dumppath & "FunctionsTransl.txt",$FunctionsTransl)		; CC output
									_FileReadToArray1D($CS_dumppath & "FunctionsUsed.txt",$FunctionsUsed)
									_FileReadToArray1D($CS_dumppath & "FunctionsUsed_CS.txt",$FunctionsUsed_CS)

	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "globals.txt",$globals)
									_FileReadToArray1D($CS_dumppath & "globalsRedundant.txt",$globalsRedundant)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "incl_notfound.txt",$incl_notfound)
									_FileReadToArray1D($CS_dumppath & "includeOnce.txt",$includeonce)
									_FileReadToArray1D($CS_dumppath & "includes.txt",$includes)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "includesRedundant.txt",$IncludesRedundant)

									_FileReadToArray1D($CS_dumppath & "macros.txt",$macros)
									_FileReadToArray1D($CS_dumppath & "macrosUsed.txt",$macrosUsed)
									_FileReadToArray1D($CS_dumppath & "macrosUsed_CS.txt",$macrosUsed_CS)

									_FileReadToArray1D($CS_dumppath & "MCinFuncDef.txt",$MCinFuncDef)			; CC output
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "myIncludes.txt",$myincludes)
									_FileReadToArray1D($CS_dumppath & "phrases.txt",$phrases)					; CC output
									_FileReadToArray1D($CS_dumppath & "phrasesEncryp.txt",$phrasesEncryp)	; CC output
									_FileReadToArray1D($CS_dumppath & "phrasesNew.txt",$phrasesNew)			; CC output
									_FileReadToArray1D($CS_dumppath & "phrasesUsed.txt",$phrasesUsed)			; CC output
									_FileReadToArray1D($CS_dumppath & "phrasesUDF.txt",$phrasesUDF)			; CC output

									_FileReadToArray1D($CS_dumppath & "selectedUDFname.txt",$SelectedUDFname)	; CC output
									If IsNumber($selectedUDFname[0]) Then _ArrayDelete($selectedUDFname,0)
									_FileReadToArray1D($CS_dumppath & "selectedUDFstatus.txt",$SelectedUDFstatus)	; CC output
									If IsNumber($selectedUDFstatus[0]) Then _ArrayDelete($selectedUDFstatus,0)
									_FileReadToArray1D($CS_dumppath & "selectedUDFfixed.txt",$SelectedUDFfixed)	; CC output
									If IsNumber($SelectedUDFfixed[0]) Then _ArrayDelete($SelectedUDFfixed,0)
									For $rc=0 To UBound($selectedUDFstatus)-1
										$selectedUDFstatus[$rc]=($selectedUDFstatus[$rc]="True")	; convert back to boolean
										$SelectedUDFfixed[$rc]=($SelectedUDFfixed[$rc]="True")	; convert back to boolean
									Next

									_FileReadToArray1D($CS_dumppath & "stringsEncryp.txt",$stringsEncryp)	; CC output
									_FileReadToArray1D($CS_dumppath & "stringsNew.txt",$stringsNew)			; CC output
									_FileReadToArray1D($CS_dumppath & "stringsTransl.txt",$stringsTransl)	; CC output
									_FileReadToArray1D($CS_dumppath & "stringsUsed.txt",$stringsUsed)
									_FileReadToArray1D($CS_dumppath & "stringsUsed_CS.txt",$stringsUsed_CS)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "stringsUsedSorted.txt",$stringsUsedSorted)

	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "treeFunc.txt",$treeFunc)
									_FileReadToArray1D($CS_dumppath & "treeIncl.txt",$treeIncl)
									_FileReadToArray1D($CS_dumppath & "uniqueFuncsAll.txt",$uniquefuncsAll)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "uniqueFuncsCalled.txt",$uniqueFuncsCalled)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "uniqueFuncsCalling.txt",$uniqueFuncsCalling)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "unknownUDFs.txt",$unknownUDFs)

	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "variableIsArray.txt",$variableIsArray)
									_FileReadToArray1D($CS_dumppath & "variablesNew.txt",$variablesNew)			; CC output
									_FileReadToArray1D($CS_dumppath & "variablesTransl.txt",$variablesTransl)	; CC output
									_FileReadToArray1D($CS_dumppath & "variablesUsed.txt",$variablesUsed)
									_FileReadToArray1D($CS_dumppath & "variablesUsed_CS.txt",$variablesUsed_CS)
	If $fulldump=True Then	_FileReadToArray1D($CS_dumppath & "variablesUsedSorted.txt",$variablesUsedSorted)
	SplashOff()

	Return True
EndFunc


Func _FileReadToArray1D($File, ByRef $a_Array)

	If $File="" Or (Not FileExists($File)) Then Return SetError(1,0,False)

	If _FileReadToArray($File,$a_Array)=0 Then
		If IsArray($a_Array) Then
			ReDim $a_Array[1]
		Else
			Dim $a_Array[1]
		EndIf
		$a_Array[0]=0
		Return SetError(2,0,False)
	EndIf

	Return True
EndFunc


Func _FileReadToArray2D($File, ByRef $a_Array,$s_Delim="|")

	If $File="" Or (Not FileExists($File)) Or (Not IsArray($a_Array)) Or StringLen($s_Delim)=0 Then Return SetError(1,0,False)

	Local $tmp[1]
	_FileReadToArray($File,$tmp)
	If $tmp[0]=0 Then Return SetError(2,0,false)
	If $tmp[1]="0" Then Return SetError(3,0,false)

	$split=StringSplit($tmp[1],$s_Delim,1)
	ReDim $a_Array[$tmp[0]+1][$split[0]]		; initial guess

	$errorcode=0
	For $rc=1 To $tmp[0]
		$split=StringSplit($tmp[$rc],$s_Delim,1)
		If UBound($a_Array,2)<$split[0] Then	; check whether current line contains more parameters than previously dimensioned
			$errorcode=4
			ReDim $a_Array[$tmp[0]+1][$split[0]+1]
		EndIf

		For $cc=1 To $split[0]
			$a_Array[$rc-1][$cc-1] = $split[$cc]
		Next
	Next

	Return SetError($errorcode,0,True)
EndFunc


Func _BlankCSvars()

	Global $report=""
	Global $globaldeflist=""

	; 2-D arrays
	Global $entrypoints[1][1]
	Global $exitpoints[1][1]
	Global $globalsinFuncs[1][1]
	Global $include_stats[1][1]
	Global $loops[1][1]
	Global $mainCodeSections[1][1]
	Global $problems[1][1]
	Global $references[1][1]
	Global $refglobals[1][1]
	Global $refindex[1][1]

	; 2-D arrays
	$entrypoints[0][0]=0
	$exitpoints[0][0]=0
	$globalsinFuncs[0][0]=0
	$include_stats[0][0]=0
	$loops[0][0]=0
	$mainCodeSections[0][0]=0
	$problems[0][0]=0
	$references[0][0]=0
	$refglobals[0][0]=0
	$refindex[0][0]=0

	; 1-D arrays
	Global $AU3operators[1]
	Global $AU3Functions[1]
	Global $AU3FunctionsCalled[1]
	Global $AU3FunctionsUsed[1]
	Global $dupes[1]

	Global $FuncEqualsString[1]
	Global $FunctionsCalled[1]
	Global $FunctionsCalled_CS[1]
	Global $FunctionsDefined[1]
	Global $FunctionsNew[1]
	Global $FunctionsTransl[1]
	Global $FunctionsUsed_CS[1]
	Global $FunctionsUsed[1]

	Global $globals[1]
	Global $globalsRedundant[1]
	Global $incl_notfound[1]
	Global $includeonce[1]
	Global $includes[1]

	Global $macros[1]
	Global $macrosUsed[1]
	Global $macrosUsed_CS[1]

	Global $MCinFuncDef[1]
	Global $myincludes[1]
	Global $phrases[1]
	Global $phrasesEncryp[1]
	Global $phrasesNew[1]
	Global $phrasesUsed[1]
	Global $phrasesUDF[1]
	Global $IncludesRedundant[1]

	Global $SelectedUDFname[1]
	Global $SelectedUDFstatus[1]
	Global $SelectedUDFfixed[1]

	Global $stringsEncryp[1]
	Global $stringsNew[1]
	Global $stringsTransl[1]
	Global $stringsUsed[1]
	Global $stringsUsed_CS[1]
	Global $stringsUsedSorted[1]

	Global $treeFunc[1]
	Global $treeIncl[1]
	Global $uniquefuncsAll[1]
	Global $uniqueFuncsCalled[1]
	Global $uniqueFuncsCalling[1]
	Global $unknownUDFs[1]

	Global $variablesNew[1]
	Global $variableIsArray[1]
	Global $variablesUsed[1]
	Global $variablesUsed_CS[1]
	Global $variablesTransl[1]
	Global $variablesUsedSorted[1]

	; 1-D arrays
	$AU3operators[0]=0
	$AU3Functions[0]=0
	$AU3FunctionsCalled[0]=0
	$AU3FunctionsUsed[0]=0
	$dupes[0]=0

	$FuncEqualsString[0]=0
	$FunctionsCalled[0]=0
	$FunctionsCalled_CS[0]=0
	$FunctionsDefined[0]=0
	$FunctionsTransl[0]=0
	$FunctionsUsed[0]=0
	$FunctionsNew[0]=0
	$FunctionsUsed_CS[0]=0

	$globals[0]=0
	$globalsRedundant[0]=0
	$incl_notfound[0]=0
	$includeonce[0]=0
	$includes[0]=0

	$macros[0]=0
	$macrosUsed[0]=0
	$macrosUsed_CS[0]=0

	$MCinFuncDef[0]=0
	$myincludes[0]=0
	$phrases[0]=0
	$phrasesEncryp[0]=0
	$phrasesNew[0]=0
	$phrasesUsed[0]=0
	$phrasesUDF[0]=0
	$IncludesRedundant[0]=0

	$stringsEncryp[0]=0
	$stringsTransl[0]=0
	$stringsUsed[0]=0
	$stringsNew[0]=0
	$stringsUsed_CS[0]=0
	$stringsUsedSorted[0]=0

	$treeFunc[0]=0
	$treeIncl[0]=0
	$uniquefuncsAll[0]=0
	$uniqueFuncsCalled[0]=0
	$uniqueFuncsCalling[0]=0
	$unknownUDFs[0]=0

	$variableIsArray[0]=0
	$variablesTransl[0]=0

	$variablesUsed[0]=0
	$variablesNew[0]=0
	$variablesUsed_CS[0]=0
	$variablesUsedSorted[0]=0

EndFunc


Func _CheckCSfilesPresent($CSpath)
; CS = CodeScaner

	Local $filelist[19]
	$filelist[1]="references.txt"
	$filelist[2]="AU3Functions.txt"
	$filelist[3]="AU3operators.txt"
	$filelist[4]="FunctionsCalled.txt"
	$filelist[5]="FunctionsCalled_CS.txt"
	$filelist[6]="FunctionsUsed.txt"
	$filelist[7]="FunctionsUsed_CS.txt"
	$filelist[8]="includeOnce.txt"
	$filelist[9]="includes.txt"
	$filelist[10]="macros.txt"
	$filelist[11]="macrosUsed.txt"
	$filelist[12]="macrosUsed_CS.txt"
	$filelist[13]="MCinFuncDef.txt"
	$filelist[14]="stringsUsed.txt"
	$filelist[15]="stringsUsed_CS.txt"
	$filelist[16]="variablesUsed.txt"
	$filelist[17]="variablesUsed_CS.txt"
	$filelist[18]="MCF1.txt"
	$filelist[0]=UBound($filelist)-1

	For $rc=1 To $filelist[0]
		If Not FileExists($CSpath & $filelist[$rc]) Then
			$msg  ="CodeScanner output file not found:" & @CR & @CR & $CSpath & $filelist[$rc]  & @CR  & @CR
			$msg &= "Are you sure you ran Codescanner with setting ""WriteMetaCode=True"", on target file " & StringTrimRight($CSpath,9) & " before? CodeCrypter requires this to function."
			MsgBox(262144+4096+48,"CodeCrypter: File Error",$msg)
			Return SetError(-1, $filelist[$rc],False)
		EndIf
	Next

	Return True
EndFunc


Func _CheckCSBfilesPresent($CSpath)
; CSB = CreateSingleBuild
; NB some of these are not used in CSB, but dummy copies should have been already created

	Local $filelist[12]
	$filelist[1]="FuncEqualsString.txt"
	$filelist[2]="stringsTransl.txt"
	$filelist[3]="stringsEncryp.txt"
	$filelist[4]="stringsNew.txt"
	$filelist[5]="variablesTransl.txt"
	$filelist[6]="variablesEncryp.txt"	; not used in CSB, but dummy copy should exist
	$filelist[7]="variablesNew.txt"
	$filelist[8]="functionsTransl.txt"
	$filelist[9]="functionsEncryp.txt"	; not used in CSB, but dummy copy should exist
	$filelist[10]="functionsNew.txt"
	$filelist[11]="MCF0.txt"
	$filelist[0]=UBound($filelist)-1

	For $rc=1 To $filelist[0]
		If Not FileExists($CSpath & $filelist[$rc]) Then
			$msg  ="_CreateSingleBuild() output file not found:" & @CR & @CR & $CSpath & $filelist[$rc]  & @CR  & @CR
			$msg &= "Are you sure you called _CreateSingleBuild() for target file " & StringTrimRight($CSpath,9) & " before?"
			MsgBox(262144+4096+48,"CodeCrypter: File Error",$msg)
			Return SetError(-1, $filelist[$rc],False)
		EndIf
	Next

	Return True
EndFunc


