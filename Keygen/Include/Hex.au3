#include-once

#include <WinAPI.au3>

; #INDEX# =======================================================================================================================
; Title .........: Hex
; AutoIt Version : 3.3
; Language ......: English
; Description ...:
; Author(s) .....: Kyaw Swar Thwin
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _Hex_Copy
; _Hex_Read
; _Hex_Search
; _Hex_Write
; ===============================================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _Hex_Copy
; Description ...:
; Syntax ........: _Hex_Copy($sSourcePath, $sDestinationPath[, $iCount = -1[, $iSourceOffset = 0[, $iDestinationOffset = -1]]])
; Parameters ....: $sSourcePath         - A string value.
;                  $sDestinationPath    - A string value.
;                  $iCount              - [optional] An integer value. Default is -1.
;                  $iSourceOffset       - [optional] An integer value. Default is 0.
;                  $iDestinationOffset  - [optional] An integer value. Default is -1.
; Return values .: None
; Author ........: Kyaw Swar Thwin
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _Hex_Copy($sSourcePath, $sDestinationPath, $iCount = -1, $iSourceOffset = 0, $iDestinationOffset = -1)
	Local $hReadFile, $iFileSize, $hWriteFile, $iBufferSize = 2097152, $tBuffer, $iBytesRead = 0, $iRead, $iWritten
	If $iSourceOffset = Default Or $iSourceOffset < 0 Then $iSourceOffset = 0
	$hReadFile = _WinAPI_CreateFile($sSourcePath, 2, 2, 2)
	If Not $hReadFile Then Return SetError(1, 0, 0)
	$iFileSize = _WinAPI_GetFileSizeEx($hReadFile)
	If $iFileSize < $iSourceOffset Then
		_WinAPI_CloseHandle($hReadFile)
		Return SetError(2, 0, 0)
	EndIf
	If $iCount = Default Or $iCount < 1 Then $iCount = $iFileSize
	If $iFileSize < $iSourceOffset + $iCount Then
		_WinAPI_CloseHandle($hReadFile)
		Return SetError(3, 0, 0)
	EndIf
	_WinAPI_SetFilePointer($hReadFile, $iSourceOffset)
	$hWriteFile = _WinAPI_CreateFile($sDestinationPath, 3, 4)
	If Not $hWriteFile Then
		_WinAPI_CloseHandle($hReadFile)
		Return SetError(4, 0, 0)
	EndIf
	If $iDestinationOffset = Default Or $iDestinationOffset < 0 Then
		_WinAPI_SetFilePointer($hWriteFile, 0, $FILE_END)
	Else
		_WinAPI_SetFilePointer($hWriteFile, $iDestinationOffset)
	EndIf
	$tBuffer = DllStructCreate("byte[" & $iBufferSize & "]")
	While $iBytesRead < $iCount
		If $iBufferSize > $iCount - $iBytesRead Then $iBufferSize = $iCount - $iBytesRead
		_WinAPI_ReadFile($hReadFile, DllStructGetPtr($tBuffer), $iBufferSize, $iRead)
		_WinAPI_WriteFile($hWriteFile, DllStructGetPtr($tBuffer), $iRead, $iWritten)
		$iBytesRead += $iBufferSize
	WEnd
	_WinAPI_CloseHandle($hReadFile)
	_WinAPI_CloseHandle($hWriteFile)
	Return 1
EndFunc   ;==>_Hex_Copy

; #FUNCTION# ====================================================================================================================
; Name ..........: _Hex_Read
; Description ...:
; Syntax ........: _Hex_Read($sFilePath[, $iCount = -1[, $iOffset = 0]])
; Parameters ....: $sFilePath           - A string value.
;                  $iCount              - [optional] An integer value. Default is -1.
;                  $iOffset             - [optional] An integer value. Default is 0.
; Return values .: None
; Author ........: Kyaw Swar Thwin
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _Hex_Read($sFilePath, $iCount = -1, $iOffset = 0)
	Local $hFile, $iFileSize, $tBuffer, $iRead
	If $iOffset = Default Or $iOffset < 0 Then $iOffset = 0
	$hFile = _WinAPI_CreateFile($sFilePath, 2, 2)
	If Not $hFile Then Return SetError(1, 0, "")
	$iFileSize = _WinAPI_GetFileSizeEx($hFile)
	If $iFileSize < $iOffset Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(2, 0, "")
	EndIf
	If $iCount = Default Or $iCount < 1 Then $iCount = $iFileSize
	If $iFileSize < $iOffset + $iCount Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(3, 0, "")
	EndIf
	_WinAPI_SetFilePointer($hFile, $iOffset)
	$tBuffer = DllStructCreate("byte[" & $iCount & "]")
	_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $iCount, $iRead)
	_WinAPI_CloseHandle($hFile)
	Return SetExtended($iRead, DllStructGetData($tBuffer, 1))
