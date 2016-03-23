function! s:action(candidate, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_opener(options)
  call gita#option#assign_selection(options)
  let options.selection = get(a:candidate, 'selection', options.selection)
  let args = [
        \ empty(options.anchor) ? '' : '--anchor',
        \ empty(options.opener) ? '' : '--opener=' . shellescape(options.opener),
        \ empty(options.selection) ? '' : '--selection=' . printf('%d-%d',
        \   options.selection[0], get(options.selection, 1, options.selection[0])
        \ ),
        \]
  let args += [
        \ get(a:candidate, 'commit', get(options, 'commit', '""')),
        \ fnameescape(a:candidate.path),
        \]
  execute 'Gita blame ' . join(filter(args, '!empty(v:val)'))
endfunction

function! gita#action#blame#define(disable_mappings) abort
  call gita#action#define('blame', function('s:action'), {
        \ 'description': 'Blame a content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  if a:disable_mappings
    return
  endif
  nmap <buffer><nowait><expr> BB gita#action#smart_map('BB', '<Plug>(gita-blame)')
endfunction

call gita#util#define_variables('action#blame', {
      \ 'default_opener': '',
      \})
