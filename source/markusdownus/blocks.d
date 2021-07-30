module markusdownus.blocks;

import std;
import markusdownus;

struct MarkdownRootContainer
{
}

struct MarkdownQuoteContainer
{
}

struct MarkdownUnorderedListContainer
{
    char delim;
}

@MarkdownHasInlines("lines")
struct MarkdownParagraphLeaf
{
    char[] lines;
}

struct MarkdownThematicBreakLeaf
{
}

struct MarkdownIndentedCodeLeaf
{
    string code;
}

@MarkdownHasInlines("text")
struct MarkdownHeaderLeaf
{
    uint level;
    string text;
}

@MarkdownHasInlines("lines")
struct MarkdownSetextHeaderLeaf
{
    uint level;
    MarkdownParagraphLeaf text;

    auto lines()
    {
        return text.lines;
    }
}

struct MarkdownFencedCodeLeaf
{
    string code;
    string language;
}

struct MarkdownLinkReferenceDefinitionLeaf
{
    string label;
    string url;
    string title;
}

@MarkdownContainerParser('>', 10, true)
struct MarkdownQuoteContainerParser
{
    alias Targets = MarkdownQuoteContainer;

    static MarkdownBlockPassResult tryOpen(AstT)(ref AstT.Context ctx)
    {
        ctx.push(
            MarkdownQuoteContainer(),
            ctx.lineWhite.spaces + 2,
            10,
            &tryClose!AstT
        );
        ctx.chars.advance(1);
        return MarkdownBlockPassResult.openContainer;
    }

    static MarkdownBlockPassResult tryClose(AstT)(ref AstT.Context ctx, ref AstT.Container container, bool forceClose)
    {
        if(forceClose)
        {
            ctx.pop();
            return MarkdownBlockPassResult.closeContainer;
        }

        if(ctx.lineWhite.spaces >= 4)
            return MarkdownBlockPassResult.didNothing;

        size_t newLineChar;
        if(ctx.chars.isRestOfLineEmpty(newLineChar))
        {
            ctx.pop();
            return MarkdownBlockPassResult.closeContainer;
        }

        if(ctx.chars.peek() == '>')
            ctx.chars.advance(1);

        return MarkdownBlockPassResult.continueContainer;
    }
}

@MarkdownContainerParser('*', 8, true)
@MarkdownContainerParser('-', 8, true)
@MarkdownContainerParser('-', 8, true)
struct MarkdownUnorderedListContainerParser
{
    alias Targets = MarkdownUnorderedListContainer;

    static MarkdownBlockPassResult tryOpen(AstT)(ref AstT.Context ctx)
    {
        const delim = ctx.chars.peek();
        ctx.chars.advance(1);
        if(ctx.chars.eof || !ctx.chars.peek().isInlineWhite)
            return MarkdownBlockPassResult.didNothing;
            
        ctx.push(
            MarkdownUnorderedListContainer(delim),
            ctx.lineWhite.spaces + 2,
            9,
            &tryClose!AstT
        );
        return MarkdownBlockPassResult.openContainer;
    }

    static MarkdownBlockPassResult tryClose(AstT)(ref AstT.Context ctx, ref AstT.Container container, bool forceClose)
    {
        if(forceClose)
        {
            ctx.pop();
            return MarkdownBlockPassResult.closeContainer;
        }

        size_t newLineChar;
        if(ctx.chars.isRestOfLineEmpty(newLineChar))
        {
            ctx.pop();
            return MarkdownBlockPassResult.closeContainer;
        }

        auto delim = container.getMarkdownUnorderedListContainer().delim;
        if(ctx.chars.peek() == delim)
            ctx.chars.advance(1);

        return MarkdownBlockPassResult.continueContainer;
    }
}

@MarkdownLeafParser('-', 15, true)
@MarkdownLeafParser('_', 15, true)
@MarkdownLeafParser('*', 15, true)
struct MarkdownThematicBreakLeafParser
{
    alias Targets = MarkdownThematicBreakLeaf;

