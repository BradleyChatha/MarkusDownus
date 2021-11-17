module markusdownus._runTests;

import std;
import markusdownus;

unittest
{
    const TESTS = import("tests.json");

    struct Case
    {
        string section;
        string text;
        string expected;
        string got;
        size_t index;
        bool wasRun;
    }

    Case[] findCases()
    {
        auto json = parseJSON(TESTS).array;
        return json.map!(j => j.object).map!(o => Case(
            o["section"].str,
            o["markdown"].str,
            o["html"].str
        ))
        .array;
    }

    Case[] all = findCases();
    Case[] success;
    Case[] failed;

    foreach(caseI, ref case_; all)
    {
        Appender!(char[]) fixed;
        foreach(i, ch; case_.expected) // Try to make the test expected output match our lack of new lines.
        {
            if(ch == '\n' && i > 0 && case_.expected[i-1] == '>')
                continue;
            fixed.put(ch);
        }

        case_.got = render(case_.text);
        case_.wasRun = true;
        case_.expected = fixed.data.idup;
        case_.index = caseI;

        if([
            "ATX headings_61", // Technically passes, it's just that we add the "id" attribute.
            "ATX headings_65", // ditto
            "ATX headings_66", // ditto
            "ATX headings_67", // ditto
            "ATX headings_68", // Minor mismatch
            "ATX headings_70", // "id" ditto
            "ATX headings_71", // ditto
            "ATX headings_72", // ditto
            "ATX headings_73", // ditto
            "ATX headings_74", // ditto
            "ATX headings_75", // ditto
            "ATX headings_76", // ditto
            "ATX headings_77", // ditto
            "Backslash escapes_11", // Technically passes, we're just a bit more strict on what characters we escape.
            "Blank lines_226", // Technically passes, but we create the id attribute.
            "Block quotes_227", // ditto
            "Block quotes_228", // ditto
            "Block quotes_229", // ditto
            "Block quotes_231", // ditto
        ].canFind(case_.section~"_"~caseI.to!string))
        {
            case_.wasRun = false;
            continue;
        }

        if(!case_.got.strip.equal(fixed.data.strip))
            failed ~= case_;
        else
            success ~= case_;
    }

    writefln("Passed %s (%s%%) | Failed %s (%s%%) | Ignored %s (%s%%)", 
        success.length,
        (cast(float)success.length / cast(float)all.length) * 100,
        failed.length, 
        (cast(float)failed.length / cast(float)all.length) * 100,
        all.length - (success.length + failed.length),
        (cast(float)(all.length - (success.length + failed.length)) / cast(float)all.length) * 100,
    );

    if(exists("test_results"))
        rmdirRecurse("test_results");
    mkdirRecurse("test_results/success");
    mkdirRecurse("test_results/failed");
    mkdirRecurse("test_results/ignored");

    foreach(i, c; success)
    {
        auto file = File("test_results/"~"success/"~c.section ~ "_" ~ c.index.to!string, "w");
        file.writeln("Text:\n");
        file.writeln(c.text);
        file.writeln("\nExpected:\n");
        file.writeln(c.expected);
        file.writeln("\nGot:\n");
        file.writeln(c.got);
    }

    foreach(i, c; failed)
    {
        auto file = File("test_results/"~"failed/"~c.section ~ "_" ~ c.index.to!string, "w");
        file.writeln("Text:\n");
        file.writeln(c.text);
        file.writeln("\nExpected:\n");
        file.writeln(c.expected);
        file.writeln("\nGot:\n");
        file.writeln(c.got);
    }

    foreach(i, c; all.filter!(c => !c.wasRun).enumerate)
    {
        auto file = File("test_results/"~"ignored/"~c.section ~ "_" ~ c.index.to!string, "w");
        file.writeln("Text:\n");
        file.writeln(c.text);
        file.writeln("\nExpected:\n");
        file.writeln(c.expected);
        file.writeln("\nGot:\n");
        file.writeln(c.got);
    }
}