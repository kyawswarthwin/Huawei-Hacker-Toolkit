#include-once
#include <Constants.au3>
#include <Crypt.au3>
#include <Array.au3>

Global Const $sBinaryPath = @ScriptDir & "\bin"

Global Const $AC_POWERED = "AC powered"
Global Const $USB_POWERED = "USB powered"
Global Const $EXTRA_STATUS = "status"
Global Const $EXTRA_HEALTH = "health"
Global Const $EXTRA_LEVEL = "level"
Global Const $EXTRA_SCALE = "scale"
Global Const $EXTRA_VOLTAGE = "voltage"
Global Const $EXTRA_TEMPERATURE = "temperature"
Global Const $EXTRA_TECHNOLOGY = "technology"

Global Const $BATTERY_STATUS_UNKNOWN = 1
Global Const $BATTERY_STATUS_CHARGING = 2
Global Const $BATTERY_STATUS_DISCHARGING = 3
Global Const $BATTERY_STATUS_NOT_CHARGING = 4
Global Const $BATTERY_STATUS_FULL = 5

Global Const $BATTERY_HEALTH_UNKNOWN = 1
Global Const $BATTERY_HEALTH_GOOD = 2
Global Const $BATTERY_HEALTH_OVERHEAT = 3
Global Const $BATTERY_HEALTH_DEAD = 4
Global Const $BATTERY_HEALTH_OVER_VOLTAGE = 5
Global Const $BATTERY_HEALTH_UNSPECIFIED_FAILURE = 6
Global Const $BATTERY_HEALTH_COLD = 7

Global Const $PROPERTY_BASEBAND_VERSION = "gsm.version.baseband"
Global Const $CURRENT_ACTIVE_PHONE = "gsm.current.phone-type"
Global Const $PROPERTY_OPERATOR_ALPHA = "gsm.operator.alpha"
Global Const $PROPERTY_OPERATOR_NUMERIC = "gsm.operator.numeric"
Global Const $PROPERTY_OPERATOR_ISO_COUNTRY = "gsm.operator.iso-country"
Global Const $PROPERTY_OPERATOR_ISROAMING = "gsm.operator.isroaming"
Global Const $PROPERTY_DATA_NETWORK_TYPE = "gsm.network.type"
Global Const $PROPERTY_SIM_STATE = "gsm.sim.state"
Global Const $PROPERTY_ICC_OPERATOR_ALPHA = "gsm.sim.operator.alpha"
Global Const $PROPERTY_ICC_OPERATOR_NUMERIC = "gsm.sim.operator.numeric"
Global Const $PROPERTY_ICC_OPERATOR_ISO_COUNTRY = "gsm.sim.operator.iso-country"

Global Const $PHONE_TYPE_NONE = 0
Global Const $PHONE_TYPE_GSM = 1
Global Const $PHONE_TYPE_CDMA = 2
Global Const $PHONE_TYPE_SIP = 3

Func _Android_Connect()
	__Run("adb kill-server")
	__Run("adb start-server")
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	Return True
EndFunc   ;==>_Android_Connect

Func _Android_Reboot($iMode = 1)
	If _Android_IsDeviceOffline() Then Return SetError(1, 0, "Error: Device Not Found!")
	Switch $iMode
		Case 2; Recovery
			If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
			__Run("adb reboot recovery")
		Case 3; Bootloader
			If _Android_IsDeviceOnline() Then
				__Run("adb reboot bootloader")
			Else
				__Run("fastboot reboot-bootloader")
			EndIf
		Case 4; Download
			If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
			__Run("adb reboot download")
		Case Else; Normal
			If _Android_IsDeviceOnline() Then
				__Run("adb reboot")
			Else
				__Run("fastboot reboot")
			EndIf
	EndSwitch
	Return True
EndFunc   ;==>_Android_Reboot

Func _Android_WaitForDevice($iMode = 1)
	_Android_Connect()
	If $iMode = 2 Then; Bootloader
		Do
			Sleep(500)
		Until _Android_IsDeviceBootloader()
	Else; Normal
		Do
			Sleep(500)
		Until _Android_IsDeviceOnline()
	EndIf
