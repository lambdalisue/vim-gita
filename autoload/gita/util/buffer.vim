let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Buffer = s:V.import('Vim.Buffer')
let s:BufferManager = s:V.import('Vim.BufferManager')

function! gita#util#buffer#open(name, ...) abort
  let config = get(a:000, 0, {})
  let group  = get(config, 'group', '')
  if empty(group)
    let loaded = s:Buffer.open(a:name, get(config, 'opener', 'edit'))
    let bufnum = bufnr('%')
    return {
          \ 'loaded': loaded,
          \ 'bufnum': bufnum,
          \}
  else
    let vname = printf('_buffer_manager_%s', group)
    if !has_key(s:, vname)
      let s:{vname} = s:BufferManager.new()
    endif
    let ret = s:{vname}.open(a:name, s:Dict.pick(config, [
          \ 'opener',
          \ 'range',
          \]))
    return {
          \ 'loaded': ret.loaded,
          \ 'bufnum': ret.bufnr,
          \}
  endif
endfunction

function! gita#util#buffer#read_content(...) abort
  call call(s:Buffer.read_content, a:000, s:Buffer)
endfunction

function! gita#util#buffer#edit_content(...) abort
  call call(s:Buffer.edit_content, a:000, s:Buffer)
endfunction
