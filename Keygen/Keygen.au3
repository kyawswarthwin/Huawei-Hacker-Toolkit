#NoTrayIcon
#include "Include\Registration.au3"
#include <Crypt.au3>

;~ Opt("MustDeclareVars", 1)

Global Const $sAppName = "Handy Toolkit"
Global Const $sAppVersion = "1.0"
Global Const $sAppPublisher = "Kyaw Swar Thwin"
Global Const $sAppURL = "http://codesnack.nazuka.net"

Global Const $vPrivateKey = __GetUniqueKey("{496DA150-1F60-4B1C-9A04-5F0D91098F9F}")

Global $sTitle = $sAppName

;~ ConsoleWrite("Serial Number: " & _Registration_GenerateSerialNumber($vPrivateKey) & @CRLF)

For $i = 1 To 100
	FileWriteLine("Serial Number.txt", _Registration_GenerateSerialNumber($vPrivateKey))
Next

;~ _Registration_Check($sAppName, $sAppURL, $vPrivateKey)

;~ MsgBox($MB_APPLMODAL, $sTitle, "Hello, World!")

Func __GetUniqueKey($vKey)
	_Crypt_Startup()
	Local $dUniqueKey = _Crypt_EncryptData(StringMid(_Crypt_HashFile("Data.dat", $CALG_MD5), 3), $vKey, $CALG_RC4)
	_Crypt_Shutdown()
	Return $dUniqueKey
EndFunc   ;==>__GetUniqueKey