EndFunc   ;==>_Android_WaitForDevice

Func _Android_Remount($sMode = "rw", $sPath = "/system")
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	If Not _Android_IsDeviceRooted() Then
		$sOutput = StringStripWS(_Android_Shell("mount -o remount," & $sMode & " " & $sPath), 3)
	Else
		$sOutput = StringStripWS(_Android_ShellAsRoot("mount -o remount," & $sMode & " " & $sPath), 3)
	EndIf
	If $sOutput <> "" Then Return SetError(2, 0, "Error: Failure!")
	Return True
EndFunc   ;==>_Android_Remount

Func _Android_FileExists($sFilePath)
	Local $sOutput, $bFileExists = False
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, $bFileExists)
	$sOutput = StringStripWS(__Run("adb shell ""if [ -e \""" & $sFilePath & "\"" ]; then echo \""True\""; else echo \""False\""; fi"""), 3)
	If $sOutput = "True" Then $bFileExists = True
	Return $bFileExists
EndFunc   ;==>_Android_FileExists

Func _Android_Push($sLocal, $sRemote)
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	Return __Run('adb push "' & $sLocal & '" "' & $sRemote & '"')
EndFunc   ;==>_Android_Push

Func _Android_Pull($sRemote, $sLocal)
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	Return __Run('adb pull "' & $sRemote & '" "' & $sLocal & '"')
EndFunc   ;==>_Android_Pull

Func _Android_Install($sFilePath, $iMode = 1)
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	If $iMode = 2 Then; Install on SD Card
		$sOutput = StringStripWS(__Run("@echo off && for /f ""skip=1 tokens=* delims="" %i in ('adb install -s """ & $sFilePath & """') do echo.%i"), 3)
	Else; Install on Internal Storage
		$sOutput = StringStripWS(__Run("@echo off && for /f ""skip=1 tokens=* delims="" %i in ('adb install """ & $sFilePath & """') do echo.%i"), 3)
	EndIf
	If $sOutput <> "Success" Then Return SetError(2, 0, "Error: Failure!")
	Return True
EndFunc   ;==>_Android_Install

Func _Android_Uninstall($sPackage)
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	$sOutput = StringStripWS(__Run("adb uninstall " & $sPackage), 3)
	If $sOutput <> "Success" Then Return SetError(2, 0, "Error: Failure!")
	Return True
EndFunc   ;==>_Android_Uninstall

Func _Android_Shell($sCommand)
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	Return __Run('adb shell "' & $sCommand & '"')
EndFunc   ;==>_Android_Shell

Func _Android_ShellAsRoot($sCommand)
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	Return __Run('adb shell su -c "' & $sCommand & '"')
EndFunc   ;==>_Android_ShellAsRoot

Func _Android_Call($sPhoneNumber)
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	$sOutput = StringStripWS(_Android_Shell("service call phone 2 s16 \""" & __URLEncode($sPhoneNumber) & "\"""), 3)
	If $sOutput <> "Result: Parcel(00000000    '....')" Then Return SetError(2, 0, "Error: Failure!")
	Return True
EndFunc   ;==>_Android_Call

Func _Android_SendSMS($sPhoneNumber, $sSMSBody)
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Error: Device Not Found!")
	$sOutput = StringStripWS(_Android_Shell("service call isms 5 s16 \""" & __URLEncode($sPhoneNumber) & "\"" i32 0 i32 0 s16 \""" & $sSMSBody & "\"""), 3)
	If $sOutput <> "Result: Parcel(00000000    '....')" Then Return SetError(2, 0, "Error: Failure!")
	Return True
EndFunc   ;==>_Android_SendSMS

Func _Android_Flash($sMode, $sFilePath)
	If Not _Android_IsDeviceBootloader() Then Return SetError(1, 0, "Error: Device Not Found!")
	Return __Run("fastboot flash " & $sMode & ' "' & $sFilePath & '"')
EndFunc   ;==>_Android_Flash

Func _Android_GetDeviceState()
	If _Android_IsDeviceOnline() Then
		Return "Online"
	ElseIf _Android_IsDeviceBootloader() Then
		Return "Bootloader"
	Else
		Return "Offline"
	EndIf
EndFunc   ;==>_Android_GetDeviceState

Func _Android_GetDeviceSerialNumber()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return _Android_GetProperty("ro.serialno")
EndFunc   ;==>_Android_GetDeviceSerialNumber

Func _Android_GetDeviceManufacturer()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return _Android_GetProperty("ro.product.manufacturer")
EndFunc   ;==>_Android_GetDeviceManufacturer

Func _Android_GetDeviceModel()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return _Android_GetProperty("ro.product.model")
EndFunc   ;==>_Android_GetDeviceModel

Func _Android_GetProductID()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	If Not _Android_IsDeviceTablet() Then
		Return __Android_GenerateProductID(_Android_GetDeviceModel(), _Android_GetDeviceID())
	Else
		Return __Android_GenerateProductID(_Android_GetDeviceModel(), _Android_GetDeviceSerialNumber())
	EndIf
EndFunc   ;==>_Android_GetProductID

Func _Android_GetAndroidVersion()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return _Android_GetProperty("ro.build.version.release")
EndFunc   ;==>_Android_GetAndroidVersion

Func _Android_GetAPILevel()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return Number(_Android_GetProperty("ro.build.version.sdk"))
EndFunc   ;==>_Android_GetAPILevel

Func _Android_GetBuildNumber()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return _Android_GetProperty("ro.build.display.id")
EndFunc   ;==>_Android_GetBuildNumber

Func _Android_GetPlugType()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	If __Android_GetBatteryInfo($AC_POWERED) = "true" Then
		Return "AC Charger"
	ElseIf __Android_GetBatteryInfo($USB_POWERED) = "true" Then
		Return "USB Port"
	Else
		Return "Unknown"
	EndIf
EndFunc   ;==>_Android_GetPlugType

Func _Android_GetBatteryStatus()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Switch __Android_GetBatteryInfo($EXTRA_STATUS)
		Case $BATTERY_STATUS_CHARGING
			Return "Charging"
		Case $BATTERY_STATUS_DISCHARGING
			Return "Discharging"
		Case $BATTERY_STATUS_NOT_CHARGING
			Return "Not Charging"
		Case $BATTERY_STATUS_FULL
			Return "Full"
		Case Else
			Return "Unknown"
	EndSwitch
EndFunc   ;==>_Android_GetBatteryStatus

Func _Android_GetBatteryHealth()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Switch __Android_GetBatteryInfo($EXTRA_HEALTH)
		Case $BATTERY_HEALTH_GOOD
			Return "Good"
		Case $BATTERY_HEALTH_OVERHEAT
			Return "Overheat"
		Case $BATTERY_HEALTH_DEAD
			Return "Dead"
		Case $BATTERY_HEALTH_OVER_VOLTAGE
			Return "Over Voltage"
		Case $BATTERY_HEALTH_UNSPECIFIED_FAILURE
			Return "Unspecified Failure"
		Case $BATTERY_HEALTH_COLD
			Return "Cold"
		Case Else
			Return "Unknown"
	EndSwitch
EndFunc   ;==>_Android_GetBatteryHealth

Func _Android_GetBatteryLevel()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return (__Android_GetBatteryInfo($EXTRA_LEVEL) * 100) / __Android_GetBatteryInfo($EXTRA_SCALE) & "%"
EndFunc   ;==>_Android_GetBatteryLevel

Func _Android_GetBatteryVoltage()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return __Android_GetBatteryInfo($EXTRA_VOLTAGE) / 1000 & "V"
EndFunc   ;==>_Android_GetBatteryVoltage

Func _Android_GetBatteryTemperature()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return StringFormat("%.1f", __Android_GetBatteryInfo($EXTRA_TEMPERATURE) / 10) & "°C"
EndFunc   ;==>_Android_GetBatteryTemperature

Func _Android_GetBatteryTechnology()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return __Android_GetBatteryInfo($EXTRA_TECHNOLOGY)
EndFunc   ;==>_Android_GetBatteryTechnology

Func _Android_GetRadioVersion()
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	Return _Android_GetProperty($PROPERTY_BASEBAND_VERSION)
EndFunc   ;==>_Android_GetRadioVersion

Func _Android_GetPhoneType($iSIMNumber = 1)
	Local $sPhoneType, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sPhoneType = _Android_GetProperty($CURRENT_ACTIVE_PHONE)
	$iOffset = StringInStr($sPhoneType, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sPhoneType = StringRight($sPhoneType, StringLen($sPhoneType) - $iOffset)
		Else
			$sPhoneType = StringLeft($sPhoneType, $iOffset - 1)
		EndIf
	EndIf
	Switch $sPhoneType
		Case $PHONE_TYPE_NONE
			Return "None"
		Case $PHONE_TYPE_GSM
			Return "GSM"
		Case $PHONE_TYPE_CDMA
			Return "CDMA"
		Case $PHONE_TYPE_SIP
			Return "SIP"
		Case Else
			Return "Unknown"
	EndSwitch
EndFunc   ;==>_Android_GetPhoneType

Func _Android_GetDeviceID()
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sOutput = StringStripWS(__Run("@echo off && for /f ""tokens=2 delims=="" %i in ('adb shell ""dumpsys iphonesubinfo"" ^| find /i ""Device ID""') do echo.%i"), 3)
	Return $sOutput
EndFunc   ;==>_Android_GetDeviceID

Func _Android_GetNetworkOperatorName($iSIMNumber = 1)
	Local $sNetworkOperatorName, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sNetworkOperatorName = _Android_GetProperty($PROPERTY_OPERATOR_ALPHA)
	$iOffset = StringInStr($sNetworkOperatorName, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sNetworkOperatorName = StringRight($sNetworkOperatorName, StringLen($sNetworkOperatorName) - $iOffset)
		Else
			$sNetworkOperatorName = StringLeft($sNetworkOperatorName, $iOffset - 1)
		EndIf
	EndIf
	Return $sNetworkOperatorName
EndFunc   ;==>_Android_GetNetworkOperatorName

Func _Android_GetNetworkOperator($iSIMNumber = 1)
	Local $sNetworkOperator, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sNetworkOperator = _Android_GetProperty($PROPERTY_OPERATOR_NUMERIC)
	$iOffset = StringInStr($sNetworkOperator, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sNetworkOperator = StringRight($sNetworkOperator, StringLen($sNetworkOperator) - $iOffset)
		Else
			$sNetworkOperator = StringLeft($sNetworkOperator, $iOffset - 1)
		EndIf
	EndIf
	Return $sNetworkOperator
EndFunc   ;==>_Android_GetNetworkOperator

Func _Android_GetNetworkOperatorCountryISO($iSIMNumber = 1)
	Local $sNetworkOperatorCountryISO, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sNetworkOperatorCountryISO = _Android_GetProperty($PROPERTY_OPERATOR_ISO_COUNTRY)
	$iOffset = StringInStr($sNetworkOperatorCountryISO, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sNetworkOperatorCountryISO = StringRight($sNetworkOperatorCountryISO, StringLen($sNetworkOperatorCountryISO) - $iOffset)
		Else
			$sNetworkOperatorCountryISO = StringLeft($sNetworkOperatorCountryISO, $iOffset - 1)
		EndIf
	EndIf
	Return $sNetworkOperatorCountryISO
EndFunc   ;==>_Android_GetNetworkOperatorCountryISO

Func _Android_GetNetworkType($iSIMNumber = 1)
	Local $sNetworkType, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sNetworkType = _Android_GetProperty($PROPERTY_DATA_NETWORK_TYPE)
	$iOffset = StringInStr($sNetworkType, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sNetworkType = StringRight($sNetworkType, StringLen($sNetworkType) - $iOffset)
		Else
			$sNetworkType = StringLeft($sNetworkType, $iOffset - 1)
		EndIf
	EndIf
	Return StringLeft($sNetworkType, StringInStr($sNetworkType, ":") - 1)
EndFunc   ;==>_Android_GetNetworkType

Func _Android_GetSIMState($iSIMNumber = 1)
	Local $sSIMState, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sSIMState = _Android_GetProperty($PROPERTY_SIM_STATE)
	$iOffset = StringInStr($sSIMState, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sSIMState = StringRight($sSIMState, StringLen($sSIMState) - $iOffset)
		Else
			$sSIMState = StringLeft($sSIMState, $iOffset - 1)
		EndIf
	EndIf
	Switch $sSIMState
		Case "ABSENT"
			Return "Absent"
		Case "PIN_REQUIRED"
			Return "PIN Required"
		Case "PUK_REQUIRED"
			Return "PUK Required"
		Case "NETWORK_LOCKED"
			Return "Network Locked"
		Case "READY"
			Return "Ready"
		Case Else
			Return "Unknown"
	EndSwitch
EndFunc   ;==>_Android_GetSIMState

Func _Android_GetSIMOperatorName($iSIMNumber = 1)
	Local $sSIMOperatorName, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sSIMOperatorName = _Android_GetProperty($PROPERTY_ICC_OPERATOR_ALPHA)
	$iOffset = StringInStr($sSIMOperatorName, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sSIMOperatorName = StringRight($sSIMOperatorName, StringLen($sSIMOperatorName) - $iOffset)
		Else
			$sSIMOperatorName = StringLeft($sSIMOperatorName, $iOffset - 1)
		EndIf
	EndIf
	Return $sSIMOperatorName
EndFunc   ;==>_Android_GetSIMOperatorName

Func _Android_GetSIMOperator($iSIMNumber = 1)
	Local $sSIMOperator, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sSIMOperator = _Android_GetProperty($PROPERTY_ICC_OPERATOR_NUMERIC)
	$iOffset = StringInStr($sSIMOperator, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sSIMOperator = StringRight($sSIMOperator, StringLen($sSIMOperator) - $iOffset)
		Else
			$sSIMOperator = StringLeft($sSIMOperator, $iOffset - 1)
		EndIf
	EndIf
	Return $sSIMOperator
EndFunc   ;==>_Android_GetSIMOperator

Func _Android_GetSIMOperatorCountryISO($iSIMNumber = 1)
	Local $sSIMOperatorCountryISO, $iOffset
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sSIMOperatorCountryISO = _Android_GetProperty($PROPERTY_ICC_OPERATOR_ISO_COUNTRY)
	$iOffset = StringInStr($sSIMOperatorCountryISO, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sSIMOperatorCountryISO = StringRight($sSIMOperatorCountryISO, StringLen($sSIMOperatorCountryISO) - $iOffset)
		Else
			$sSIMOperatorCountryISO = StringLeft($sSIMOperatorCountryISO, $iOffset - 1)
		EndIf
	EndIf
	Return $sSIMOperatorCountryISO
EndFunc   ;==>_Android_GetSIMOperatorCountryISO

Func _Android_GetProperty($sPropertyName)
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sOutput = StringStripWS(_Android_Shell("getprop " & $sPropertyName), 3)
	Return $sOutput
EndFunc   ;==>_Android_GetProperty

Func _Android_IsDeviceOnline()
	Local $sOutput, $bDeviceOnline = False
	$sOutput = StringStripWS(__Run("@echo off && for /f ""skip=1 tokens=* delims="" %i in ('adb devices') do echo.%i"), 3)
	If $sOutput <> "" Then $bDeviceOnline = True
	Return $bDeviceOnline
EndFunc   ;==>_Android_IsDeviceOnline

Func _Android_IsDeviceBootloader()
	Local $sOutput, $bDeviceBootloader = False
	$sOutput = StringStripWS(__Run("fastboot devices"), 3)
	If $sOutput <> "" Then $bDeviceBootloader = True
	Return $bDeviceBootloader
EndFunc   ;==>_Android_IsDeviceBootloader

Func _Android_IsDeviceOffline()
	Return Not (_Android_IsDeviceOnline() Or _Android_IsDeviceBootloader())
EndFunc   ;==>_Android_IsDeviceOffline

Func _Android_IsDeviceTablet()
	Return StringInStr(_Android_GetProperty("ro.build.characteristics"), "tablet") <> 0
EndFunc   ;==>_Android_IsDeviceTablet

Func _Android_IsDeviceRooted()
	Local $sOutput, $bRootAccess = False
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, $bRootAccess)
	$sOutput = StringStripWS(_Android_ShellAsRoot("echo Root Checker"), 3)
	If $sOutput = "Root Checker" Then $bRootAccess = True
	Return $bRootAccess
EndFunc   ;==>_Android_IsDeviceRooted

Func _Android_IsNetworkRoaming($iSIMNumber = 1)
	Local $sNetworkRoaming, $iOffset, $bNetworkRoaming = False
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, $bNetworkRoaming)
	$sNetworkRoaming = _Android_GetProperty($PROPERTY_OPERATOR_ISROAMING)
	$iOffset = StringInStr($sNetworkRoaming, ",")
	If $iOffset <> 0 Then
		If $iSIMNumber = 2 Then
			$sNetworkRoaming = StringRight($sNetworkRoaming, StringLen($sNetworkRoaming) - $iOffset)
		Else
			$sNetworkRoaming = StringLeft($sNetworkRoaming, $iOffset - 1)
		EndIf
	EndIf
	If $sNetworkRoaming = "true" Then $bNetworkRoaming = True
	Return $bNetworkRoaming
EndFunc   ;==>_Android_IsNetworkRoaming

Func __Run($sCommand)
	Local $iPID, $sLine, $sOutput = ""
	$iPID = Run(@ComSpec & " /c " & $sCommand, $sBinaryPath, @SW_HIDE, $STDERR_CHILD + $STDOUT_CHILD)
	While 1
		$sLine = StdoutRead($iPID)
		If @error Then ExitLoop
		$sOutput &= $sLine
	WEnd
	Return SetError(@error, @extended, $sOutput)
EndFunc   ;==>__Run

Func __URLEncode($sURL)
	Local $aChar, $sEncode = ""
	$aChar = StringSplit($sURL, "")
	For $i = 1 To $aChar[0]
		If Not StringInStr("$-_.+!*'(),;/?:@=&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890", $aChar[$i]) Then
			$sEncode &= "%" & Hex(Asc($aChar[$i]), 2)
		Else
			$sEncode &= $aChar[$i]
		EndIf
	Next
	Return $sEncode
EndFunc   ;==>__URLEncode

Func __Android_GenerateProductID($sDeviceModel, $sDeviceID)
	_Crypt_Startup()
	Local $sData, $aChar, $aProductID[8] = [0, 0, 0, 0, 0, 0, 0, 0]
	$sData = _Crypt_HashData($sDeviceModel & $sDeviceID, $CALG_MD5)
	$aChar = StringSplit(__Hex(BitXOR(Dec(StringMid($sData, 3, 8)), Dec(StringRight($sData, 8)))), "")
	For $i = 1 To $aChar[0]
		If StringInStr("ABCDEF", $aChar[$i]) Then
			$aProductID[$i - 1] = Chr(Asc($aChar[$i]) - 17)
		Else
			$aProductID[$i - 1] = $aChar[$i]
		EndIf
	Next
	_Crypt_Shutdown()
	Return _ArrayToString($aProductID, "")
EndFunc   ;==>__Android_GenerateProductID

Func __Hex($iDec)
	Local $sHex = Hex($iDec)
	While StringLeft($sHex, 1) = "0"
		$sHex = StringMid($sHex, 2)
		If StringLeft($sHex, 1) <> "0" Then ExitLoop
	WEnd
	Return $sHex
EndFunc   ;==>__Hex

Func __Android_GetBatteryInfo($sBatteryReceiver)
	Local $sOutput
	If Not _Android_IsDeviceOnline() Then Return SetError(1, 0, "Unknown")
	$sOutput = StringStripWS(__Run("@echo off && for /f ""tokens=2 delims=:"" %i in ('adb shell ""dumpsys battery"" ^| find /i """ & $sBatteryReceiver & """') do echo.%i"), 3)
	Return $sOutput
EndFunc   ;==>__Android_GetBatteryInfo
