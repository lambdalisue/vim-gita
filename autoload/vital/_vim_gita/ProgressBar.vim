let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:Guard = s:V.import('Vim.Guard')
  let s:config = {
        \ 'default_width': 30,
        \}
endfunction

function! s:_vital_depends() abort
  return ['Vim.Guard']
endfunction

function! s:new(max_value, ...) abort
  let options = extend({
        \ 'width': s:config.default_width,
        \}, get(a:000, 0, {}))
  let max_value = str2float(a:max_value)
  let width = str2float(options.width)
  let alpha = width / max_value
  let pb = extend(deepcopy(s:progressbar), {
        \ 'max_value': max_value,
        \ 'width': float2nr(width),
        \ 'alpha': alpha,
        \ 'cursor': 0,
        \ '_guard': s:Guard.store('&statusline'),
        \})
  let &statusline = '|' . repeat('.', float2nr(width)) . '|'
  redrawstatus
  return pb
endfunction

let s:progressbar = {}
function! s:progressbar.update(...) abort
  let next_cursor = get(a:000, 0, self.cursor + 1)
  let self.cursor = next_cursor > self.max_value
        \ ? self.max_value
        \ : next_cursor
  let barwidth = float2nr(self.alpha * self.cursor)
  let &statusline = '|' . repeat('=', barwidth) . repeat('.', self.width - barwidth) . '|'
  redrawstatus
endfunction
function! s:progressbar.exit() abort
  call self._guard.restore()
endfunction
