# Vim to RTF

Converts the current buffer or visually selected text to syntax highlighted RTF
text and puts it in the paste buffer.

Watch it in action:

<video src="https://github.com/tenderlove/vim-to-rtf/assets/3124/f50894d9-1eff-44c6-9531-e85f15bc7171" width="300"></video>

Inspired by [vim-copy-as-rtf](https://github.com/zerowidth/vim-copy-as-rtf).

I wrote this because I write code examples in Vim, and I want to paste them
in to Keynote but maintain the syntax highlighting.  I've been using
vim-copy-as-rtf for years, but it uses a macOS utility called `textutil`, and
that utility has started giving me problems.  vim-copy-as-rtf would convert
the source to HTML, then use `textutil` to convert the HTML to RTF.  This
plugin directly converts the text to RTF without an intermediate HTML file.

## Installation

```
$ git submodule add https://github.com/tenderlove/vim-to-rtf.git pack/dist/start/vim-to-rtf
```

## Usage

Convert the entire buffer to RTF and put it in the paste buffer:

```
:ToRTF
```

To select lines and put in the paste buffer, just visual select, then do

```
:ToRTF
```

## Configuration

The default font it uses is `Arial`, but you can change it like this:

```vim
g:tortf_font = "SF Mono"
```

No font size is specified by default, but you can specify a font size like this:

```vim
g:tortf_font_size = 32
```
