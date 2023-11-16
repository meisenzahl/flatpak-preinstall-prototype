public class Application : GLib.Application {
    public const OptionEntry[] FLATPAK_OPTIONS = {
        { "user", 'u', 0, OptionArg.NONE, out user,
        "Work on the user installation", null},
        { "system", 's', 0, OptionArg.NONE, out system,
        "Work on the system-wide installation (default)", null},
        { "assumeyes", 'y', 0, OptionArg.NONE, out assumeyes,
        "Automatically answer yes for all questions", null},
        { null }
    };

    public static bool user;
    public static bool system;
    public static bool assumeyes;

    struct FlatpakInstall {
        public string origin;
        public string bundle_id;
    }

    construct {
        application_id = "com.github.meisenzahl.flatpak-preinstall-prototype";
        flags = HANDLES_OPEN;

        Intl.setlocale ();

        add_main_option_entries (FLATPAK_OPTIONS);
    }

    public override void activate () {
        if (user && system) {
            print ("ERROR: Cannot specify both --user and --system\n");
            return;
        }

        Flatpak.Installation installation;
        try {
            installation = new Flatpak.Installation.system ();
        } catch (Error e) {
            critical ("Unable to open system-wide Flatpak installation: %s", e.message);
            return;
        }

        string flatpak_preinstall_config_dir = "/etc/flatpak/preinstall.d";

        if (user) {
            try {
                installation = new Flatpak.Installation.user ();
            } catch (Error e) {
                critical ("Unable to open user Flatpak installation: %s", e.message);
                return;
            }
            flatpak_preinstall_config_dir = "%s/.config/flatpak/preinstall.d".printf (Environment.get_home_dir ());
        }

        try {
            update_remotes (installation);
        } catch (Error e) {
            critical ("Unable to update Flatpak remotes: %s", e.message);
            return;
        }

        GLib.GenericArray<weak Flatpak.Remote> remotes;
        try {
            remotes = installation.list_remotes ();
        } catch (Error e) {
            critical ("Unable to get a list of Flatpak remotes: %s", e.message);
            return;
        }

        GLib.GenericArray<weak Flatpak.InstalledRef> installed_refs;
        try {
            installed_refs = installation.list_installed_refs ();
        } catch (Error e) {
            critical ("Unable to get a list of installed Flatpak refs: %s", e.message);
            return;
        }

        var remote_ref_strings = new GLib.GenericArray<string> ();
        foreach (var remote in remotes) {
            if (remote.get_url ().has_prefix ("file://")) {
                continue;
            }

            try {
                foreach (var remote_ref in installation.list_remote_refs_sync_full (remote.get_name (), Flatpak.QueryFlags.ONLY_CACHED, null)) {
                    remote_ref_strings.add (remote_ref.format_ref ());
                }
            } catch (Error e) {
                warning ("Unable to list remote refs of %s: %s", remote.get_name (), e.message);
            }
        }

        if (FileUtils.test (flatpak_preinstall_config_dir, FileTest.IS_DIR)) {
            print ("Looking for matches…\n");
            Dir dir;
            try {
                dir = Dir.open(flatpak_preinstall_config_dir);

                var to_be_installed_list = new GLib.GenericArray<FlatpakInstall?> ();

                unowned string? file;
                while ((file = dir.read_name ()) != null) {
                    string path = Path.build_filename (flatpak_preinstall_config_dir, file);
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

                            if (preinstall) {
                                var installed = is_installed (installation, collection_id, id);
                                if (installed != null) {
                                    print ("Skipping: %s is already installed\n", installed);
                                    continue;
                                }

                                string? origin = null;
                                foreach (var remote in remotes) {
                                    if (remote.get_name () == collection_id) {
                                        origin = remote.get_name ();
                                        break;
                                    }
                                }

                                if (origin == null) {
                                    print ("Could not find remote for %s\n", id);
                                    continue;
                                }

                                foreach (var remote_ref in remote_ref_strings) {
                                    var keys = remote_ref.split ("/");

                                    if (keys.length != 4) {
                                        continue;
                                    }

                                    string application_id = keys[1];

                                    if (id != application_id) {
                                        continue;
                                    }

                                    to_be_installed_list.add (FlatpakInstall () {
                                        origin = origin,
                                        bundle_id = remote_ref,
                                    });
                                }
                            }
                        }
                    } catch (Error e) {
                        critical ("Unable to read Flatpak configuration %s", e.message);
                    }
                }

                if (to_be_installed_list.length == 0) {
                    print ("No applications to be installed\n");
                    return;
                }

                print ("\nThe following applications will be installed:\n\n");
                foreach (var to_be_installed in to_be_installed_list) {
                    print ("%s\n", to_be_installed.bundle_id);
                }
                print ("\n");

                bool should_install = assumeyes;
                if (!assumeyes) {
                    print ("Proceed with these changes to the %s installation? [Y/n]: ".printf (user ? "user" : "system"));
                    string answer = string.nfill (1, (char) stdin.getc ()).down ();
                    should_install = answer == "y" || answer == "\n";
                    print ("\n");
                }

                if (should_install) {
                    foreach (var to_be_installed in to_be_installed_list) {
                        print ("Installing %s\n", to_be_installed.bundle_id);
                        install (installation, to_be_installed.origin, to_be_installed.bundle_id);
                    }
                }
            } catch (Error e) {
                critical ("Unable to read flatpak configs: %s", e.message);
            }
        }
    }

    private string? is_installed (Flatpak.Installation installation, string origin, string bundle_id) throws Error {
        GLib.GenericArray<weak Flatpak.InstalledRef> installed_refs;
        installed_refs = installation.list_installed_refs ();

        foreach (var installed_ref in installed_refs) {
            if (installed_ref.origin == origin && installed_ref.format_ref ().contains (bundle_id)) {
                return installed_ref.format_ref ();
            }
        }

        return null;
    }

    private bool update_remotes (Flatpak.Installation installation) throws Error {
        GLib.GenericArray<weak Flatpak.Remote> remotes = null;

        installation.drop_caches ();
        remotes = installation.list_remotes ();

        bool success = false;
        for (int i = 0; i < remotes.length; i++) {
            var remote = remotes[i];
            try {
                success = installation.update_remote_sync (remote.get_name ());
            } catch (Error e) {
                warning ("Unable to update remote: %s", e.message);
            }
            debug ("Remote updated: %s", success.to_string ());
        }

        return true;
    }

    private bool install (Flatpak.Installation installation, string origin, string bundle_id) {
        Flatpak.Transaction transaction;
        try {
            transaction = new Flatpak.Transaction.for_installation (installation, null);
            transaction.add_default_dependency_sources ();
        } catch (Error e) {
            critical ("Error creating transaction for flatpak install: %s", e.message);
            return false;
        }

        try {
            transaction.add_install (origin, bundle_id, null);
        } catch (Error e) {
            critical ("Error setting up transaction for flatpak install: %s", e.message);
            return false;
        }

        transaction.choose_remote_for_ref.connect ((@ref, runtime_ref, remotes) => {
            if (remotes.length > 0) {
                return 0;
            } else {
                return -1;
            }
        });

        bool success = false;

        transaction.operation_error.connect ((operation, e, detail) => {
            warning ("Flatpak installation failed: %s (detail: %d)", e.message, detail);
            if (e is GLib.IOError.CANCELLED) {
                success = true;
            }

            // Only cancel the transaction if this is fatal
            var should_continue = detail == Flatpak.TransactionErrorDetails.NON_FATAL;

            return should_continue;
        });

        transaction.ready.connect (() => {
            return true;
        });

        try {
            success = transaction.run (null);
        } catch (Error e) {
            if (e is GLib.IOError.CANCELLED) {
                success = true;
            } else {
                success = false;
            }
        }

        return success;
    }
}

public static int main (string[] args) {
    var application = new Application ();
    return application.run (args);
}
