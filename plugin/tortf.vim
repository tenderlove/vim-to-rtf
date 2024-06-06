vim9script

import autoload "tortf.vim"

def ToRTF(f: number, g: number)
  call tortf#ToRTF(f, g)
enddef

command! -range=% ToRTF :call ToRTF(<line1>, <line2>)
