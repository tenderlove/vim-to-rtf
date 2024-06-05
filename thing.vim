vim9script

class RTFEscape
  def new()
  enddef

  def EscapeChunk(colorIdx: number, text: string): string
    if text !~ '\S'
      # If it's only whitespace, return whitespace
      return text
    else
      var str = text

      if text =~ '^[0-9 ]'
        # No numbers or spaces right after a command
        str = " " .. text
      endif

      if str =~ '[\\{}]'
        str = substitute(str, "[\\{}]", '\\\0', "g")
      endif

      return "\\cf" .. colorIdx .. str
    endif
  enddef
endclass

class ColorMap
  var indexMap: dict<any>
  var mapIndex: number

  def new()
    this.indexMap = {}
    this.mapIndex = 1
  enddef

  def ColorIndex(r: number, b: number, g: number): number
    if !has_key(this.indexMap, r)
      this.indexMap[r] = {}
    endif

    var blues = this.indexMap[r]

    if !has_key(blues, b)
      blues[b] = {}
    endif

    var greens = blues[b]

    if !has_key(greens, g)
      greens[g] = this.mapIndex
      this.mapIndex = this.mapIndex + 1
    endif

    return greens[g]
  enddef

  def RTFColorTable(): string
    var colormap = []

    for [red, greens] in items(this.indexMap)
      for [green, blues] in items(greens)
        for [blue, index] in items(blues)
          add(colormap, [red, green, blue, index])
        endfor
      endfor
    endfor

    sort(colormap, (i1, i2) => i1[3] - i2[3] )

    var colors = []

    for [r, g, b, i] in colormap
      add(colors, "\\red" .. r .. "\\green" .. g .. "\\blue" .. b)
    endfor

    return "{\\colortbl;" .. join(colors, ";") .. ";}"
  enddef
endclass

def ScanFile(start: number, finish: number): void
  var line = start

  var newbuf = bufnr("temp", 1)
  bufload(newbuf)
  setbufline(newbuf, 1, "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2636")
  appendbufline(newbuf, "$", "{\\fonttbl{\\f0 Inconsolata;}}")
  appendbufline(newbuf, "$", "{\\f0")

  var colorMap = ColorMap.new()
  var rtfEscape = RTFEscape.new()

  # For each line
  while line <= finish
    var column = 0
    var linelen = strlen(getline(line))

    var rtfLine = []

    # For each column
    while column < linelen
      var span = column
      var bytes = 0
      var syntaxID = synID(line, span + 1, 1)

      while span < linelen && syntaxID == synID(line, span + 1, 1)
        bytes += 1
        span += 1
      endwhile

      var syntax = synIDtrans(syntaxID)
      var fg_color_str = strpart(synIDattr(syntax, "fg#"), 1, 6)

      var r = str2nr(strpart(fg_color_str, 0, 2), 16)
      var b = str2nr(strpart(fg_color_str, 2, 2), 16)
      var g = str2nr(strpart(fg_color_str, 4, 2), 16)

      var fg_color = [r, b, g]

      var colorIdx = colorMap.ColorIndex(r, b, g)

      # bytes is probably wrong. We need to test with multibyte chars
      var text = strpart(getline(line), column, bytes)

      add(rtfLine, rtfEscape.EscapeChunk(colorIdx, text))

      #echom "[" .. color_idx .. "] " .. fg_color_str .. string(fg_color) .. strpart(getline(line), column, bytes)

      column = span

    endwhile

    appendbufline(newbuf, "$", join(rtfLine, "") .. "\\")
    line = line + 1
  endwhile

  appendbufline(newbuf, 1, colorMap.RTFColorTable())
  appendbufline(newbuf, "$", "}")
  appendbufline(newbuf, "$", "}")
  execute ":sbu " .. newbuf
enddef

def g:AaronRTF(): void
  ScanFile(1, line("$"))
enddef
