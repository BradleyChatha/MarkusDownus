// Parse the file into blocks
module markusdownus.syntax1;

import std.stdio : writeln;
import std.exception : enforce;
import std.meta : AliasSeq;
import markusdownus.core, markusdownus.charreader;

enum SYNTAX1_DEFAULT_ALLOWED_WHITE_PREFIX_LIMIT = 3;

// version = MD_Debug_Verbose;

package struct Syntax1Context(MarkdownT)
{
    CharReader chars;
    MarkdownT.BlockUnion[] blockStack;
    MarkdownT.BlockUnion lastPushedBlock; // Only used for context-specific syntax, do not modify as it will not be applied.
    WhiteInfo lineWhitePrefix;

    this(string _)
    {
        this.blockStack ~= MarkdownT.BlockUnion(
            MarkdownT.ContainerBlockUnion(
                RootContainerBlock()
            )
        );
    }

    void push(T)(T leaf)
    if(__traits(compiles, MarkdownT.LeafBlockUnion(leaf)))
    {
        this.blockStack[$-1].containerValue.addChild(MarkdownT.LeafBlockUnion(leaf));
        this.lastPushedBlock = this.blockStack[$-1].containerValue.children[$-1];
    }

    void push(T)(T container)
    if(__traits(compiles, MarkdownT.ContainerBlockUnion(container)))
    {
        this.blockStack ~= MarkdownT.BlockUnion(
            MarkdownT.ContainerBlockUnion(container)
        );
        this.lastPushedBlock = this.blockStack[$-1];
    }

    bool pop()()
    {
        if(this.blockStack.length > 1)
        {
            auto block = this.blockStack[$-1];
            this.blockStack.length--;

            if(block.isContainer)
                this.blockStack[$-1].containerValue.addChild(block);

            return true;
        }
        else
            return false;
    }

    ref MarkdownT.BlockUnion peek()
    out(block; block.isContainer)
    {
        return this.blockStack[$-1];
    }

    @property @safe @nogc
    ref inout(MarkdownT.ContainerBlockUnion) root() nothrow inout
    {
        return this.blockStack[$-1].containerValue;
    }
}

