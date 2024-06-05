vim9script

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
endclass

def ScanFile(start: number, finish: number): void
  var line = start

  var color_index = {}
  var colorMap = ColorMap.new()

  # For each line
  while line <= finish
    echom "line: " .. line .. ": " .. getline(line)

    var column = 0
    var linelen = strlen(getline(line))

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

      var color_idx = colorMap.ColorIndex(r, b, g)

      echom "[" .. color_idx .. "] " .. fg_color_str .. string(fg_color) .. strpart(getline(line), column, bytes)

      column = span

    endwhile

    line = line + 1
  endwhile
enddef

def g:Aaron(): void
  ScanFile(1, line("$"))
enddef
