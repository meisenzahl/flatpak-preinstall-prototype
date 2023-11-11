public class Application : GLib.Application {
    construct {
        application_id = "com.github.meisenzahl.flatpak-preinstall-prototype";
    }

    public override void activate () {
        const string FLATPAK_PREINSTALL_CONFIG_DIR = "/etc/flatpak/preinstall.d";
        if (FileUtils.test (FLATPAK_PREINSTALL_CONFIG_DIR, FileTest.IS_DIR)) {
            Dir dir;
            try {
                dir = Dir.open(FLATPAK_PREINSTALL_CONFIG_DIR);

                unowned string? file;
                while ((file = dir.read_name ()) != null) {
                    string path = Path.build_filename (FLATPAK_PREINSTALL_CONFIG_DIR, file);
                    if (!FileUtils.test (path, FileTest.IS_REGULAR)) {
                        continue;
                    }

                    if (!path.has_suffix (".preinstall")) {
                        continue;
                    }

                    var key_file = new KeyFile ();
                    try {
                        key_file.load_from_file (path, KeyFileFlags.NONE);

                        foreach (var group in key_file.get_groups ()) {
                            var id = group;
                            var collection_id = key_file.get_string (group, "CollectionID");
                            var preinstall = key_file.get_boolean (group, "Preinstall");
                        }
                    } catch (Error e) {
                        critical ("Unable to read Flatpak system configuration %s", e.message);
                    }
                }
            } catch (Error e) {
                critical ("Unable to read flatpak configs: %s", e.message);
            }
        }
    }
}

public static int main (string[] args) {
    var application = new Application ();
    return application.run (args);
}
