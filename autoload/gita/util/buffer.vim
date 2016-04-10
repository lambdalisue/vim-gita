let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Buffer = s:V.import('Vim.Buffer')
let s:BufferManager = s:V.import('Vim.BufferManager')

function! s:is_preview(opener) abort
  if a:opener =~# '\%(^\|\W\)\%(pta\|ptag\)!\?\%(\W\|$\)'
    return 1
  elseif a:opener =~# '\%(^\|\W\)\%(ped\|pedi\|pedit\)!\?\%(\W\|$\)'
    return 1
  elseif a:opener =~# '\%(^\|\W\)\%(ps\|pse\|psea\|psear\|psearc\|psearch\)!\?\%(\W\|$\)'
    return 1
  endif
  return 0
endfunction

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
          \ 'preview': s:is_preview(config.opener),
          \}
  else
    let vname = '_buffer_manager_' . config.window
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
          \ 'preview': s:is_preview(config.opener),
          \}
  endif
  if !empty(config.selection)
    if !result.preview
      call gita#util#buffer#select(config.selection)
    else
      noautocmd keepjumps wincmd P
      call gita#util#buffer#select(config.selection)
      noautocmd keepjumps normal! zz
      noautocmd keepjumps wincmd p
    endif
  endif
  return result
endfunction

function! gita#util#buffer#read_content(...) abort
  call call(s:Buffer.read_content, a:000, s:Buffer)
endfunction

function! gita#util#buffer#edit_content(...) abort
  call call(s:Buffer.edit_content, a:000, s:Buffer)
endfunction

function! gita#util#buffer#select(selection, ...) abort
  " Original from mattn/emmet-vim
  " https://github.com/mattn/emmet-vim/blob/master/autoload/emmet/util.vim#L75-L79
  let prefer_visual = get(a:000, 0, 0)
  let line_start = get(a:selection, 0, line('.'))
  let line_end = get(a:selection, 1, line_start)
  if line_start == line_end && !prefer_visual
    call setpos('.', [0, line_start, 1, 0])
  else
    call setpos('.', [0, line_end, 1, 0])
    keepjump normal! v
    call setpos('.', [0, line_start, 1, 0])
  endif
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
