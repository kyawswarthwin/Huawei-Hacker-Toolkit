#include-once

Func _Unpack_UPDATEAPP($sSourcePath, $sDestinationPath)
	Local $dData, $iOffset, $sSequencePath = $sDestinationPath & "\Sequence.ini", $tHeader, $sDevice, $sKey, $sFileName, $iSequence = 1
	$dData = _Hex_Read($sSourcePath, BinaryLen($dSignature1))
	If @error Then Return SetError(1, 0, 0)
	If $dData <> $dSignature1 Then Return SetError(2, 0, 0)
	$iOffset = @extended
	FileDelete($sSequencePath)
	While 1
		$tHeader = DllStructCreate($tagHEADER)
		__BinaryToDLLStruct(_Hex_Read($sSourcePath, DllStructGetSize($tHeader), $iOffset), $tHeader)
		If DllStructGetData($tHeader, "Signature") <> $dSignature2 Then ExitLoop
		$sDevice = StringReplace(DllStructGetData($tHeader, "Device"), Chr(Dec("FF")), "")
		IniWrite($sSequencePath, "Information", "Device", $sDevice)
		If @error Then Return SetError(3, 0, 0)
		If DllStructGetData($tHeader, "Type") = "INPUT" Then
			$sKey = Hex(DllStructGetData($tHeader, "Sequence"), 8)
		Else
			$sKey = DllStructGetData($tHeader, "Type")
		EndIf
		$sFileName = IniRead(@ScriptDir & "\Profiles.ini", $sDevice, $sKey, "")
		If $sFileName = "" Then $sFileName = $sKey & ".img"
;~ 		IniWrite(@ScriptDir & "\~Profiles.ini", $sDevice, $sKey, $sFileName)
		IniWrite($sSequencePath, "Sequence", $iSequence, $sFileName)
		If @error Then Return SetError(3, 0, 0)
		_Hex_Write($sDestinationPath & "\" & $sFileName & ".header", __BinaryFromDLLStruct($tHeader), 0)
		If @error Then Return SetError(4, 0, 0)
		$iOffset += DllStructGetData($tHeader, "HeadSize")
		_Hex_Copy($sSourcePath, $sDestinationPath & "\" & $sFileName, DllStructGetData($tHeader, "BodySize"), $iOffset, 0)
		If @error Then Return SetError(5, 0, 0)
		$iOffset += DllStructGetData($tHeader, "BodySize")
		If BitAND($iOffset, 3) Then
			$iOffset += 4 - BitAND($iOffset, 3)
		EndIf
		$iSequence += 1
	WEnd
EndFunc   ;==>_Unpack_UPDATEAPP

Func _Repack_UPDATEAPP($sSourcePath, $sDestinationPath)
	Local $aSequence, $sDrive = "", $sDir = "", $sFileName = "", $sExtension = "", $tHeader, $iOffset, $iBodySize, $iBufferSize, $sCRC, $iHeadSize, $tBuffer
	$aSequence = IniReadSection($sSourcePath, "Sequence")
	If @error Then Return SetError(1, 0, 0)
	_Hex_Write($sDestinationPath, $dSignature1, 0)
	If @error Then Return SetError(2, 0, 0)
	_PathSplit($sSourcePath, $sDrive, $sDir, $sFileName, $sExtension)
	For $i = 1 To $aSequence[0][0]
		$tHeader = DllStructCreate($tagHEADER)
		__BinaryToDLLStruct(_Hex_Read($sDrive & $sDir & $aSequence[$i][1] & ".header", DllStructGetSize($tHeader)), $tHeader)
		If DllStructGetData($tHeader, "Signature") <> $dSignature2 Then Return SetError(3, 0, 0)
		$iOffset = 0
		$iBodySize = FileGetSize($sDrive & $sDir & $aSequence[$i][1])
		$iBufferSize = 4096
		$sCRC = ""
		While $iOffset < $iBodySize
			If $iBufferSize > $iBodySize - $iOffset Then $iBufferSize = $iBodySize - $iOffset
			$sCRC &= BinaryToString(BinaryMid(Binary(BitAND(BitXOR(_CRC16(_Hex_Read($sDrive & $sDir & $aSequence[$i][1], $iBufferSize, $iOffset), 0xFFFF, 0x8408), 0xFFFF), 0xFFFF)), 1, 2))
			$iOffset += $iBufferSize
		WEnd
		$iHeadSize = DllStructGetSize($tHeader) + StringLen($sCRC)
		DllStructSetData($tHeader, "HeadSize", $iHeadSize)
		DllStructSetData($tHeader, "BodySize", $iBodySize)
		_Hex_Write($sDestinationPath, __BinaryFromDLLStruct($tHeader))
		_Hex_Write($sDestinationPath, StringToBinary($sCRC))
		_Hex_Copy($sDrive & $sDir & $aSequence[$i][1], $sDestinationPath)
		$iBufferSize = FileGetSize($sDestinationPath)
		If BitAND($iBufferSize, 3) Then
			$iBufferSize = 4 - BitAND($iBufferSize, 3)
			$tBuffer = DllStructCreate("byte[" & $iBufferSize & "]")
			_Hex_Write($sDestinationPath, __BinaryFromDLLStruct($tBuffer))
		EndIf
	Next
EndFunc   ;==>_Repack_UPDATEAPP

Func __BinaryToDLLStruct($dData, ByRef $tStruct)
	Local $tBuffer = DllStructCreate("byte[" & DllStructGetSize($tStruct) & "]", DllStructGetPtr($tStruct))
	DllStructSetData($tBuffer, 1, $dData)
EndFunc   ;==>__BinaryToDLLStruct

Func __BinaryFromDLLStruct($tStruct)
	Local $tBuffer = DllStructCreate("byte[" & DllStructGetSize($tStruct) & "]", DllStructGetPtr($tStruct))
	Return DllStructGetData($tBuffer, 1)
EndFunc   ;==>__BinaryFromDLLStruct
