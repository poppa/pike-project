
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

  prog = "#!/usr/bin/env pike\n"
         "// NOTE: This file is partly generated, do not edit it directly!\n\n";
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
  array(string) s = Parser.Pike.split(prog);
  array(Parser.Pike.Token) tokens = Parser.Pike.tokenize(s);
  array(Parser.Pike.Token) new_tokens = ({});

  for (int i; i < sizeof(tokens); i++) {
    Parser.Pike.Token t = tokens[i];
    string text = String.trim_all_whites(t->text);

    if (sizeof(text)  && has_prefix(text, "/*#")) {
      continue;
    }

    if (sizeof(text) && text[0] == '#' && (text[1] != '"' && text[1] != '!')) {
      string macro = (text/" ")[0];

      if ((< "#if", "#ifdef", "#ifndef">)[macro]) {
        // Keep the content of #ifndef AUTO_FILL
        if (sscanf(text, "#ifndef%*[ ]AUTO_FILL") == 1) {
          i += 1;
          for (; i < sizeof(tokens); i++) {
            text = String.trim_all_whites(tokens[i]->text);

            if (has_prefix(text, "#else")) {
              break;
            }
            else {
              new_tokens += ({ tokens[i] });
            }
          }
        }

        i += 1;
        for (; i < sizeof(tokens); i++) {
          text = String.trim_all_whites(tokens[i]->text);

          if (has_prefix(text, "#endif")) {
            break;
          }
        }

        continue;
      }

      if (macro != "#charset") {
        continue;
      }
    }

    new_tokens += ({ t });
  }

  array(Parser.Pike.Token) tt = ({});
  new_tokens += ({0});

  for (int i; i < sizeof(new_tokens); i++) {
    Parser.Pike.Token t = new_tokens[i];
    Parser.Pike.Token n = new_tokens[i+1];

    if (!n) {
      break;
    }

    string t1 = String.trim_all_whites(t->text);
    string t2 = String.trim_all_whites(n->text);

    // Consecutive only whie-space
    if (has_value(t->text, "\n") && has_value(n->text, "\n") &&
        !sizeof(t1) && !sizeof(t2))
    {
      continue;
    }

    tt += ({ t });
  }

  prog = Parser.Pike.simple_reconstitute(tt);
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

  foreach (sort(indices(licences)), string key) {
    string f = licences[key];
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

  foreach (sort(indices(packages)), string key) {
    string m = packages[key];
    string tarname = m + ".tar";
    mixed r = Process.run(({ "tar", "pcf", tarname, m }));

    if (r->exitcode == 0) {
      string fdata = MIME.encode_base64(Gz.compress(Stdio.read_file(tarname)), true);

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
