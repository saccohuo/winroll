NAME=winroll
$(NAME).exe: winrollexe.obj winreg.obj $(NAME).res $(NAME).dll
        \masm32\bin\link /MAP:winrollexe.map /SUBSYSTEM:WINDOWS /LIBPATH:\masm32\lib /OUT:$(NAME).exe winrollexe.obj winreg.obj $(NAME).res
winrollexe.obj: winrollexe.asm
        \masm32\bin\ml /c /coff /Cp  winrollexe.asm
winreg.obj: winreg.asm
        \masm32\bin\ml /c /coff /Cp winreg.asm
$(NAME).res:$(NAME).rc
	\masm32\bin\rc $(NAME).rc
$(NAME).dll: winrolldll.obj winprop.obj
        \masm32\bin\link /MAP:winrolldll.map /SECTION:.data,S /DLL /DEF:winrolldll.def /SUBSYSTEM:WINDOWS /LIBPATH:\masm32\lib winrolldll.obj winprop.obj
winrolldll.obj: winrolldll.asm
        \masm32\bin\ml /c /coff /Cp winrolldll.asm
winprop.obj: winprop.asm
        \masm32\bin\ml /c /coff /Cp winprop.asm
