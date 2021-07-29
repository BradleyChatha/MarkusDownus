module app;
import std;
import jcli, markusdownus;

@CommandDefault("Converts the given markdown file into HTML.")
struct MainCommand
{
    @CommandPositionalArg(0, "file", "The markdown file to convert.")
    @PostValidate!(f => Result!void.failureIf(!exists(f), "File does not exist: "~f))
    string file;

    @CommandNamedArg("o|output", "Where to place the output.")
    Nullable!string output;

    void onExecute()
    {
        auto output = this.output.get(file.setExtension(".html"));
        if(!exists(output.dirName))
            mkdirRecurse(output.dirName);
        auto content = render(readText(this.file));
        std.file.write(output, content);
    }
}

int main(string[] args)
{
    return new CommandLineInterface!app().parseAndExecute(args);
}
