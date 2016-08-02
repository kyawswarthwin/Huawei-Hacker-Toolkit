#include-once
#RequireAdmin
#include <ButtonConstants.au3>
#include <Crypt.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <StaticConstants.au3>
#include <WinAPIDiag.au3>
#include <WindowsConstants.au3>

Global Const $VALID_CHARS = "0123456789ABCDEFGHJKLMNPQRTUVWXY"

Global $idSerialNumberInput, $idRegisterButton, $__vPrivateKey

Func _Registration_Check($sAppName, $sAppURL, $vPrivateKey)
	_Crypt_Startup()
	Local $sTitle = $sAppName & " Online Registration", $sKey = "HKEY_LOCAL_MACHINE\Software\" & $sAppName, $sValue = "License", $dData, $sSerialNumber, $sOutput
	$__vPrivateKey = $vPrivateKey
	$dData = RegRead($sKey, $sValue)
	If Not @error Then
		$sSerialNumber = BinaryToString(_Crypt_DecryptData($dData, _WinAPI_UniqueHardwareID() & $vPrivateKey, $CALG_RC4))
		If _Registration_ValidateSerialNumber($sSerialNumber, $vPrivateKey) Then
			If Not StringInStr(__Register($sAppURL, $sSerialNumber), "Registration Has Been Temporarily Disabled.") Then
				_Crypt_Shutdown()
				Return
			EndIf
		EndIf
	EndIf
	RegDelete($sKey, $sValue)
	$hGUI = GUICreate($sTitle, 305, 130, -1, -1, $WS_SYSMENU)
	$idSerialNumberLabel = GUICtrlCreateLabel("Serial Number:", 10, 8, 73, 17)
	$idSerialNumberInput = GUICtrlCreateInput("", 10, 25, 280, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_UPPERCASE))
	GUICtrlSetLimit(-1, 29)
	$idRegisterButton = GUICtrlCreateButton("&Register", 215, 60, 75, 25)
	GUICtrlSetState(-1, $GUI_DISABLE)
	Dim $hGUI_AccelTable[1][2] = [["{Enter}", $idRegisterButton]]
	GUISetAccelerators($hGUI_AccelTable)
	GUIRegisterMsg($WM_COMMAND, "__Registration_WM_COMMAND")
	GUISetState()
	While 1
		$iMsg = GUIGetMsg()
		Switch $iMsg
			Case $GUI_EVENT_CLOSE
				_Crypt_Shutdown()
				Exit
			Case $idRegisterButton
				$sSerialNumber = StringReplace(GUICtrlRead($idSerialNumberInput), "-", "")
				If Not _Registration_ValidateSerialNumber($sSerialNumber, $vPrivateKey) Then
					GUICtrlSetState($idRegisterButton, $GUI_DISABLE)
				Else
					$sOutput = __Register($sAppURL, $sSerialNumber)
					If @error Then
						MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Unable To Connect To The Server.", Default, $hGUI)
					Else
						If StringInStr($sOutput, "Registration Has Been Successful.") Then
							RegWrite($sKey, $sValue, "REG_BINARY", _Crypt_EncryptData($sSerialNumber, _WinAPI_UniqueHardwareID() & $vPrivateKey, $CALG_RC4))
							GUIDelete()
							_Crypt_Shutdown()
							Return
						ElseIf StringInStr($sOutput, "Serial Number Has Already Been Used.") Then
							MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Serial Number Has Already Been Used.", Default, $hGUI)
						ElseIf StringInStr($sOutput, "Registration Has Been Temporarily Disabled.") Then
							MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Registration Has Been Temporarily Disabled.", Default, $hGUI)
						Else
							MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Unable To Register.", Default, $hGUI)
						EndIf
					EndIf
				EndIf
		EndSwitch
	WEnd
EndFunc   ;==>_Registration_Check

Func _Registration_GenerateSerialNumber($vPrivateKey)
	Local $sRandomKey = ""
	For $i = 1 To 9
		$sRandomKey &= StringMid($VALID_CHARS, Random(1, StringLen($VALID_CHARS), 1), 1)
	Next
	Return StringRegExpReplace($sRandomKey & __GenerateSerialNumber($sRandomKey & $vPrivateKey), "([A-Z0-9]{5})(?=[A-Z0-9])", "\1-")
EndFunc   ;==>_Registration_GenerateSerialNumber

Func _Registration_ValidateSerialNumber($sSerialNumber, $vPrivateKey)
	Local $sRandomKey = StringLeft($sSerialNumber, 9)
	Return $sRandomKey & __GenerateSerialNumber($sRandomKey & $vPrivateKey) == $sSerialNumber
EndFunc   ;==>_Registration_ValidateSerialNumber

Func __Registration_WM_COMMAND($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $ilParam
	Local $sSerialNumber
	Switch _WinAPI_LoWord($iwParam)
		Case $idSerialNumberInput
			Switch _WinAPI_HiWord($iwParam)
				Case $EN_CHANGE
					$sSerialNumber = StringReplace(GUICtrlRead($idSerialNumberInput), "-", "")
					If Not _Registration_ValidateSerialNumber($sSerialNumber, $__vPrivateKey) Then
						GUICtrlSetState($idRegisterButton, $GUI_DISABLE)
					Else
						GUICtrlSetState($idRegisterButton, $GUI_ENABLE)
					EndIf
					$sSerialNumber = StringRegExpReplace($sSerialNumber, "([A-Z0-9]{5})(?=[A-Z0-9])", "\1-")
					GUICtrlSetData($idSerialNumberInput, $sSerialNumber)
			EndSwitch
	EndSwitch
EndFunc   ;==>__Registration_WM_COMMAND

Func __GenerateSerialNumber($vKey)
	_Crypt_Startup()
	Local $sMD5, $iChar, $sSerialNumber = ""
	$sMD5 = StringTrimLeft(_Crypt_HashData($vKey, $CALG_MD5), 2)
	For $i = 1 To 16
		$iChar = Mod(Dec(StringMid($sMD5, ($i * 2) - 1, 2)), 32)
		$sSerialNumber &= StringMid($VALID_CHARS, $iChar + 1, 1)
	Next
	_Crypt_Shutdown()
	Return $sSerialNumber
EndFunc   ;==>__GenerateSerialNumber

Func __Register($sAppURL, $sSerialNumber)
	_Crypt_Startup()
	Local $oHTTP = ObjCreate("winhttp.winhttprequest.5.1")
	$oHTTP.Open("POST", $sAppURL & "/register.php", False)
	$oHTTP.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
	$oHTTP.Send("serial_number=" & StringTrimLeft(_Crypt_HashData($sSerialNumber, $CALG_MD5), 2) & "&hardware_id=" & _WinAPI_UniqueHardwareID())
	If $oHTTP.Status <> 200 Then
		_Crypt_Shutdown()
		Return SetError(1, 0, "")
	EndIf
	_Crypt_Shutdown()
	Return $oHTTP.ResponseText
EndFunc   ;==>__Register
