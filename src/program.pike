#charset utf8

/*#
  To run this program directly when developing pass the flags DEV and
  optionally AUTO_FILL to skip the wizard. If never done before you have to
  first run build.pike which will generate generated_constants.pike which
  this file needs when running standalone.

    pike -DDEV -DAUTO_FILL program.pike

  If any changes is made to any of the stub, license or text files build.pike
  need to be run for the changes to take effect.

  NOTE! No macros will be kept in this program when building the finished
        program with build.pike.
*/

#define PROJ_DEBUG

#ifdef PROJ_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...)0
#endif

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

Default values will be written in parentheses's <lb>(default value)</lb>.

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

  /*# The contents of this will be kept when built */
#ifndef AUTO_FILL
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

#else // AUTO_FILL
  opt_type = "CMOD";
  opt_author = "John Doe";
  opt_module_name = "Yaml";
  opt_module_path = "Parser";
  opt_license = "MPL2.0";
#endif // AUTO_FILL

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

string tmpdir = ".pike-project-tmp";

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

  void handle_files(object tar, string dir) {
    array(string) files = tar->get_dir();

    foreach (files, string file) {
      object stat = tar->stat(file);

      if (stat->isdir) {
        mkdir(combine_path(tmpdir, dir, file));
        handle_files(tar->cd(file), dir + "/" + file);
      }
      else {
        Stdio.File fp = tar->open(file, "r");
        string fdata = fp->read();
        fp->close();
        Stdio.write_file(combine_path(tmpdir, dir, file), fdata);
      }
    }
  };

  handle_files(tar, ".");

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
#ifdef DEV
  if (Stdio.exist(tmpdir)) {
    Stdio.recursive_rm(tmpdir);
  }
#endif

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

//#GENERATED_CONSTANTS

#ifdef DEV
  #include "generated_constants.h"
#endif
