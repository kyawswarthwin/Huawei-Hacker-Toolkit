#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Icon.ico
#AutoIt3Wrapper_Outfile=Release\Huawei Hacker Toolkit.exe
#AutoIt3Wrapper_Res_Description=Huawei Hacker Toolkit
#AutoIt3Wrapper_Res_Fileversion=1.2.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Copyright © 2014 Kyaw Swar Thwin
#AutoIt3Wrapper_Res_Language=1033
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#pragma compile(AutoItExecuteAllowed, true)
#include "MCFinclude.au3"

If Not @Compiled Then Exit

Run(@ScriptFullPath & ' /AutoIt3ExecuteScript "' & @ScriptDir & '\Data.dat"')
