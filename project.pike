#!/usr/bin/env pike
// NOTE: This file is partly generated, do not edit it directly!
#charset utf8

mapping(string:string) colors = ([
  "g"   : "1;30m", // grey
  "lg"  : "0;37m", // light grey
  "br"  : "0;33m", // brown
  "y"   : "1;33m", // yellow
  "w"   : "1;37m", // white
  "p"   : "0;35m", // purple
  "r"   : "0;31m", // red
  "lr"  : "1;31m", // light red
  "bl"  : "0;34m", // blue
  "lb"  : "1;34m", // lb,
  "bld" : "1m",    // bold,
  "gr"  : "0;32m"  // green
]);

string opt_type;
string opt_author;
string opt_license;
string opt_module_name;
string opt_module_path;

mapping vars = ([
  "author"         : UNDEFINED,
  "license"        : UNDEFINED,
  "type"           : UNDEFINED,
  "module"         : UNDEFINED,
  "module_name"    : UNDEFINED,
  "module_path"    : UNDEFINED,
  "module_dir"     : UNDEFINED,
  "lc_module_name" : UNDEFINED,
  "local_dir_name" : UNDEFINED,
  "year"           : UNDEFINED,
]);

string init_text = #"
This utility program will help you set up a new Pike module.
If you wish to abort this process at any time press ^C.

Default values will be written in parentheses <lb>(default value)</lb>.

";

Stdio.Readline rl;

constant trap_signals = ({
  "SIGHUP",
  "SIGINT",
  "SIGQUIT",
  "SIGKILL",
  "SIGTERM",
});

int main(int argc, array(string) argv)
{
  foreach (trap_signals, string s) {
    signal(signum(s), on_signal);
  }

  if (mixed e = catch(run())) {
    if (Stdio.exist(tmpdir)) {
      Stdio.recursive_rm(tmpdir);
    }

    werror("<lr>Error:</lr> %s \n", describe_backtrace(e));

    return 1;
  }

  return 0;
}

int run()
{
  rl = Stdio.Readline();
  rl->OutputController()->clear();

  check_perms();

  write(init_text);

  mapping env = getenv();
  write("  <g>You can use your <lb>up/down</lb> keys to select module type.</g>\n");

  while (!opt_type) {
    rl->enable_history(sort(indices(PACKAGES)));

    opt_type = prompt("Module Type", "CMOD");

    if (!PACKAGES[upper_case(opt_type)]) {
      write("  <lr>Unknown module type \"%s\". Module Type must be"
            " either %s.</lr>\n",
            opt_type,
            String.implode_nicely(indices(PACKAGES), "or"));

      opt_type = 0;
    }
  }

  rl->enable_history(({}));

  opt_author = env["LOGNAME"] || env["USER"] || env["USERNAME"];
  opt_author = prompt("Module Author", opt_author);

  rl->enable_history(({}));

  write("  <g>A single word like <lb>MyModule</lb>"
        " for instance ...</g>\n");

  while (!opt_module_name) {
    opt_module_name = prompt("Module Name");

    if (!verify_module_name(opt_module_name)) {
      opt_module_name = 0;
      write("    <lr>Invalid module name.</lr>\n");
    }
  }

  rl->enable_history(({}));

  write("  <g>The namespace where this module will reside.\n"
        "  Like <lb>Protocols.HTTP</lb>, <lb>Parser</lb>,"
        " <lb>Tools.Standalone</lb> ...</g>\n");
  while (!opt_module_path) {
    opt_module_path = prompt("Parent Module", "::");
    if (!verify_parent_module_name(opt_module_path)) {
      opt_module_path = 0;
      write("   <lr>Invalid parent module name</lr>\n");
    }
  }

  if (opt_module_path == "::") {
    opt_module_path = 0;
  }

  write("  <g>You can use your <lb>up/down</lb> keys to select license.</g>\n");

  while (!opt_license) {
    rl->enable_history(sort(indices(LICENSES)));
    opt_license = prompt("License", "NONE");

    if (!LICENSES[upper_case(opt_license)] && opt_license != "NONE") {
      write("  <lr>Unknown license \"%s\".</lr>\n", opt_license);
      opt_license = 0;
    }
  }

  if (opt_license == "NONE") {
    opt_license = 0;
  }
  set_vars();

  write("\n\n  <bld>Are these settings correct?</bld>\n\n");
  write("  <g>Author:</g>      <br>%s</br>\n", vars->author);
  write("  <g>License:</g>     <br>%s</br>\n", vars->license || "None");
  write("  <g>Module Type:</g> <br>%s</br>\n", vars->type);
  write("  <g>Module Name:</g> <br>%s</br>\n", vars->module_name);
  write("  <g>Module:</g>      <br>%s</br>\n\n", vars->module);
  write("  The module will be created in <br>%s/</br><y>%s</y>\n\n",
        getcwd(), vars->local_dir_name);

  rl->enable_history(({ "Yes", "No" }));

  string doit = prompt("Create Project [Y/n]", "Yes");

  if (!(<"y","yes">)[lower_case(doit)]) {
    write("\n  <lr>Aborting...</lr>\n");
    return 0;
  }

  unpack();

  write("\n  <gr><bld>%s</bld> Module <y>%s</y> created successfully in "
        "<y>%s</y>.\n\n",
        string_to_utf8("✓"),
        vars->module,
        vars->local_dir_name);

  return 0;
}

