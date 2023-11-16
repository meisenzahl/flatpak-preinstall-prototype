systemd_user_unit_dir = get_option('systemduserunitdir')
if systemd_user_unit_dir != 'no'
    if systemd_user_unit_dir == ''
        systemd_dep = dependency('systemd', version: '>= 206', required: false)
        assert(systemd_dep.found(), 'systemd required but not found, please provide a valid systemd system unit dir or disable it')
        systemd_user_unit_dir = systemd_dep.get_variable('systemduserunitdir', pkgconfig_define: ['prefix', prefix])
    endif
endif

systemd_system_unit_dir = get_option('systemdsystemunitdir')
if systemd_system_unit_dir != 'no'
    if systemd_system_unit_dir == ''
        systemd_dep = dependency('systemd', version: '>= 206', required: false)
        assert(systemd_dep.found(), 'systemd required but not found, please provide a valid systemd system unit dir or disable it')
        systemd_system_unit_dir = systemd_dep.get_variable('systemdsystemunitdir', pkgconfig_define: ['prefix', prefix])
    endif
endif

install_data(
    'user.service',
    install_dir: systemd_user_unit_dir,
    rename: meson.project_name() + '.service'
)

install_data(
    'system.service',
    install_dir: systemd_system_unit_dir,
    rename: meson.project_name() + '.service'
)
