// Parse blocks down into inlines.
module markusdownus.syntax2;

import std.conv : to;
import std.format : format;
import std.stdio : writeln;
import std.exception : enforce;
import std.meta : AliasSeq;
import markusdownus.core, markusdownus.charreader, markusdownus.syntax1;
import markusdownus.syntax1 : GatherUniqueTriggers;

import taggedalgebraic : visit;

// version = MD_Debug_Verbose;

package struct Syntax2Context(MarkdownT)
{
    CharReader chars;
    MarkdownT.LeafBlockUnion* block;
    size_t plainTextStart;
    size_t plainTextEnd;

    this(ref MarkdownT.LeafBlockUnion block)
    {
        this.block = &block;

        block.value.visit!(
            (value) 
            {
                static if(__traits(compiles, value.range))
                    this.chars = CharReader(value.range.text);
            }
        );
    }

    void push(T)(T inline)
    {
        this.block.inlines ~= MarkdownT.InlineUnion(inline);
    }

    void pushPlainText(size_t newTextStart)
    {
        version(MD_Debug_Verbose) writeln("Pushing plain text from [",this.plainTextStart,"..",this.plainTextEnd,"]");
        this.push(PlainTextInline(
            MarkdownTextRange(this.plainTextStart, this.plainTextEnd, this.chars.slice(this.plainTextStart, this.plainTextEnd))
        ));
        this.plainTextStart = newTextStart;
    }

    bool hasChars()
    {
        return this.chars != CharReader.init;
    }
}

package void syntax2(MarkdownT)(Syntax2Context!MarkdownT context)
{
    import std.algorithm : splitter, count;
    import std.traits    : getUDAs;
    import std.meta      : anySatisfy, Filter;

    if(!context.hasChars)
        return;

    const uniqueTriggers = GatherUniqueTriggers!(MarkdownSyntax2Parser, MarkdownT.Syntax2Parsers);
    context.plainTextEnd = context.chars.length; // Just in case it doesn't get set, this'll treat the entire line as plain text.
    While: while(!context.chars.eof)
    {
        const white = context.chars.eatPrefixWhite();
        if(context.chars.eof)
            break;

        size_t afterTrigger;
        bool wasHandled;
        bool wasEscaped;
        
        const trigger = context.chars.peekUtfEscaped(afterTrigger, wasEscaped);
        
        auto wasWhiteBefore = white.spaces || white.tabs || context.chars.cursor == 0;
        if(!wasWhiteBefore && !context.chars.eof)
        {
            context.chars.retreat(1);
            wasWhiteBefore = context.chars.peek() == '\n';
            context.chars.advance(1);
        }

        Switch: switch(trigger)
        {
            static foreach(uniqueTrigger; uniqueTriggers)
            {
                static if(uniqueTrigger != '\0')
                {
                    case uniqueTrigger:
                        context.plainTextEnd = context.chars.cursor;
                        if(context.plainTextStart != context.plainTextEnd)
                            context.pushPlainText(context.plainTextEnd);
                        static foreach(i, parser; MarkdownT.Syntax2Parsers)
                        {{
                            enum wantsTrigger(alias uda) = uda.triggerChar == uniqueTrigger;
                            enum udas                    = getUDAs!(parser, MarkdownSyntax2Parser);
                            enum canUse                  = anySatisfy!(wantsTrigger, udas);

                            static if(canUse)
                            {
                                bool run = true;
                                static if(udas[0].wantsWhiteBefore)
                                    run = wasWhiteBefore;

                                if(run)
                                {
                                    const result = parser.init.parse(context);
                                    if(result != MarkdownSyntax2Result.didNothing)
                                    {
                                        context.plainTextStart = context.chars.cursor;
                                        context.plainTextEnd = context.chars.length;
                                        wasHandled = true;
                                        break Switch;
                                    }
                                }
                            }
                        }}
                        break Switch;
                }
            }
            default: break;
        }

        if(wasHandled)
            continue;

        context.chars.advance(1);
    }

    if(context.plainTextStart != context.plainTextEnd)
        context.pushPlainText(0);
}

@MarkdownInline("code")
struct CodeInline
{
    MarkdownTextRange range;
}

@MarkdownInline("weakEmphesis")
struct WeakEmphesisInline
{
    MarkdownTextRange range;
}

@MarkdownInline("strongEmphesis")
struct StrongEmphesisInline
{
    MarkdownTextRange range;
}

@MarkdownInline("link")
struct LinkInline
{
    MarkdownTextRange text;
    MarkdownTextRange url;
}

@MarkdownSyntax2Parser('`', true)
struct CodeParser
{
    alias Inlines = AliasSeq!(CodeInline);