    static MarkdownBlockPassResult tryParse(AstT)(ref AstT.Context ctx)
    {
        if(!ctx.chars.atStartOfLine || ctx.lineWhite.spaces >= 4)
            return MarkdownBlockPassResult.didNothing;

        const delim = ctx.chars.peek();
        const count = ctx.chars.peekSameChar(delim);

        size_t newLineChar;
        ctx.chars.advance(count);
        if(count < 3 || !ctx.chars.isRestOfLineEmpty(newLineChar))
            return MarkdownBlockPassResult.didNothing;

        ctx.chars.cursor = newLineChar + !ctx.chars.eof;
        ctx.push(MarkdownThematicBreakLeaf(), 15);
        return MarkdownBlockPassResult.foundLeaf;
    }
}

@MarkdownLeafParser(' ', 20, false)
struct MarkdownIndentedCodeLeafParser
{
    alias Targets = MarkdownIndentedCodeLeaf;

    static MarkdownBlockPassResult tryParse(AstT)(ref AstT.Context ctx)
    {
        if(ctx.lineWhite.spaces < 4 || ctx.paragraph.lines.length)
            return MarkdownBlockPassResult.didNothing;

        const start = ctx.chars.cursor;

        size_t newLineChar;
        ctx.chars.eatLine(newLineChar);

        while(true)
        {
            if(ctx.chars.eof)
                break;

            const white = ctx.chars.eatInlineWhite();
            size_t _1;
            if(white.spaces < 4 && !ctx.chars.isRestOfLineEmpty(_1))
                break;

            ctx.chars.eatLine(newLineChar);
        }

        ctx.chars.cursor = newLineChar;
        ctx.push(MarkdownIndentedCodeLeaf(
            ctx.chars.slice(start, newLineChar)
        ), 20);
        return MarkdownBlockPassResult.foundLeaf;
    }
}

@MarkdownLeafParser('#', 9, true)
struct MarkdownHeaderLeafParser
{
    alias Targets = MarkdownHeaderLeaf;

    static MarkdownBlockPassResult tryParse(AstT)(ref AstT.Context ctx)
    {
        if(ctx.lineWhite.spaces > 3)
            return MarkdownBlockPassResult.didNothing;

        const count = ctx.chars.peekSameChar('#');
        if(count > 6)
            return MarkdownBlockPassResult.didNothing;

        ctx.chars.advance(count);
        if(ctx.chars.eof || !ctx.chars.peek.isInlineWhite)
            return MarkdownBlockPassResult.didNothing;

        const start = ctx.chars.cursor;
        size_t end;
        ctx.chars.eatLine(end);
        ctx.push(MarkdownHeaderLeaf(cast(uint)count, ctx.chars.slice(start, end).strip), 10);
        return MarkdownBlockPassResult.foundLeaf;
    }
}

@MarkdownLeafParser('=', 9, true)
@MarkdownLeafParser('-', 16, true)
struct MarkdownSetextHeaderLeafParser
{
    alias Targets = MarkdownSetextHeaderLeaf;

    static MarkdownBlockPassResult tryParse(AstT)(ref AstT.Context ctx)
    {
        if(!ctx.chars.atStartOfLine || ctx.lineWhite.spaces >= 4)
            return MarkdownBlockPassResult.didNothing;

        const delim = ctx.chars.peek();
        const count = ctx.chars.peekSameChar(delim);

        size_t newLineChar;
        ctx.chars.advance(count);
        if(!ctx.chars.isRestOfLineEmpty(newLineChar) || ctx.paragraph == MarkdownParagraphLeaf.init)
            return MarkdownBlockPassResult.didNothing;

        auto paragraph = ctx.paragraph;
        ctx.paragraph = MarkdownParagraphLeaf.init;
        ctx.chars.cursor = newLineChar + !ctx.chars.eof;
        ctx.push(MarkdownSetextHeaderLeaf(delim == '-' ? 2 : 1, paragraph), 9);
        return MarkdownBlockPassResult.foundLeaf;
    }
}

