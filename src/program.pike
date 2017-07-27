#charset utf-8

#define PROJ_DEBUG

#ifdef PROJ_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...)0
#endif

mapping(string:string) colors = ([
  "g"  : "1;30m", // grey
  "lg" : "0;37m", // light grey
  "br" : "0;33m", // brown
  "y"  : "1;33m", // yellow
  "w"  : "1;37m", // white
  "p"  : "0;35m", // purple
  "r"  : "0;31m", // red
  "lr" : "1;31m", // light red
  "bl" : "0;34m", // blue
  "lb" : "1;34m", // lb
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

Default values will be written in parens <lb>(default value)</lb>.

";

Stdio.Readline rl;

int main(int argc, array(string) argv)
{
  check_perms();

  write(init_text);

  rl = Stdio.Readline();

  mapping env = getenv();

  write("  <g>You can use your <lb>up/down</lb> keys to select module type.</g>\n");

  while (!opt_type) {
    rl->enable_history(sort(indices(PACKAGES)));

    opt_type = prompt("Module Type", "PMOD");

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

    if (!LICENSES[upper_case(opt_license)]) {
      write("  <lr>Unknown license \"%s\".</lr>\n", opt_license);
      opt_license = 0;
    }
  }

  if (opt_license == "NONE") {
    opt_license = 0;
  }

  set_vars();

  rl->OutputController()->clear();

  write("\n\n  <lg>Are these settings correct?</lg>\n\n");
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

  return 0;
}


Regexp.PCRE.Widestring re_module_name =
  Regexp.PCRE.Widestring("^[_a-zA-Z]([_a-zA-Z0-9]+)?$");

void unpack()
{
  mkdir(".pike-project-tmp");

  Stdio.recursive_rm(".pike-project-tmp");
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

  // TRACE("\nvars: %O\n", vars);
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
