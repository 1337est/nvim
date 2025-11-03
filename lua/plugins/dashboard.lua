return {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    dependencies = { { 'nvim-tree/nvim-web-devicons' } },
    config = function()
        require('dashboard').setup {
            theme = 'hyper',
            disable_move = true,
            shortcut_type = 'letter',
            shuffle_letter = false,
            letter_list = 'abcdefghijklmnNopqrstuvwxyz',
            config = {
                header = {
                    '                                                                                                                       ',
                    ' HH   H   HH   HH   H   HH   HH   HH      ee   e   e   ee   ee   e   ee   e       ll   l   l   ll   l   l   ll   ll    ',
                    'H  H  H  H  H H  H  H  H  H H  H H  H    e  e  e   e  e  e e  e  e  e  e  e      l  l  l   l  l  l  l   l  l  l l  l   ',
                    ' HH   H   HH   HH   H   HH   HH   HH      ee   e   e   ee   ee   e   ee   e       ll   l   l   ll   l   l   ll   ll    ',
                    '                                                                                                                       ',
                    '                                                                                                                       ',
                    ' ll   l   l   ll   l   l   ll   ll        oo   o   o   oo   o   o   o   o         ␣␣   ␣␣   ␣   ␣␣   ␣␣   ␣␣   ␣␣   ␣␣ ',
                    'l  l  l   l  l  l  l   l  l  l l  l      o  o  o   o  o  o  o   o   o   o        ␣  ␣ ␣  ␣  ␣  ␣  ␣ ␣  ␣ ␣  ␣ ␣  ␣ ␣  ␣',
                    ' ll   l   l   ll   l   l   ll   ll        oo   o   o   oo   o   o   o   o         ␣␣   ␣␣   ␣   ␣␣   ␣␣   ␣␣   ␣␣   ␣␣ ',
                    '                                                                                                                       ',
                    '                                                                                                                       ',
                    ' WW  WW   WW  WW   WW  WW  WW  WW         oo   o   o   oo   o   o   o   o         rr   r   r   r   rr   rr   r   rr    ',
                    'W  W  W  W  W  W  W  W  W   W   W        o  o  o   o  o  o  o   o   o   o        r  r  r   r   r  r  r r  r  r  r  r   ',
                    ' WW  WWW  WW  WWW  WW  WWW WWW WWW        oo   o   o   oo   o   o   o   o         rr   r   r   r   rr   rr   r   rr    ',
                    '                                                                                                                       ',
                    '                                                                                                                       ',
                    ' ll   l   l   ll   l   l   ll   ll        dd   d   d   dd   dd   d   dd   dd      !!   !!   !   !!   !!   !!   !!   !  ',
                    'l  l  l   l  l  l  l   l  l  l l  l      d  d  d   d  d  d d  d  d  d  d d  d    !  ! !  !  !  !  ! !  ! !  ! !  !  !  ',
                    ' ll   l   l   ll   l   l   ll   ll        dd   d   d   dd   dd   d   dd   dd      !!   !!   !   !!   !!   !!   !!   !  ',
                    '                                                                                                                       ',
                    '',
                },
                week_header = {
                    enable = false,
                },
                shortcut = {
                    {
                        desc = '[ Neorg]',
                        group = '@module',
                        action = 'Neorg workspace main',
                        key = 'n',
                    },
                    {
                        desc = '[ Journal]',
                        group = '@function',
                        action = 'Neorg journal',
                        key = 'j',
                    },
                    {
                        desc = '[󰄬 Todo]',
                        group = '@neorg.todo_items.done',
                        action = 'e ~/todo.norg',
                        key = 't',
                    },
                    {
                        desc = '[ dotfiles]',
                        group = '@markup',
                        action = 'Telescope find_files cwd=~/Code/dotfiles',
                        key = 'd',
                    },
                },
            },
        }
    end,
}