@MarkdownLeafParser('`', 9, true)
struct MarkdownFencedCodeLeafParser
{
    alias Targets = MarkdownFencedCodeLeaf;

    static MarkdownBlockPassResult tryParse(AstT)(ref AstT.Context ctx)
    {
        ctx.pushParagraphIfNeeded();
        const count = ctx.chars.peekSameChar('`');
        if(count < 3)
            return MarkdownBlockPassResult.didNothing;

        ctx.chars.advance(count);
        const langStart = ctx.chars.cursor;
        size_t langEnd = langStart;
        if(!ctx.chars.isRestOfLineEmpty(langEnd)) {}

        size_t _1;
        ctx.chars.eatLine(_1);

        string _2;
        const textStart = ctx.chars.cursor;
        size_t textEnd = textStart;

        while(true)
        {
            const notEof = ctx.chars.eatUntil('`', _2);
            if(!notEof)
                return MarkdownBlockPassResult.didNothing;

            const endCount = ctx.chars.peekSameChar('`');
            textEnd = ctx.chars.cursor;
            ctx.chars.advance(endCount);
            if(endCount != count)
                continue;

            break;
        }

        ctx.push(MarkdownFencedCodeLeaf(
            ctx.chars.slice(textStart, textEnd),
            ctx.chars.slice(langStart, langEnd)
        ), 9);
        return MarkdownBlockPassResult.foundLeaf;
    }
}

@MarkdownLeafParser('[', 9, false)
struct MarkdownLinkReferenceDefinitionLeafParser
{
    alias Targets = MarkdownLinkReferenceDefinitionLeaf;

    static MarkdownBlockPassResult tryParse(AstT)(ref AstT.Context ctx)
    {
        ctx.chars.advance(1);

        bool wasNewLine;
        string _2;
        const labelStart = ctx.chars.cursor;
        const foundLabelEnd = ctx.chars.eatUntilOrEndOfLine(']', _2, wasNewLine);

        if(!foundLabelEnd || wasNewLine)
            return MarkdownBlockPassResult.didNothing;

        const labelEnd = ctx.chars.cursor;
        ctx.chars.advance(1);

        const white = ctx.chars.eatInlineWhite();
        if(white.spaces > 3)
            return MarkdownBlockPassResult.didNothing;

        if(ctx.chars.peek() != ':')
            return MarkdownBlockPassResult.didNothing;
        ctx.chars.advance(1);

        const urlWhite = ctx.chars.eatInlineWhite();
        if(ctx.chars.atEndOfLine)
        {
            size_t _1;
            ctx.chars.eatLine(_1);
            ctx.chars.eatInlineWhite();
            if(ctx.chars.atEndOfLine)
                return MarkdownBlockPassResult.didNothing;
        }

        const urlStart = ctx.chars.cursor;
        const foundUrlEnd = ctx.chars.eatUntilOrEndOfLine(' ', _2, wasNewLine);
        if(!foundUrlEnd)
            return MarkdownBlockPassResult.didNothing;
        const urlEnd = ctx.chars.cursor;

        size_t titleStart;
        size_t titleEnd;
        if(!wasNewLine)
        {
            ctx.chars.eatInlineWhite();
            if(ctx.chars.peek() == '"')
            {
                ctx.chars.advance(1);
                titleStart = ctx.chars.cursor;

                const foundTitleEnd = ctx.chars.eatUntilOrEndOfLine('"', _2, wasNewLine);
                if(wasNewLine)
                {
                    ctx.chars.cursor = titleStart;
                    titleStart = 0;
                }
                else
                {
                    titleEnd = ctx.chars.cursor;
                    ctx.chars.advance(1);
                }
            }
        }

        ctx.push(
            MarkdownLinkReferenceDefinitionLeaf(
                ctx.chars.slice(labelStart, labelEnd),
                ctx.chars.slice(urlStart, urlEnd),
                ctx.chars.slice(titleStart, titleEnd)
            ),
            9
        );
        return MarkdownBlockPassResult.foundLeaf;
    }
}