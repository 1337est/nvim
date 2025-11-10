if exists('b:current_syntax')
  finish
endif

let b:current_syntax = 'mbsync'

let s:cpo_save = &cpo
set cpo&vim

" ========================
" OPTIONS - Extracted from mbsync(1)
" ========================
" All Stores
syntax match mbsyncOption /^\<\(Path\|MaxSize\|MapInbox\|Flatten\|Trash\|TrashNewOnly\|TrashRemoteNew\)\>/
" Maildir Stores
syntax match mbsyncOption /^\<\(MaildirStore\|AltMap\|Inbox\|InfoDelimiter\|SubFolders\)\>/
" IMAP4 Account
syntax match mbsyncOption /^\<\(IMAPAccount\|Host\|Port\|Timeout\|User\|UserCmd\|Pass\|PassCmd\|Tunnel\|AuthMechs\|TLSType\|TLSVersions\|SystemCertificates\|CertificateFile\|ClientCertificate\|ClientKey\|PipelineDepth\|DisableExtension.*\)\>/
" IMAP Stores
syntax match mbsyncOption /^\<\(IMAPStore\|Account\|UseNameSpace\|PathDelimiter\)\>/
" Channels
syntax match mbsyncOption /^\<\(Channel\|Master\|Slave\|Far\|Near\|Pattern\|Patterns\|MaxSize\|MaxMessages\|ExpireUnread\|Sync\|Create\|Remove\|Expunge\|CopyArrivalDate\|SyncState\)\>/
" Groups
syntax match mbsyncOption /^\<\(Group\|Channel\)\>/
" Global
syntax match mbsyncOption /^\<\(FSync\|FieldDelimiter\|BufferLimit\)\>/

" ========================
" VALIDATION FOR OPTIONS
" ========================
" Options that accept only yes|no values
syntax match mbsyncWrongOption /^\<\(TrashNewOnly\|TrashRemoteNew\|AltMap\|SystemCertificates\|UseNameSpace\|ExpireUnread\|CopyArrivalDate\|FSync\) \(yes$\|no$\)\@!.*$/
" Option SubFolders accepts Verbatim|Maildir++|Legacy
syntax match mbsyncWrongOption /^\<\(SubFolders\) \(Verbatim$\|Maildir++$\|Legacy$\)\@!.*$/
" Option TLSType accepts None|STARTTLS|IMAPS
syntax match mbsyncWrongOption /^\<\(TLSType\) \(None$\|STARTTLS$\|IMAPS$\)\@!.*$/
" Option TLSVersions accepts +1.0|-1.1|+1.2|-1.3
syn match mbsyncWrongOption /^\<\(TLSVersions\) \([+-]\)\(1\.0$\|1\.1$\|1\.2$\|1\.3$\)\@!.*$/
" Option Sync
syntax match mbsyncWrongOption /^\<\(Sync\) \(None$\|Pull$\|Push$\|New$\|ReNew$\|Delete$\|Flags$\|All$\)\@!.*$/
" Options Create|Remove|Expunge accept None|Master|Slave|Far|Near|Both
syntax match mbsyncWrongOption /^\<\(Create\|Remove\|Expunge\) \(None$\|Master$\|Slave$\|Far$\|Near$\|Both$\)\@!.*$/
" Marks all wrong option values as errors.
syntax match mbsyncWrongOptionValue /\S* \zs.*$/ contained containedin=mbsyncWrongOption
" Mark the option part as a normal option.
highlight default link mbsyncWrongOption mbsyncOption

" ========================
" SPECIAL SYNTAX ELEMENTS
" ========================
" Email Addresses (yanked from esmptrc)
syntax match mbsyncAddress      /[a-z0-9_.-]*[a-z0-9]\+@[a-z0-9_.-]*[a-z0-9]\+\.[a-z]\+/
" Host names
syntax match mbsyncHost         /[a-z0-9_.-]\+\.[a-z]\+$/
" Numeric values
syntax match mbsyncNumber       /\<\(\d\+$\)/
" File Sizes
syntax match mbsyncNumber       /\d\+[k|m][b]/
" Master|Slave stores
syntax match mbsyncStores       /:[^-].*:[^-]*$/
" Strings
syntax region mbsyncString start=/"/ end=/"/
syntax region mbsyncString start=/'/ end=/'/
" Comments
syntax match mbsyncComment      /#.*$/ contains=@Spell
" File/Dir paths - Neovim exclusive
if has ('nvim')
  syntax match mbsyncPath "~\%(/[^/]\+\)\+"
endif

" ========================
" HIGHLIGHT GROUPS
" ========================
highlight default link mbsyncAddress            Constant
highlight default link mbsyncComment            Comment
highlight default link mbsyncHost               Constant
highlight default link mbsyncNumber             Number
highlight default link mbsyncOption             Type
highlight default link mbsyncPath               Constant
highlight default link mbsyncStores             Identifier
highlight default link mbsyncString             String
highlight default link mbsyncWrongOptionValue   Error

" Restore previous 'cpo' settings
let &cpo = s:cpo_save
unlet s:cpo_save
