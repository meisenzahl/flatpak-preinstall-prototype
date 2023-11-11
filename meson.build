project(
    'flatpak-preinstall-prototype', 
    'vala', 'c',
)

executable(
    meson.project_name (),
    'src' / 'Application.vala',
    dependencies: [
        dependency ('gio-2.0'),
        dependency ('glib-2.0'),
    ],
    install : true
)
