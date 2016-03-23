function! s:_vital_loaded(V) abort
  let s:Guard = a:V.import('Vim.Guard')
endfunction

function! s:_vital_depends() abort
  return ['Vim.Guard']
endfunction

function! s:_throw(msg) abort
  throw 'vital: ProgressBar: ' . a:msg
endfunction

function! s:new(maxvalue, ...) abort
  let options = extend({
        \ 'barwidth': 80,
        \ 'nullchar': '.',
        \ 'fillchar': '|',
        \ 'format': '%(prefix)s|%(fill)s%(null)s| %(percent)s%%(suffix)s',
        \ 'prefix': '',
        \ 'suffix': '',
        \ 'method': 'echo'
        \}, get(a:000, 0, {}))
  " Validate
  if index(['echo', 'statusline'], options.method) == -1
    call s:_throw(printf('"%s" is not a valid method', options.method))
  elseif options.method ==# 'statusline' && has('vim_starting')
    call s:_throw('"statusline" method could not be used in "vim_starting"')
  endif
  " Calculate alpha value
  let maxvalue = str2nr(a:maxvalue)
  let barwidth = str2nr(options.barwidth)
  let alpha = barwidth / str2float(maxvalue)
  let instance = extend(deepcopy(s:instance), {
        \ 'maxvalue': maxvalue,
        \ 'barwidth': barwidth,
        \ 'alpha': alpha,
        \ 'nullchar': options.nullchar,
        \ 'fillchar': options.fillchar,
        \ 'nullbar': repeat(options.nullchar, barwidth),
        \ 'fillbar': repeat(options.fillchar, barwidth),
        \ 'format': options.format,
        \ 'prefix': options.prefix,
        \ 'suffix': options.suffix,
        \ 'method': options.method,
        \ 'current': 0,
        \})
  " Lock readonly options; options which require to be initialized or involved
  " in .new() method. Users require to create a new progressbar instance if
  " they want to modify such options
  lockvar instance.maxvalue
  lockvar instance.barwidth
  lockvar instance.alpha
  lockvar instance.nullchar
  lockvar instance.fillchar
  lockvar instance.nullbar
  lockvar instance.fillbar
  lockvar instance.method
  if instance.method ==# 'statusline'
    let instance._guard = s:Guard.store(
          \ '&l:statusline',
          \)
  elseif instance.method ==# 'echo'
    let instance._guard = s:Guard.store(
          \ '&more',
          \ '&showcmd',
          \ '&ruler',
          \)
    set nomore
    set noshowcmd
    set noruler
  endif
  call instance.redraw()
  return instance
endfunction

let s:instance = {}

function! s:instance.construct(value) abort
  let percent = float2nr(a:value / str2float(self.maxvalue) * 100)
  let fillwidth = float2nr(ceil(a:value * self.alpha))
  let nullwidth = self.barwidth - fillwidth
  let fillstr = fillwidth == 0 ? '' : self.fillbar[ : fillwidth-1]
  let nullstr = nullwidth == 0 ? '' : self.nullbar[ : nullwidth-1]
  let indicator = self.format
  let indicator = substitute(indicator, '%(prefix)s', self.prefix, '')
  let indicator = substitute(indicator, '%(suffix)s', self.suffix, '')
  let indicator = substitute(indicator, '%(fill)s', fillstr, '')
  let indicator = substitute(indicator, '%(null)s', nullstr, '')
  let indicator = substitute(indicator, '%(percent)s', percent, '')
  return indicator
endfunction

function! s:instance.redraw() abort
  let indicator = self.construct(self.current)
  if indicator ==# get(self, '_previous', '')
    " skip
    return
  endif
  if self.method ==# 'statusline'
    let &l:statusline = indicator
    redrawstatus
  elseif self.method ==# 'echo'
    redraw | echo indicator
  endif
  let self._previous = indicator
endfunction

function! s:instance.update(...) abort
  let value = get(a:000, 0, self.current + 1)
  let self.current = value > self.maxvalue ? self.maxvalue : value
  call self.redraw()
endfunction

function! s:instance.exit() abort
  let self.current = self.maxvalue
  call self.redraw()
  if has_key(self, '_guard')
    call self._guard.restore()
  endif
endfunction