    MarkdownSyntax2Result parse(ContextT)(ref ContextT context)
    {
        const count = context.chars.peekSameChar('`');
        context.chars.advance(count);
        const start = context.chars.cursor;
        
        while(true)
        {
            if(context.chars.eof)
            {
                context.push(JunkInline(
                    MarkdownTextRange(start, context.chars.cursor, "Unterminated inline code segment.")
                ));
                return MarkdownSyntax2Result.foundInline;
            }

            if(context.chars.peek() == '`' && context.chars.peekSameChar('`') == count)
            {
                context.push(CodeInline(
                    MarkdownTextRange(start, context.chars.cursor, context.chars.slice(start, context.chars.cursor))
                ));
                context.chars.advance(count);
                return MarkdownSyntax2Result.foundInline;
            }

            context.chars.advance(1);
        }
    }
}

@MarkdownSyntax2Parser('*', true)
@MarkdownSyntax2Parser('_', true)
struct EmphesisParser
{
    alias Inlines = AliasSeq!(WeakEmphesisInline, StrongEmphesisInline);

    MarkdownSyntax2Result parse(ContextT)(ref ContextT context)
    {
        const trigger = context.chars.peek();
        const count   = context.chars.peekSameChar(trigger);
        context.chars.advance(count);
        const start   = context.chars.cursor;

        while(true)
        {
            if(context.chars.eof)
                return MarkdownSyntax2Result.didNothing;

            if(context.chars.peek() == trigger && context.chars.peekSameChar(trigger) == count)
            {
                if(count == 1)
                {
                    context.push(WeakEmphesisInline(
                        MarkdownTextRange(start, context.chars.cursor, context.chars.slice(start, context.chars.cursor))
                    ));
                }
                else
                {
                    context.push(StrongEmphesisInline(
                        MarkdownTextRange(start, context.chars.cursor, context.chars.slice(start, context.chars.cursor))
                    ));
                }

                context.chars.advance(count);
                return MarkdownSyntax2Result.foundInline;
            }

            context.chars.advance(1);
        }
    }
}

@MarkdownSyntax2Parser('[', true)
struct LinkParser
{
    alias Inlines = AliasSeq!(LinkInline);

    MarkdownSyntax2Result parse(ContextT)(ref ContextT context)
    {
        const start = context.chars.cursor;
        context.chars.advance(1);

        string text;
        const textStart = context.chars.cursor;
        auto notEof = context.chars.eatUntil(']', text);

        if(!notEof)
        {
            context.chars.cursor = start;
            return MarkdownSyntax2Result.didNothing;
        }

        const textEnd = context.chars.cursor;
        context.chars.advance(1);

        if(context.chars.peek() != '(')
        {
            context.chars.cursor = start;
            return MarkdownSyntax2Result.didNothing;
        }

        context.chars.advance(1);
        const linkStart = context.chars.cursor;
        notEof = context.chars.eatUntil(')', text);

        if(!notEof)
        {
            context.chars.cursor = start;
            return MarkdownSyntax2Result.didNothing;
        }

        const linkEnd = context.chars.cursor;
        context.chars.advance(1);

        context.push(LinkInline(
            MarkdownTextRange(textStart, textEnd, context.chars.slice(textStart, textEnd)),
            MarkdownTextRange(linkStart, linkEnd, context.chars.slice(linkStart, linkEnd))
        ));
        return MarkdownSyntax2Result.foundInline;
    }
}

version(unittest) import std.stdio;

@("syntax2 - 328")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("`foo`");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!CodeInline);
}

@("syntax2 - 329")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("``foo ` bar``");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!CodeInline);
    assert(result.root.children[0].leafValue.inlines.length == 1);
}

@("syntax2 - 350")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("*foo bar*");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!WeakEmphesisInline);
    assert(result.root.children[0].leafValue.inlines.length == 1);
}

@("syntax2 - 377")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("**foo bar**");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!StrongEmphesisInline);
    assert(result.root.children[0].leafValue.inlines.length == 1);
}

@("syntax2 - big boy")
unittest
{
    string bigBoyTest = import("bigboytest.md");
    auto result = MarkdownDefault.doFullSyntax(bigBoyTest);
}

@("syntax2 - 482")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("[link](/url)");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!LinkInline);
    assert(result.root.children[0].leafValue.inlines.length == 1);
}

@("syntax2 - 483")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("[](./target.md)");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!LinkInline);
    assert(result.root.children[0].leafValue.inlines.length == 1);
}

@("syntax2 - 484")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("[link]()");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!LinkInline);
    assert(result.root.children[0].leafValue.inlines.length == 1);
}

@("syntax2 - 486")
unittest
{
    auto result = MarkdownDefault.doFullSyntax("[]()");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[0].leafValue.inlines[0].isType!LinkInline);
    assert(result.root.children[0].leafValue.inlines.length == 1);
}