Regexp.PCRE.Widestring re_module_name =
  Regexp.PCRE.Widestring("^[_a-zA-Z]([_a-zA-Z0-9]+)?$");

string tmpdir = combine_path(__DIR__, ".pike-project-tmp");

string my_combine_path(mixed ... args) {
  args = map(args, lambda (string s) {
    if (has_prefix(s, "/")) {
      s = s[1..];
    }

    return s;
  });

  return combine_path(tmpdir, @args);
};

string tmp_path(string file)
{
  return combine_path(tmpdir, file);
}

void unpack()
{
  mkdir(tmpdir);
  string package = MIME.decode_base64(PACKAGES[vars->type]);
  package = Gz.uncompress(package);
  Stdio.write_file(tmp_path("stub.tar"), package);

  object tar = Filesystem.Tar(tmp_path("stub.tar"));
  string root = lower_case(vars->type);
  tar = tar->cd(root);

  string strip_root(string s) {
    string prefix = "/" + root + "/";

    if (has_prefix(s, prefix)) {
      s = s[sizeof(prefix)..];
    }

    return s;
  };

  void handle_files(object tar) {
    array(string) files = tar->get_dir();

    foreach (files, string file) {
      object stat = tar->stat(file);

      if (stat->isdir) {
        mkdir(my_combine_path(strip_root(file)));
        handle_files(tar->cd(file));
      }
      else {
        Stdio.File fp = tar->open(file, "r");
        string fdata = fp->read();
        fp->close();
        Stdio.write_file(my_combine_path(strip_root(file)), fdata);
      }
    }
  };

  handle_files(tar);

  destruct(tar);
  tar = 0;

  rm(tmp_path("stub.tar"));

  fix_files();

  if (!mv(tmpdir, vars->local_dir_name)) {
    werror("  <lr>Failed creating module directory <y>%s</y>.\n"
           "  Make sure you have write permissons and that the directory "
           "doesn't exist already.</lr>\n", vars->local_dir_name);

    exit(1);
  }
}

string replace_vars(string c)
{
  foreach (vars; string key; string v) {
    if (v) {
      c = replace(c, "${" + key + "}", v);
    }
  }

  return c;
}

