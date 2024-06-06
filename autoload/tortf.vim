vim9script

# This class keeps track of the colors we've encountered while processing
# We use it to emit a "color table" used by RTF.  Colored text needs to
# refer to a color in the color map by index, so this class returns the
# index corresponding to the text's color
class ColorMap
  var indexMap: dict<any>
  var mapIndex: number

  def new()
    this.indexMap = {}
    this.mapIndex = 1
  enddef

  # Find the color table index for r, g, b
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

  # Returns the sorted color map so we can transform it in to an RTF color table
  def ColorIndexes(): list<any>
    var colormap = []

    for [red, greens] in items(this.indexMap)
      for [green, blues] in items(greens)
        for [blue, index] in items(blues)
          add(colormap, [red, green, blue, index])
        endfor
      endfor
    endfor

    sort(colormap, (i1, i2) => i1[3] - i2[3] )

    return colormap
  enddef
endclass

# Converts text to RTF
class RTFHighlight
  var colorMap: ColorMap

  def new()
    this.colorMap = ColorMap.new()
  enddef

  def Highlight(syntaxID: number, text: string): string
    var colorIdx = this._ColorIndex(syntaxID, text)

    var syntax = synIDtrans(syntaxID)
    var bold = synIDattr(syntax, "bold") == "1"
    var italic = synIDattr(syntax, "italic") == "1"

    if bold || italic
      var header = "{" .. (bold ? "\\b1 " : "") .. (italic ? "\\i1 " : "")
      return header .. this._EscapeChunk(colorIdx, text) .. "}"
    else
      return this._EscapeChunk(colorIdx, text)
    endif
  enddef

  def RTFColorTable(): string
    var colormap = this.colorMap.ColorIndexes()
    var colors = []

    for [r, g, b, i] in colormap
      add(colors, "\\red" .. r .. "\\green" .. g .. "\\blue" .. b)
    endfor

    return "{\\colortbl;" .. join(colors, ";") .. ";}"
  enddef

  def _RGB(syntaxID: number, text: string): list<number>
    var syntax = synIDtrans(syntaxID)
    var fg_color_str = strpart(synIDattr(syntax, "fg#"), 1, 6)

    var r = str2nr(strpart(fg_color_str, 0, 2), 16)
    var g = str2nr(strpart(fg_color_str, 2, 2), 16)
    var b = str2nr(strpart(fg_color_str, 4, 2), 16)
    return [r, g, b]
  enddef

  def _ColorIndex(syntaxID: number, text: string): number
    var [r, b, g] =  this._RGB(syntaxID, text)

    return this.colorMap.ColorIndex(r, b, g)
  enddef

  def _EscapeChunk(colorIdx: number, text: string): string
    if text !~ '\S'
      # If it's only whitespace, return whitespace
      return text
    else
      var str = text

      if str =~ '[\\{}]'
        str = substitute(str, "[\\{}]", '\\\0', "g")
      endif

      return "\\cf" .. colorIdx .. " " .. str
    endif
  enddef
endclass

export def ToRTF(start: number, finish: number): void
  var line = start

  var rtfFilename = tempname() .. ".rtf"
  var newbuf = bufnr(rtfFilename, 1)
  bufload(newbuf)
  setbufline(newbuf, 1, "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2636")

  var font = get(g:, 'tortf_font', "Arial")

  appendbufline(newbuf, "$", "{\\fonttbl{\\f0 " .. font .. ";}}")
  appendbufline(newbuf, "$", "{\\f0")

  var rtfHighlight = RTFHighlight.new()

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

      # bytes is probably wrong. We need to test with multibyte chars
      var text = strpart(getline(line), column, bytes)

      add(rtfLine, rtfHighlight.Highlight(syntaxID, text))

      column = span

    endwhile

    appendbufline(newbuf, "$", join(rtfLine, "") .. "\\")
    line = line + 1
  endwhile

  appendbufline(newbuf, 1, rtfHighlight.RTFColorTable())
  appendbufline(newbuf, "$", "}")
  appendbufline(newbuf, "$", "}")

  silent exe ":sbu " .. newbuf
  silent exe ":w"
  silent exe "!cat " .. rtfFilename .. " | pbcopy"
  silent bd!
  call delete(rtfFilename)
enddef
