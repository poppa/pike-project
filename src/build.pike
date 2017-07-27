
constant target = combine_path(__DIR__, "..", "project.pike");

constant packages = ([
  "CMOD" : "cmod",
  "PMOD" : "pmod",
]);

constant licences = ([
  "GPL2"    : "gpl2.lic",
  "LGPL2.1" : "lgpl21.lic",
  "GPL3"    : "gpl3.lic",
  "LGPL3"   : "lgpl3.lic",
  "MPL2.0"  : "mpl20.lic",
]);

string prog;

int main(int argc, array(string) argv)
{
  if (getcwd() != __DIR__) {
    werror("This program must be run from the same location as it resides.\n");
    return 1;
  }

  prog = "// NOTE: This file is partly generated, do not edit it directly!\n\n";
  prog += Stdio.read_file("program.pike");

  clean_prog();

  string t = make_install()  + "\n\n" +
             make_licenses() + "\n\n" +
             make_packages();
  prog = replace(prog, "//#GENERATED_CONSTANTS", t);
  Stdio.write_file(target, prog);

  string consts = "// NOTE: This file is generated from build.pike\n"
                  "// Do not edit it directly\n\n" + t;

  Stdio.write_file("generated_constants.h", consts);

  return 0;
}

void clean_prog()
{
  prog = replace(prog, "#define PROJ_DEBUG\n", "");
  sscanf(prog, "%s#ifdef PROJ_DEBUG%*s#endif%s", string pre, string post);
  prog = String.trim_all_whites(pre) + "\n\n" +
         String.trim_all_whites(post);
  sscanf(prog, "%s#ifdef DEV%*s#endif", prog);
  prog = String.trim_all_whites(prog) + "\n";
}

string make_install()
{
  string t = MIME.encode_base64(Stdio.read_file("text/install.txt"), true);
  return "constant INSTALL = \"" + t + "\";";
}

string make_licenses()
{
  array(string) chunks = ({});
  array(string) licmap = ({});

  foreach (licences; string key; string f) {
    string file = combine_path(__DIR__, "licenses", f);

    if (Stdio.exist(file)) {
      string keynodot = replace(key, ".", "");
      string tmp = MIME.encode_base64(Gz.compress(Stdio.read_file(file)), true);
      chunks += ({ "constant LICENSE_" + keynodot + " = \"" + tmp + "\";" });
      licmap += ({ "  \"" + key + "\": LICENSE_" + keynodot });
    }
  }

  return "constant LICENSES = ([\n" +
     (licmap*",\n") + "\n]);\n\n" +
     chunks * "\n";
}

string make_packages()
{
  array(string) chunks = ({});
  array(string) modmap = ({});

  foreach (packages; string key; string m) {
    string tarname = m + ".tar.gz";
    mixed r = Process.run(({ "tar", "pczf", tarname, m }));

    if (r->exitcode == 0) {
      string fdata = MIME.encode_base64(Stdio.read_file(tarname), true);

      chunks += ({ "constant PACKAGE_" + key + " = \"" + fdata + "\";" });
      modmap += ({ "  \"" + key + "\": " + "PACKAGE_" + key });

      rm(tarname);
    }
    else {
      error("Error creating tar.gz for %O\n", m);
    }
  }

  return "constant PACKAGES = ([\n" +
    (modmap * ",\n") + "\n]);\n\n" +
    (chunks * "\n");
}