// Break things down into leaf and container blocks, since the syntax is rather uniform.
package void syntax1(MarkdownT)(ref Syntax1Context!MarkdownT context)
{
    import std.algorithm : splitter, count;
    import std.traits    : getUDAs;
    import std.meta      : anySatisfy, Filter;

    const uniqueTriggers = GatherUniqueTriggers!(MarkdownSyntax1Parser, MarkdownT.Syntax1Parsers);
    size_t _1;

    While: while(!context.chars.eof)
    {
        const start = context.chars.cursor;
        context.lineWhitePrefix = context.chars.eatPrefixWhite();

        if(context.lineWhitePrefix.spaces || context.lineWhitePrefix.tabs)
        {
            context.chars.cursor = start;
            static foreach(i, parser; MarkdownT.Syntax1Parsers)
            {{
                enum wantsTrigger(alias uda) = uda.triggerChar == ' ' || uda.triggerChar == '\t';
                enum udas                    = getUDAs!(parser, MarkdownSyntax1Parser);
                enum canUse                  = anySatisfy!(wantsTrigger, udas);

                static if(canUse)
                {
                    const result = parser.init.parse(context);
                    version(MD_Debug_Verbose) writeln(context.chars.eof ? ' ' : context.chars.peek, " ", parser.stringof, " ", result);
                    if(result != MarkdownSyntax1Result.didNothing)
                        continue While;
                }
            }}
            context.chars.eatPrefixWhite();
        }

        if(context.chars.eof)
            break;

        size_t afterTrigger;
        bool wasEscaped;
        bool wasHandled;
        const trigger = context.chars.peekUtfEscaped(afterTrigger, wasEscaped);
        Switch: switch(trigger)
        {
            static foreach(uniqueTrigger; uniqueTriggers)
            {
                static if(uniqueTrigger != '\0')
                {
                    case uniqueTrigger:
                        static foreach(i, parser; MarkdownT.Syntax1Parsers)
                        {{
                            enum wantsTrigger(alias uda) = uda.triggerChar == uniqueTrigger;
                            enum udas                    = getUDAs!(parser, MarkdownSyntax1Parser);
                            enum canUse                  = anySatisfy!(wantsTrigger, udas);

                            static if(canUse)
                            {
                                enum prefixLimit = Filter!(wantsTrigger, udas)[0].spacePrefixLimit;
                                if(context.lineWhitePrefix.spaces <= prefixLimit && context.lineWhitePrefix.tabs == 0)
                                {
                                    const result = parser.init.parse(context);
                                    version(MD_Debug_Verbose) writeln(trigger, " ", parser.stringof, " ", result);
                                    if(result != MarkdownSyntax1Result.didNothing)
                                    {
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

        static foreach(i, parser; MarkdownT.Syntax1Parsers)
        {{
            enum wantsTrigger(alias uda) = uda.triggerChar == '\0';
            enum udas                    = getUDAs!(parser, MarkdownSyntax1Parser);
            enum canUse                  = anySatisfy!(wantsTrigger, udas);

            static if(canUse)
            {
                const result = parser.init.parse(context);
                version(MD_Debug_Verbose) writeln(trigger, " ", parser.stringof, " ", result);
                if(result != MarkdownSyntax1Result.didNothing)
                    continue While;
            }
        }}

        context.chars.eatLine(_1);
    }

    while(context.pop()){}
}

package template GatherUniqueTriggers(UDA, Parsers...)
{
    dchar[] get()
    {
        import std.algorithm : canFind;
        import std.array     : array;
        import std.traits    : getUDAs;

        dchar[] values;
        static foreach(parser; Parsers)
        {
            static foreach(uda; getUDAs!(parser, UDA))
            {
                if(!values.canFind(cast(dchar)uda.triggerChar))
                    values ~= uda.triggerChar;
            }
        }

        return values.array;
    }
    enum GatherUniqueTriggers = get();
}

@MarkdownLeafBlock("header")
struct HeaderLeafBlock
{
    MarkdownTextRange range;
    uint level;
}

@MarkdownLeafBlock("thematicBreak")
struct ThematicBreakLeafBlock
{
    MarkdownTextRange range;
}

@MarkdownLeafBlock("setextHeader")
struct SetextHeaderLeafBlock
{
    MarkdownTextRange range;
    uint level;
}

@MarkdownLeafBlock("blankLine")
struct BlankLineLeafBlock
{
}

@MarkdownLeafBlock("indentedCode")
struct IndentedCodeLeafBlock
{
    MarkdownTextRange range;
}

@MarkdownLeafBlock("fencedCode")
struct FencedCodeLeafBlock
{
    MarkdownTextRange lang;
    MarkdownTextRange code;
}

@MarkdownLeafBlock("paragraphLine")
struct ParagraphLineLeafBlock
{
    MarkdownTextRange range;
}

@MarkdownContainerBlock("quoteBlock")
struct QuoteContainerBlock
{
}

@MarkdownContainerBlock("listItem")
struct ListItemContainerBlock
{
    uint indentLevel;
}

@MarkdownSyntax1Parser('#')
struct HeaderParser
{
    enum MAX_LEVEL = 6;

    alias LeafBlocks = AliasSeq!(HeaderLeafBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        const level = context.chars.peekSameChar('#');
        const start = context.chars.cursor;
        size_t end;
        context.chars.eatLine(end);

        if(level > MAX_LEVEL)
        {
            context.push(JunkLeafBlock(
                MarkdownTextRange(start, end, context.chars.slice(start, end)),
                "Header level is too large."
            ));
            return MarkdownSyntax1Result.foundLeafBlock;
        }

        const textStart = start + level;
        context.push(HeaderLeafBlock(
            MarkdownTextRange(textStart, end, context.chars.slice(textStart, end)),
            cast(uint)level
        ));

        return MarkdownSyntax1Result.foundLeafBlock;
    }
}

@MarkdownSyntax1Parser('-')
@MarkdownSyntax1Parser('_')
@MarkdownSyntax1Parser('*')
struct ThematicBreakParser
{
    alias LeafBlocks = AliasSeq!(ThematicBreakLeafBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        const triggerChar = context.chars.peek;
        const start = context.chars.cursor;
        const count = context.chars.peekSameChar(triggerChar);

        if(count < 3 || !context.chars.atEndOfLine(count))
            return MarkdownSyntax1Result.didNothing;

        context.peek();

        size_t end;
        context.chars.eatLine(end);
        context.push(ThematicBreakLeafBlock(
            MarkdownTextRange(start, end, context.chars.slice(start, end))
        ));
        return MarkdownSyntax1Result.foundLeafBlock;
    }
}

@MarkdownSyntax1Parser('\0')
struct SetextHeaderParser
{
    alias LeafBlocks = AliasSeq!(SetextHeaderLeafBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        if(context.lineWhitePrefix.spaces > SYNTAX1_DEFAULT_ALLOWED_WHITE_PREFIX_LIMIT
        || context.lineWhitePrefix.tabs > 0)
        {
            version(MD_Debug_Verbose) writeln("[Setext] Failed because of whitespace: ", context.lineWhitePrefix);
            return MarkdownSyntax1Result.didNothing;
        }

        const start = context.chars.cursor;

        size_t endOfLine;
        context.chars.eatLine(endOfLine);

        const white = context.chars.eatPrefixWhite();
        if(white.spaces > 3 || white.tabs > 0)
        {
            version(MD_Debug_Verbose) writeln("[Setext] Failed because of whitespace: ", white);
            context.chars.cursor = start;
            return MarkdownSyntax1Result.didNothing;
        }

        if(context.chars.eof)
        {
            version(MD_Debug_Verbose) writeln("[Setext] Failed because of eof: ", start, " ", endOfLine, " ", context.chars.cursor);
            context.chars.cursor = start;
            return MarkdownSyntax1Result.didNothing;
        }

        bool wasEscaped;
        const next = context.chars.peekEscaped(wasEscaped);
        if(wasEscaped)
        {
            version(MD_Debug_Verbose) writeln("[Setext] Failed because character was escaped: ", next);
            context.chars.cursor = start;
            return MarkdownSyntax1Result.didNothing;
        }
        else if(next != '-' && next != '=')
        {
            version(MD_Debug_Vebose) writeln("[Setext] Failed because character is not a - or =: ", next);
            context.chars.cursor = start;
            return MarkdownSyntax1Result.didNothing;
        }

        const count = context.chars.peekSameChar(next);
        context.chars.advance(count);
        context.chars.eatPrefixWhite();
        if(!context.chars.atEndOfLine)
        {
            version(MD_Debug_Verbose) writeln("[Setext] Failed because we're not at the end of the line: ", context.chars.cursor, " ", context.chars.peek);
            context.chars.cursor = start;
            return MarkdownSyntax1Result.didNothing;
        }
        else if(next == '-' && count == 1)
        {
            version(MD_Debug_Verbose) writeln("[Setext] Failed because delim is '-' but there's only one of them, so it could be a list item.");
            context.chars.cursor = start;
            return MarkdownSyntax1Result.didNothing;
        }

        context.push(SetextHeaderLeafBlock(
            MarkdownTextRange(start, endOfLine, context.chars.slice(start, endOfLine)),
            next == '-' ? 1 : 2
        ));
        return MarkdownSyntax1Result.foundLeafBlock;
    }
}

@MarkdownSyntax1Parser(' ')
@MarkdownSyntax1Parser('\t')
@MarkdownSyntax1Parser('\n')
struct BlankLineParser
{
    alias LeafBlocks = AliasSeq!(BlankLineLeafBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        const start = context.chars.cursor;
        const white = context.chars.eatPrefixWhite();
        
        if(!context.chars.atEndOfLine)
        {
            version(MD_Debug_Verbose) writeln("[BlankLine] Failed because the line isn't blank");
            context.chars.cursor = start;
            return MarkdownSyntax1Result.didNothing;
        }

        size_t _1;
        context.chars.eatLine(_1);
        context.pop();
        context.push(BlankLineLeafBlock());
        return MarkdownSyntax1Result.foundLeafBlock;
    }
}

@MarkdownSyntax1Parser(' ')
@MarkdownSyntax1Parser('\t')
struct IndentedCodeParser
{
    alias LeafBlocks = AliasSeq!(IndentedCodeLeafBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        if(context.lastPushedBlock.isLeafOfType!ParagraphLineLeafBlock)
        {
            version(MD_Debug_Verbose) writeln("[IndentedCode] Failed because the previous block was a paragraph.");
            return MarkdownSyntax1Result.didNothing;
        }

        if(context.lineWhitePrefix.spaces < 4 && context.lineWhitePrefix.tabs < 1)
        {
            version(MD_Debug_Verbose) writeln("[IndentedCode] Failed because of prefix whitespace: ", context.lineWhitePrefix);
            return MarkdownSyntax1Result.didNothing;
        }

        const start = context.chars.cursor;
        size_t end;
        context.chars.eatLine(end);

        context.push(IndentedCodeLeafBlock(
            MarkdownTextRange(start, end, context.chars.slice(start, end))
        ));

        return MarkdownSyntax1Result.foundLeafBlock;
    }
}

@MarkdownSyntax1Parser('`')
@MarkdownSyntax1Parser('~')
struct FencedCodeParser
{
    enum REQUIRED_FENCE_CHARS = 3;

    alias LeafBlocks = AliasSeq!(FencedCodeLeafBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        if(context.lineWhitePrefix.spaces > 3 || context.lineWhitePrefix.tabs)
        {
            version(MD_Debug_Verbose) writeln("[FencedCode] Failed because of prefix whitespace: ", context.lineWhitePrefix);
            return MarkdownSyntax1Result.didNothing;
        }

        const fenceChar = context.chars.peek();
        const count = context.chars.peekSameChar(fenceChar);

        if(count < REQUIRED_FENCE_CHARS)
            return MarkdownSyntax1Result.didNothing;

        context.chars.advance(count);
        const startLang = context.chars.cursor;
        size_t endLang;
        context.chars.eatLine(endLang);

        const startCode = context.chars.cursor;
        while(true)
        {
            const white = context.chars.eatPrefixWhite();
            if(context.chars.eof)
            {
                version(MD_Debug_Verbose) writeln("[FencedCode] Unterminated code block");
                context.push(JunkLeafBlock(
                    MarkdownTextRange(startLang, context.chars.cursor, ""),
                    "Unterminated code block"
                ));
                return MarkdownSyntax1Result.foundLeafBlock;
            }
            else if((white.spaces > 3 || white.tabs) || context.chars.peek() != fenceChar)
            {
                size_t _1;
                context.chars.eatLine(_1);
                continue;
            }

            const fenceCount = context.chars.peekSameChar(fenceChar);
            if(fenceCount < REQUIRED_FENCE_CHARS)
            {
                size_t _1;
                context.chars.eatLine(_1);
                continue;
            }

            context.push(FencedCodeLeafBlock(
                MarkdownTextRange(startLang, endLang, context.chars.slice(startLang, endLang)),
                MarkdownTextRange(startCode, context.chars.cursor, context.chars.slice(startLang, context.chars.cursor))
            ));
            context.chars.advance(fenceCount);
            return MarkdownSyntax1Result.foundLeafBlock;
        }
    }
}

@MarkdownSyntax1Parser('\0', uint.max)
struct ParagraphLineParser
{
    alias LeafBlocks = AliasSeq!(ParagraphLineLeafBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        import std.algorithm : all;
        import std.ascii : isWhite;
        import std.string : stripLeft, stripRight;
            
        auto start = context.chars.cursor;
        size_t end;

        context.chars.eatLine(end);

        auto lineStart = context.chars.cursor;
        size_t lineEnd;

        if(!context.peek.isContainerOfType!QuoteContainerBlock) // It parses weirdly otherwise.
        {
            while(true)
            {
                context.chars.eatLine(lineEnd);
                if(context.chars.eof)
                {
                    end = context.chars.length;
                    break;
                }
                if(context.chars.slice(lineStart, lineEnd).all!isWhite)
                {
                    end = lineStart;
                    context.chars.cursor = lineStart;
                    break;
                }

                lineStart = lineEnd;
            }
        }

        const text = context.chars.slice(start, end);
        auto stripped = stripLeft(text);
        start += (text.length - stripped.length);
        stripped = stripRight(text);
        end -= (text.length - stripped.length);

        context.push(ParagraphLineLeafBlock(
            MarkdownTextRange(start, end, context.chars.slice(start, end))
        ));
        return MarkdownSyntax1Result.foundLeafBlock;
    }
}

@MarkdownSyntax1Parser('>')
struct QuoteParser
{
    alias ContainerBlocks = AliasSeq!(QuoteContainerBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        context.chars.advance(1);

        if(context.peek().isContainerOfType!QuoteContainerBlock)
        {
            if(context.lineWhitePrefix.spaces >= 4 || context.lineWhitePrefix.tabs)
                context.pop();
            return MarkdownSyntax1Result.foundContainerBlock;
        }

        if(context.lineWhitePrefix.spaces >= 4 || context.lineWhitePrefix.tabs)
            return MarkdownSyntax1Result.didNothing;

        context.push(QuoteContainerBlock());
        return MarkdownSyntax1Result.foundContainerBlock;
    }
}

// Slight issue where this design falls apart buuuuuuuuuuuut meep.
@MarkdownSyntax1Parser('-')
@MarkdownSyntax1Parser('*')
@MarkdownSyntax1Parser('+')
@MarkdownSyntax1Parser('0')
@MarkdownSyntax1Parser('1')
@MarkdownSyntax1Parser('2')
@MarkdownSyntax1Parser('3')
@MarkdownSyntax1Parser('4')
@MarkdownSyntax1Parser('5')
@MarkdownSyntax1Parser('6')
@MarkdownSyntax1Parser('7')
@MarkdownSyntax1Parser('8')
@MarkdownSyntax1Parser('9')
struct ListItemParser
{
    alias ContainerBlocks = AliasSeq!(ListItemContainerBlock);

    MarkdownSyntax1Result parse(Context)(ref Context context)
    {
        import std.ascii : isDigit;
        const trigger = context.chars.peek();

        if(trigger.isDigit)
        {
            if(context.chars.peek(1) != '.')
                return MarkdownSyntax1Result.didNothing;

            context.chars.advance(1);
        }

        context.chars.advance(1);

        if(context.lineWhitePrefix.spaces >= 4 || context.lineWhitePrefix.tabs)
            return MarkdownSyntax1Result.didNothing;

        if(!context.chars.eof && context.chars.peek() != ' ' && context.chars.peek() != '\t')
        {
            context.chars.retreat(1);
            if(trigger.isDigit)
                context.chars.retreat(1);
            return MarkdownSyntax1Result.didNothing;
        }

        context.pop();
        context.push(ListItemContainerBlock());
        return MarkdownSyntax1Result.foundContainerBlock;
    }
}

// All examples are from the 0.30 revision of common mark's spec

@("syntax1 - 43")
unittest
{
    static foreach(str; ["***", "---", "___"])
    {{
        auto result = MarkdownDefault.doSyntax1(str);
        assert(result.root.childIsLeafOfType!ThematicBreakLeafBlock(0), str);
        assert(result.chars.eof);
    }}

    auto result = MarkdownDefault.doSyntax1("***\n---\r\n___");
    static foreach(i; 0..3)
        assert(result.root.childIsLeafOfType!ThematicBreakLeafBlock(i));
    assert(result.chars.eof);
}

@("syntax1 - 80,83,84,85,86,87,88,106")
unittest
{
    // passing
    static foreach(str; [
        "Foo *bar*\n======", 
        "Foo *bar*\n-----",
        "   Foo\n=",
        " Foo\n   --",
        "Foo\n= "
    ])
        assert(MarkdownDefault.doSyntax1(str).root.childIsLeafOfType!SetextHeaderLeafBlock(0), str);

    // failing
    static foreach(str; [
        "    Foo\n=",
        "Foo\n    =",
        "Foo\n= =",
        "Foo\n--- -",
        "Foo\n\\---"
    ])
    {{
        auto result = MarkdownDefault.doSyntax1(str);
        assert(result.root.children.length == 0 || !result.root.childIsLeafOfType!SetextHeaderLeafBlock(0), str);
    }}
}

@("syntax1 - 107")
unittest
{
    static foreach(str; [
        "    a simple\n      indented code block"
    ])
        assert(MarkdownDefault.doSyntax1(str).root.childIsLeafOfType!IndentedCodeLeafBlock(0), str);
}

@("syntax1 - 119,120,122,129,130,142")
unittest
{
    static foreach(str; [
        "```\n<\n >\n```",
        "~~~\n<\n >\n~~~",
        "```\naaa\n```",
        "```\n   \n```",
        "```\n```",
        "```ruby\ndef foo(x)\n  return 3\nend\n```"
    ])
        assert(MarkdownDefault.doSyntax1(str).root.childIsLeafOfType!FencedCodeLeafBlock(0), str);
}

@("syntax1 - 219,220,221,222,223,224")
unittest
{
    static foreach(str; [
        "aaa\n\nbbb",
        "aaa\nbbb\n\nccc\nddd",
        "aaa\n\n\nbbb",
        "  aaa\n bbb",
        "aaa\n                     bbb\n                                    ccc",
        "   aaa\nbbb"
    ])
    {{
        auto root = MarkdownDefault.doSyntax1(str).root;
        foreach(i; 0..root.children.length)
            assert(root.childIsLeafOfType!ParagraphLineLeafBlock(i)
                || root.childIsLeafOfType!BlankLineLeafBlock(i)
            , str);
    }}
}

@("syntax1 - 228,229,230,232")
unittest
{
    import std.conv : to;

    foreach(str; [
        "> # Foo\n> bar\n> baz",
        "># Foo\n>bar\n> baz",
        "   > # Foo\n   > bar\n > baz",
        "> # Foo\n> bar\nbaz"
    ])
    {
        auto result = MarkdownDefault.doSyntax1(str).root;
        assert(result.children.length == 1, result.children.to!string);
        assert(result.children[0].isContainerOfType!QuoteContainerBlock);
        
        const quote = result.children[0].containerValue;
        assert(quote.children.length == 3);
        assert(quote.children[0].isLeafOfType!HeaderLeafBlock);
        assert(quote.children[1].isLeafOfType!ParagraphLineLeafBlock);
        assert(quote.children[2].isLeafOfType!ParagraphLineLeafBlock);
    }
}

@("syntax1 - 255")
unittest
{
    auto result = MarkdownDefault.doSyntax1("- one\n\n two");
    assert(result.root.children[0].isContainerOfType!ListItemContainerBlock);
    assert(result.root.children[0].containerValue.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[2].isLeafOfType!ParagraphLineLeafBlock);
}

@("syntax1 - 261")
unittest
{
    auto result = MarkdownDefault.doSyntax1("-one\n\n2.two");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children[2].isLeafOfType!ParagraphLineLeafBlock);
}

@("syntax1 - paragraph coalescence")
unittest
{
    auto result = MarkdownDefault.doSyntax1("abc\n123\neeasy as\n321\nray doe me");
    assert(result.root.children[0].isLeafOfType!ParagraphLineLeafBlock);
    assert(result.root.children.length == 1);
}