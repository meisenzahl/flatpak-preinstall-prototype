project(
    'flatpak-preinstall-prototype', 
    'vala', 'c',
)

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

prefix = get_option('prefix')

subdir('data')
subdir('src')
