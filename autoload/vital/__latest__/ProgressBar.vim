function! s:_vital_loaded(V) abort
  let s:Dict = a:V.import('Data.Dict')
  let s:Guard = a:V.import('Vim.Guard')
  let s:config = {
        \ 'default_barwidth': 80,
        \ 'default_nullchar': '.',
        \ 'default_fillchar': '|',
        \ 'default_format': '%(prefix)s|%(fill)s%(null)s| %(percent)s%%(suffix)s',
        \}
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Data.Dict',
        \ 'Vim.Guard',
        \]
endfunction
function! s:_vital_created(module) abort
endfunction

function! s:_throw(msg) abort
  throw 'vital: ProgressBar: ' . a:msg
endfunction

function! s:get_config() abort
  return copy(s:config)
endfunction
function! s:set_config(config) abort
  call extend(s:config, s:Dict.pick(a:config, [
        \ 'default_barwidth',
        \ 'default_nullchar',
        \ 'default_fillcahr',
        \ 'default_format',
        \]))
endfunction

function! s:new(maxvalue, ...) abort
  let options = extend({
        \ 'barwidth': s:config.default_barwidth,
        \ 'nullchar': s:config.default_nullchar,
        \ 'fillchar': s:config.default_fillchar,
        \ 'format': s:config.default_format,
        \ 'prefix': '',
        \ 'suffix': '',
        \ 'statusline': 0,
        \}, get(a:000, 0, {}))
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
        \ 'statusline': options.statusline,
        \ 'current': 0,
        \})
  if instance.statusline && !has('vim_starting')
    let instance._guard = s:Guard.store(
          \ '&l:statusline',
          \)
  else
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
function! s:instance.construct() abort
  let percent = float2nr(self.current / str2float(self.maxvalue) * 100)
  let fillwidth = float2nr(ceil(self.current * self.alpha))
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
  let indicator = self.construct()
  if self.statusline
    let &l:statusline = indicator
    redrawstatus
  else
    redraw | echo indicator
  endif
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
