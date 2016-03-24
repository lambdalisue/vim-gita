let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Buffer = s:V.import('Vim.Buffer')
let s:BufferManager = s:V.import('Vim.BufferManager')

function! gita#util#buffer#open(name, ...) abort
  let config = extend({
        \ 'opener': '',
        \ 'window': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let config.opener = empty(config.opener) ? 'edit' : config.opener
  if empty(config.window)
    let loaded = s:Buffer.open(a:name, config.opener)
    let bufnum = bufnr('%')
    let result = {
          \ 'loaded': loaded,
          \ 'bufnum': bufnum,
          \}
  else
    let vname = printf('_buffer_manager_%s', config.window)
    if !has_key(s:, vname)
      let s:{vname} = s:BufferManager.new()
    endif
    let ret = s:{vname}.open(a:name, s:Dict.pick(config, [
          \ 'opener',
          \ 'range',
          \]))
    let result = {
          \ 'loaded': ret.loaded,
          \ 'bufnum': ret.bufnr,
          \}
  endif
  if !empty(config.selection)
    call gita#util#select(config.selection)
  endif
  return result
endfunction

function! gita#util#buffer#read_content(...) abort
  call call(s:Buffer.read_content, a:000, s:Buffer)
endfunction

function! gita#util#buffer#edit_content(...) abort
  call call(s:Buffer.edit_content, a:000, s:Buffer)
endfunction

function! gita#util#buffer#parse_cmdarg(...) abort
  let cmdarg = get(a:000, 0, v:cmdarg)
  let options = {}
  if cmdarg =~# '++enc='
    let options.encoding = matchstr(cmdarg, '++enc=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++ff='
    let options.fileformat = matchstr(cmdarg, '++ff=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++bad='
    let options.bad = matchstr(cmdarg, '++bad=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++bin'
    let options.binary = 1
  endif
  if cmdarg =~# '++nobin'
    let options.nobinary = 1
  endif
  if cmdarg =~# '++edit'
    let options.edit = 1
  endif
  return options
endfunction

