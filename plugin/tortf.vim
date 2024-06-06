vim9script

import autoload "tortf.vim"

func ToRTF() range
  call tortf#ToRTF(a:firstline, a:lastline)
endfunc

command! -range=% ToRTF :<line1>,<line2>call ToRTF()