EndFunc   ;==>_Hex_Read

; #FUNCTION# ====================================================================================================================
; Name ..........: _Hex_Search
; Description ...:
; Syntax ........: _Hex_Search($sFilePath, $dData[, $iStartOffset = 0])
; Parameters ....: $sFilePath           - A string value.
;                  $dData               - An unknown value.
;                  $iStartOffset        - [optional] An integer value. Default is 0.
; Return values .: None
; Author ........: Kyaw Swar Thwin
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _Hex_Search($sFilePath, $dData, $iStartOffset = 0)
	Local $hFile, $iFileSize, $iBufferSize = 2097152, $tBuffer, $iOffset, $iRead, $iResult
	If Not IsBinary($dData) Then Return SetError(2, 0, -1)
	If $iStartOffset = Default Or $iStartOffset < 0 Then $iStartOffset = 0
	$hFile = _WinAPI_CreateFile($sFilePath, 2, 2, 2)
	If Not $hFile Then Return SetError(1, 0, -1)
	$iFileSize = _WinAPI_GetFileSizeEx($hFile)
	If $iFileSize < $iStartOffset Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(3, 0, -1)
	EndIf
	_WinAPI_SetFilePointer($hFile, $iStartOffset)
	$tBuffer = DllStructCreate("byte[" & $iBufferSize & "]")
	$iOffset = $iStartOffset
	While 1
		_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $iBufferSize, $iRead)
		$iResult = StringInStr(BinaryToString(DllStructGetData($tBuffer, 1)), BinaryToString($dData), $STR_CASESENSE)
		If $iResult > 0 Then ExitLoop
		If $iRead < $iBufferSize Then
			_WinAPI_CloseHandle($hFile)
			Return -1
		EndIf
		$iOffset += $iRead
	WEnd
	_WinAPI_CloseHandle($hFile)
	$iResult = $iOffset + $iResult - 1
	Return $iResult
EndFunc   ;==>_Hex_Search

; #FUNCTION# ====================================================================================================================
; Name ..........: _Hex_Write
; Description ...:
; Syntax ........: _Hex_Write($sFilePath, $dData[, $iOffset = -1])
; Parameters ....: $sFilePath           - A string value.
;                  $dData               - An unknown value.
;                  $iOffset             - [optional] An integer value. Default is -1.
; Return values .: None
; Author ........: Kyaw Swar Thwin
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _Hex_Write($sFilePath, $dData, $iOffset = -1)
	Local $hFile, $iBufferSize, $tBuffer, $iWritten, $bResult
	If Not IsBinary($dData) Then Return SetError(2, 0, 0)
	$hFile = _WinAPI_CreateFile($sFilePath, 3, 4)
	If Not $hFile Then Return SetError(1, 0, 0)
	If $iOffset = Default Or $iOffset < 0 Then
		_WinAPI_SetFilePointer($hFile, 0, $FILE_END)
	Else
		_WinAPI_SetFilePointer($hFile, $iOffset)
	EndIf
	$iBufferSize = BinaryLen($dData)
	$tBuffer = DllStructCreate("byte[" & $iBufferSize & "]")
	DllStructSetData($tBuffer, 1, $dData)
	$bResult = _WinAPI_WriteFile($hFile, DllStructGetPtr($tBuffer), $iBufferSize, $iWritten)
	_WinAPI_CloseHandle($hFile)
	Return Number($bResult)
EndFunc   ;==>_Hex_Write
