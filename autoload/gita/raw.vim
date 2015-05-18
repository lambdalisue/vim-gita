let s:save_cpo = &cpo
set cpo&vim


let s:P = gita#utils#import('Prelude')
let s:D = gita#utils#import('Data.Dict')
let s:L = gita#utils#import('Data.List')


function! s:parse_options(opts, scheme) abort " {{{
  let args = []
  for [key, value] in items(a:opts)
    if key =~# '^--$'
      call add(args, '--')
      call add(args, value)
    elseif key =~# '^--'
      if s:P.is_number(value)
        call add(args, key)
      else
        call add(args, printf('%s=%s', key, value))
      endif
    elseif key =~# '^-'
      if s:P.is_number(value)
        call add(args, key)
      else
        call add(args, printf('%s%s', key, value))
      endif
    endif
  endfor
  return args
endfunction " }}}
function! s:validate_options(opts, available_option_keys) abort " {{{
  let invalid_options = s:D.omit(a:opts, a:available_option_keys)
  if !empty(invalid_options)
    call gita#utils#error(
          \ 'vim-gita: The following unknown options are specified:'
          \)
    for key in keys(invalid_options)
      call gita#utils#info(printf('* %s', key))
    endfor
    return 1
  endif
  return 0
endfunction " }}}


function! gita#raw#init(gita, opts) abort " {{{
  let available_option_keys = [
        \ '-q', '--quiet',
        \ '--bare',
        \ '--template',
        \ '--separate-git-dir',
        \ '--shared',
        \ 'directory',
        \]
  if s:validate_options(a:opts, available_option_keys)
    return { 'status': -1 }
  endif
  let args = [
        \ 'init',
        \ s:parse_options(a:opts),
        \ get(a:opts, 'directory', ''),
        \]
  return a:gita.exec(args)
endfunction " }}}
function! gita#raw#add(gita, opts) abort " {{{
  let available_option_keys = [
        \ '-n', '--dry-run',
        \ '-v', '--verbose',
        \ '-f', '--force',
        \ '-i', '--interactive',
        \ '-p', '--patch',
        \ '-e', '--edit',
        \ '-u', '--update',
        \ '-A', '--all', '--no-ignore-removal',
        \ '--no-all', '--ignore-removal',
        \ '-N', '--intent-to-add',
        \ '--refresh',
        \ '--ignore-errors',
        \ '--ignore-missing',
        \ '--',
        \]
  if s:validate_options(a:opts, available_option_keys)
    return { 'status': -1 }
  endif
  let args = [
        \ 'add',
        \ s:parse_options(a:opts),
        \]
  return a:gita.exec(args)
endfunction " }}}
function! gita#raw#rm(gita, opts) abort " {{{
  let available_option_keys = [
        \ '-n', '--dry-run',
        \ '-f', '--force',
        \ '-r',
        \ '--cached',
        \ '--ignore-unmatch',
        \ '-q', '--quiet',
        \ '--',
        \]
  if s:validate_options(a:opts, available_option_keys)
    return { 'status': -1 }
  endif
  let args = [
        \ 'rm',
        \ s:parse_options(a:opts),
        \]
  return a:gita.exec(args)
endfunction " }}}
function! gita#raw#clone(gita, opts) abort " {{{
  let available_option_keys = [
        \ '-l', '--local',
        \ '--no-hardlinks',
        \ '-s', '--shared',
        \ '-n', '--dry-run',
        \ '-f', '--force',
        \ '-r',
        \ '--cached',
        \ '--ignore-unmatch',
        \ '-q', '--quiet',
        \ '--',
        \]
  if s:validate_options(a:opts, available_option_keys)
    return { 'status': -1 }
  endif
  let args = [
        \ 'rm',
        \ s:parse_options(a:opts),
        \]
  return a:gita.exec(args)
endfunction " }}}

function! gita#raw#status(gita, opts) abort " {{{
  let available_option_keys = [
        \ '-s', '--short',
        \ '-b', '--branch',
        \ '--porecelain',
        \ '--long',
        \ '-u', '--untracked-files',
        \ '--ignore-submodules',
        \ '--ignored',
        \ '-z',
        \ '--column', '--no-column',
        \ '--',
        \]
  if s:validate_options(a:opts, available_option_keys)
    return { 'status': -1 }
  endif
  let args = [
        \ 'status',
        \ s:parse_options(a:opts),
        \]
  return a:gita.exec(args)
endfunction " }}}
function! gita#raw#commit(gita, opts) abort " {{{
  let available_option_keys = [
        \ '-a', '--all',
        \ '-p', '--patch',
        \ '-C', '--reuse-message',
        \ '-c', '--reedit-message',
        \ '--fixup',
        \ '--squash',
        \ '--reset-author',
        \ '--short',
        \ '--branch',
        \ '--porcelain',
        \ '--long',
        \ '-z', '--null',
        \ '-F', '--file',
        \ '--author',
        \ '--date',
        \ '-m', '--message',
        \ '-t', '--template',
        \ '-s', '--signoff',
        \ '-n', '--no-verify',
        \ '--allow-empty',
        \ '--allow-empty-message',
        \ '--cleanup',
        \ '-e', '--edit', '--no-edit',
        \ '--amend',
        \ '--no-post-rewrite',
        \ '-i', '--include',
        \ '-o', '--only',
        \ '-u', '--untracked-files',
        \ '-v', '--verbose',
        \ '-q', '--quiet',
        \ '--dry-run',
        \ '--status',
        \ '--no-status',
        \ '-S', '--gpg-sign', '--no-gpg-sign',
        \ '--',
        \]
  if s:validate_options(a:opts, available_option_keys)
    return { 'status': -1 }
  endif
  let args = [
        \ 'commit',
        \ s:parse_options(a:opts),
        \]
  return a:gita.exec(args)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
