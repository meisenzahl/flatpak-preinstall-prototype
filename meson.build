project(
    'flatpak-preinstall-prototype', 
    'vala', 'c',
)

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

executable(
    meson.project_name (),
    'src' / 'Application.vala',
    dependencies: [
        dependency ('flatpak'),
        dependency ('gio-2.0'),
        dependency ('glib-2.0'),
    ],
    install : true
)