void fix_files()
{
  Stdio.write_file(tmp_path("CHANGES"), "");
  Stdio.write_file(tmp_path("INSTALL"), MIME.decode_base64(INSTALL));

  if (vars->license) {
    string lic = Gz.uncompress(MIME.decode_base64(LICENSES[vars->license]));
    [string head, string body] = lic/"[BODY]";

    Stdio.write_file(tmp_path("LICENSE"), body);
    vars->license = replace_vars(head);
  }
  else {
    vars->license = "";
  }

  void loop_dir(string dir) {
    foreach (get_dir(dir), string file) {
      string fp = combine_path(dir, file);

      if (Stdio.is_dir(fp)) {
        loop_dir(fp);
      }
      else {
        if (file == "Module.cmod") {
          string new = vars->module_name + ".cmod";
          string nfp = combine_path(dir, new);
          mv(fp, nfp);
          file = new;
          fp = nfp;
        }

        string c = Stdio.read_file(fp);
        Stdio.write_file(fp, replace_vars(c));
      }
    }
  };

  loop_dir(tmpdir);
}

void check_perms()
{
  if (!Stdio.write_file(".pike-project-tmp", "\n")) {
    werror("<lr>No write permission to</lr> <y>%s</y>\n", getcwd());
    exit(1);
  }

  rm(".pike-project-tmp");
}

void set_vars()
{
  vars->type = opt_type;
  vars->author = opt_author;
  vars->module_name = opt_module_name;
  vars->lc_module_name = lower_case(opt_module_name);
  vars->module_path = opt_module_path;
  vars->year = (string)(localtime(time())->year + 1900);

  if (opt_module_path) {
    vars->module = opt_module_path + "." + opt_module_name;
  }
  else {
    vars->module = opt_module_name;
  }

  vars->local_dir_name = lower_case(replace(vars->module, ".", "_"));

  string md = "";
  foreach (vars->module/".", string pt) {
    md += pt + ".pmod/";
  }

  vars->module_dir = md;

  if (opt_license) {
    vars->license = opt_license;
  }
}

bool verify_module_name(string n)
{
  return n && re_module_name->match(n);
}

bool verify_parent_module_name(string n)
{
  if (!n) {
    return false;
  }

  if (n == "::") {
    return true;
  }

  foreach (n/".", string p) {
    if (!verify_module_name(p)) {
      return false;
    }
  }

  return true;
}


string prompt(string message, void|string default_value)
{
  string tmp = message + ": ";
  if (default_value) {
    tmp = sprintf("%s(%s) ", tmp, default_value);
  }

  tmp = rl->read("  " + tmp);

  if (!sizeof(String.trim_all_whites(tmp))) {
    if (default_value) {
      tmp = default_value;
    }
    else {
      tmp = UNDEFINED;
    }
  }

  if (tmp) {
    tmp = string_to_utf8(tmp);
  }

  return tmp;
}

void on_signal(int s)
{
  Stdio.recursive_rm(tmpdir);
  werror("\n<lr>Exiting...</lr>\n\n");
  exit(s);
}

void write(mixed ... args)
{
  predef::write(colorify(@args));
}

void werror(mixed ... args)
{
  predef::werror(colorify(@args));
}

object text_parser = class {
  Parser.HTML parser;
  ADT.Stack stack;

  string reset = "\033[0m";

  void create() {
    stack = ADT.Stack();
    parser = Parser.HTML();
    parser->_set_tag_callback(any_tag);
  }

  mixed any_tag(Parser.HTML pp, string data) {
    string tag = pp->tag_name();
    bool is_closing = tag[0] == '/';

    if (is_closing) {
      if (sizeof(stack)) {
        stack->pop();

        if (sizeof(stack)) {
          return stack->top();
        }
      }

      return reset;
    }

    if (string c = colors[tag]) {
      c = "\033[" + c;
      stack->push(c);
      return c;
    }

    return reset;
  }

  string parse(string s) {
    return parser->feed(s)->finish()->read();
  }
}();


string colorify(mixed ... args)
{
  return text_parser->parse(sprintf(@args));
}

/*
  Generated stuff
*/

constant INSTALL = "VHlwaWNhbGx5IHlvdSBpbnN0YWxsIGEgUGlrZSBtb2R1bGUgbGlrZSB0aGlzOgoKCXBpa2UgLXggbW9kdWxlICAgICAgICAgICAgIyBDb21waWxlcyB0aGUgbW9kdWxlCglwaWtlIC14IG1vZHVsZSBpbnN0YWxsICAgICMgSW5zdGFsbHMgdGhlIG1vZHVsZQoJCkZvciBmdXJ0aGVyIG9wdGlvbnMgcnVuCgoJcGlrZSAteCBtb2R1bGUgLS1oZWxwCg==";

