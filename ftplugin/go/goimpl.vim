function! s:goimpl(...)
  noau update
  let lines = call("s:get_impl", a:000)
  if empty(lines)
    return
  end
  normal %
  call append(line('.'), ['']+lines)
  let @" = join(lines, "\n")
endfunction

function! s:get_current_word()
  let is_strct = v:true
  let word = expand('<cword>')
  if word ==# 'type'
    normal! w
    let word = expand('<cword>')
  elseif word ==# 'struct' || word ==# 'interface'
    normal! B
    let word = expand('<cword>')
  endif
  if getline('.') =~# 'interface'
    let is_strct = v:false
  end
  return [word, is_strct]
endfunction

function! s:get_package_iface(iface, dir)
  let iface = a:iface
  if stridx(iface, ".") == -1 
    silent let package = system(printf('cd %s && go list', shellescape(a:dir)))
    if !empty(package)
      let iface = substitute(package, '[ \t\r\n]', '', 'g') . '.' . iface
    endif
  endif
  return iface
endfunction

function! s:get_impl(...)
  let dir = expand('%:p:h')
  let new = v:false
  " no args
  if empty(a:000)
    let [iface, is_strct] = s:get_current_word()
    if is_strct
      echom "please specify an interface to impl"
      return
    end
    let iface = s:get_package_iface(iface, dir)
    let strct = split(iface, '\.')[-1] ."Impl"
    let new = v:true
  elseif len(a:000) ==# 1
    let [word, is_strct] = s:get_current_word()
    if is_strct
      let strct = word
      let iface = s:get_package_iface(a:000[0], dir)
    else
      let iface = s:get_package_iface(word, dir)
      let strct = a:000[0]
      let new = v:true
    end
  else
    let iface = s:get_package_iface(a:000[0], dir)
    let strct = a:000[1]
    let new = v:true
  endif
  if empty(iface)
    return
  endif
  let impl = printf('%s *%s', tolower(strct[0]), strct)
  let cmd = printf('impl -dir %s %s %s', shellescape(dir), shellescape(impl), iface)
  let out = system(cmd)
  let lines = split(out, '\n')
  if v:shell_error != 0
    echomsg join(lines, "\n")
    return
  endif
  if new
    let lines = ['type ' . strct . ' struct {', '}', ''] + lines
  endif
  return lines
endfunction

command! -nargs=* -buffer GoImpl call s:goimpl(<f-args>)
