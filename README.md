# RI.ASM  Revision 2.12
[ July 12, 1994 ]

' Revision V2.12 @ DOS

Copyright (c) 1989-1994 by Yellow Rose Software Co.

Written by Mr. Leijun @Kingsoft

Function:

Press HotKey (default is holding both the left and right Ctrl keys) to remove all TSR programs after this program.
More usages can be displayed after running "**RI.com /?**"

# Build tips
Build environment recommeded：

MSDOS v6,**TASM** v4.

MASM can't recognize some instructions such as "locals".

Step1: **tasm RI**

Step2: **tlink/t RI**

Step3: **RI.com** generated, Enjoy!


If the error message **"can't find dpmi16bi.ovl"** appears at step2, You can find and alternate the linker to **tlink.exe** in Turbo C v2.0 or Turbo C++ v1.01 above.