constant LICENSES = ([
  "GPL2": LICENSE_GPL2,
  "GPL3": LICENSE_GPL3,
  "LGPL2.1": LICENSE_LGPL21,
  "LGPL3": LICENSE_LGPL3,
  "MPL2.0": LICENSE_MPL20
]);

constant LICENSE_GPL2 = "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";
constant LICENSE_GPL3 = "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";
constant LICENSE_LGPL21 = "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";
constant LICENSE_LGPL3 = "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";
constant LICENSE_MPL20 = "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";

constant PACKAGES = ([
  "CMOD": PACKAGE_CMOD,
  "PMOD": PACKAGE_PMOD
]);

constant PACKAGE_CMOD = "eNrtWf9P4koQ91f3r5jjNCkGocgXk2dMWoVD3qEYvtx7iZqmtAv0KNtm22oM4X9/s21BKOo7kycvnp0Qdnd2djrtdD8zszWmjlnYeV+SZfm4UoGwrUatfFSO2pigWJarJbkql8pHIBePysfFHajsbIECz9c5muI6zA+8l+VQbDh8/SbFfSzbD0KG8P+lYwY2zYv+O/m/Wi6/6P9isVJO+L9cqZZ2QE79/+60N7MtgzKPzgn5ajHDDkwKmZHtDHQ7P84gM2AmHcK1ev5dbdS1s36jU79ud3rJiSv1sp7kdXud5lUjye2pneeE+51WkvWj3uk221erlhkOG1ojYdkTz2I+5S6n/jp7Gr3VazyXOyOuT9eZns9123aMBPdet4PEcmfwkxrJy+iua7GESa41oZr/6FJvnT8ILNu3mDYMmOFbDgunCanVz1tqR+3hzXYJuW5+F+NuF6KNSWZkt3nV7JHdGSG76Kjd+t9Po3m0QLts1/qtuhYK4gLdNDW8MbRMw2eGby/zpYym6YE/dngmt+nQHMjZkxfX3VPuob0rC2PnRMtiAxO2hGbOYnPn5KPsic9EIf771PPfMQl4e/wvlStyGv+35v8FqOYt9k7+fzX+y+jzZPwvFtP4vw0qHEAUJ7WVlyAP0KCMct2nJgy5M4VoMuAUZ2HwCBhGnDHVTcpR9qBACOqp0aHFKPgO+GMKGEc49Tx4GFNOYRCMgFPX4b4HQ4ejhOWBqxsTfUTBGzuBbcIAe5T5eaHvxaxj80LDwLaB6VMKznBN73OKwsTjNR06MyGOdb+iL85wNjU62PUepwPHFrfH/V+2cJEdbaocO6jBFQ8s+QSf0yPSqU0db7i1RfL1CYLgJ6YV/I929/bxXy5XSwn8r8hyJcX/bZB6HlYM0s3eLIoD87sc3Mj5omj2ZlG5ML/LEhRcqTCkkHHevvrWbGgXdbWGYCEtIkiWfMVJtdPQ/mr2LiQsMQ0tDjICBec5EHQDcHj4YKH+wD/ckIGIuoErgkaIeCsW3uBPLNU21p0+Ug+tJedorNZqnnVPM5locP6tpTbCoTC92z/r9qSViWyCK9aGvHa/d93vSZf6BJHUptnfCxDD/R9Xyi62iAD/eSXw9vy/UjpKz/+25//Fu/3/5P+I/5v5f1lO8X8bpEzR99q9zi19YFNPIT+u1d7FqeJxw7S4Qtpnf3ZPF8gbQWzeIQiQtWbniY+ic8EUmWtCmqj9XrvWRmztiFCT1GWQOKpcC9DF+XUsWsy2ahF6K3FHAUUANDZLsFYWsjHQKyvgrpD1UIWTa2OFKOYjGmQtg8k03hJihroUM2NmWOL5/Gb58HP4vzLcyv7HvZ/Y/8cICen+3watnf+LU2vQtE5dbS3KP03DKrLwBRRrxBxOicWwnrf8ZTKmubo/nivRQDmJZHG7xOJp9fgR9n94/jvV3yf6/3v+Vy5Wk/G/dJR+/9sKff1SCDxeGCDsU3YPAgEIsaZh0bUsuE6QxXwQb4gkOjofGTn85/qjFH0rygrefZbMCMAD4gOVMresJ06Y8Heb2W/DvnebESeHOMDeLbtlmRyJq7ynK+WjNgfLL06iG1Wh4jMTiEqQ6sYYJA9NRGtMhC9PWirIZnMQmQSTbKg/MgcyAAdoxB+w3xaXhknu6ao3kztA7ekXqpRSSukz0T8h2IrB";
constant PACKAGE_PMOD = "eNrtWG1v2kAM7uf8Co+2ElQIQkmotAkpKVDGRgkKYV9KFQVygQi4oLukU1Xx3+dLgJaObqs22KbGQtyLHccXnx/7bjEP3OLRfkmW5QtVhbitJK18riTtiqCkyJWyXJHLyjnIpXNVrhyBenQAinjoMDRlEdAw4i/LoZjn/XiRYh2b9j+hhfB/SHi4x03wev+XlYqa+v9g/h8F1PPHhUnBp3vyf0VRXvR/SUafb/tfUc8x/uXU/3un4hngDohmxH6yCQoATUIJc0LigseCOSTMiBHkwvAenCgMJsRxCUPZs6IkoZ468XxKIAwgnBBwXJcRzuHrhDACw2gMjCwCFnLwAoYSPoeFM5o6YwJ8EkQzF4bYIzQsCH3HEXWJB1299llvNuzLftNsdA3T2vEiL5rNgDpzAoG3pXeXoo5+3fihDoe6cEcY9wP6K/p6ltnqNHdoDLDL7+fDYCaWx8JfttDSzReMnASoYSE+2PMvuEtP32zv0PGKpX1pmL2W0ZH+l52c0m/ifxLdh8d/uaQ+x38Vfyn+H4L0mt3qtKzszclDkgeWt3m4kQsl0Zw8IM4jei1vcxIKXhv1fruRyMcTNaNz1WraHxt6HcEiu84gMc/oW92+lb12pghAM5JLceTfjf/E8wXRRwT44yeB19f/armcnv8O5/91kP6d+h/L/+/rf7WU4v8hSJuj7+07h/nOcEa4Jn3p6tbHqsbZyPWZJhmXn3pVCZG/3jKr6xxhI2spJkWl+jgrStylpPcto27U7J4pUkv8rMgaXWzFeBtr1tx2/aqtN3tVbdXRQGu3LkVTE8/F/bVsbSUac5KBJm2nImRujTVJc+/RPH9kr2ydr7a84JAFwcqXjnyx/jeWp3bh/5PhQeK/dKE8i/+L+P4vjf/908nDzB8RyjFwpeOFPyVg22ZDb6+Pf7aNp8jiO9D8MQ0YkbDGwy9BQxRLakOoQmZTJ2Y+PBVYHzZRAgtK5MWKMNZWut5WpP3D8R/f/86d/WT/n9d/SqnyPP+XFTmN/0PQ8btixFlxiLBP6B0IBJAkfy5u6mBzJPyAUxjRYodkRcdh41Ee/5lzn+Uh8+k4J+buctKDBPCV+SHJZgbUEjdM+BtkTg045YOMuDnEAfYGdEAzeRROaPOmQtLmH9Ejv0GaHJoB4u6LOKMJZDmaiNa4CF88u1GQy+UhMQmmuVh/Yg5kAM7QiPdwaohXwzT/+Nab6S2g9mWKSCmllNIbom9pZnEa";
