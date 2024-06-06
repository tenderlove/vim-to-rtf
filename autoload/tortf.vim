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
  def ColorIndex(rgb: string): number
    if !has_key(this.indexMap, rgb)
      this.indexMap[rgb] = this.mapIndex
      this.mapIndex = this.mapIndex + 1
    endif

    return this.indexMap[rgb]
  enddef

  # Returns the sorted color map so we can transform it in to an RTF color table
  def ColorIndexes(): list<any>
    var colormap = items(this.indexMap)

    sort(colormap, (i1, i2) => i1[1] - i2[1] )

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

    for [rgb, i] in colormap
      var r = str2nr(strpart(rgb, 0, 2), 16)
      var g = str2nr(strpart(rgb, 2, 2), 16)
      var b = str2nr(strpart(rgb, 4, 2), 16)
      add(colors, "\\red" .. r .. "\\green" .. g .. "\\blue" .. b)
    endfor

    return "{\\colortbl;" .. join(colors, ";") .. ";}"
  enddef

  def _RGB(syntaxID: number, text: string): string
    var syntax = synIDtrans(syntaxID)
    return strpart(synIDattr(syntax, "fg#"), 1, 6)
  enddef

  def _ColorIndex(syntaxID: number, text: string): number
    return this.colorMap.ColorIndex(this._RGB(syntaxID, text))
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

      # If there are non-ascii characters, we need to escape them
      if str =~ '[^\U0000-\U007F]'
        str = substitute(str, '[^\U0000-\U007F]',
          (m) => this._ConvertUnicode(m[0]), "g")
      endif

      return "\\cf" .. colorIdx .. " " .. str
    endif
  enddef

  def _ConvertUnicode(char: string): string
    var value = char2nr(char, 1)

    # If the character is too big, encode it as a surrogate pair
    if value > 0xFFFF
      value = value - 0x10000
      var upper = or(0xD800, and(value >> 10, 0x3FF))
      var lower = or(0xDC00, and(0x3FF, value))
      return "\\u" .. upper .. " \\u" .. lower .. "?"
    else
      # RTF uses signed integers, so if it's too big, encode it as negative
      if value > 0x7FFF
        return "\\u" .. (value - 0x10000) .. "?"
      else
        return "\\u" .. value .. "?"
      endif
    endif
  enddef
endclass

export def ToRTF(start: number, finish: number): void
  var line = start

  var rtfFilename = tempname() .. ".rtf"
  var newbuf = bufnr(rtfFilename, 1)
  bufload(newbuf)
  setbufline(newbuf, 1, "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2636")

  var font = get(g:, 'tortf_font', "Courier")

  appendbufline(newbuf, "$", "{\\fonttbl{\\f0 " .. font .. ";}}")
  appendbufline(newbuf, "$", "{\\f0")

  if has_key(g:, "tortf_font_size")
    appendbufline(newbuf, "$", "\\fs" .. g:tortf_font_size * 2)
  endif

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

      # synID is per byte, so we need to take byte slices
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
