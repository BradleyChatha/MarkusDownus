module markusdownus.inlines;

import markusdownus;

struct MarkdownPlainTextInline
{
    string text;
}

struct MarkdownCodeSpanInline
{
    string code;
}

struct MarkdownLinkInline
{
    string label;
    string url;
    string title;
    bool isImage;
}

struct MarkdownEmphesisInline
{
    char emphChar;
    uint count;
    bool prefixWhite;
    bool postfixWhite;

    enum RenderMode
    {
        start,
        end,
        dont
    }
    RenderMode renderMode = RenderMode.start; // Used in the render pass.
}

@MarkdownInlineParser('`')
struct MarkdownCodeSpanInlineParser
{
    alias Targets = MarkdownCodeSpanInline;

    static MarkdownInlinePassResult tryParse(AstT)(ref CharReader chars, ref AstT.Leaf leaf)
    {
        const count = chars.peekSameChar('`');
        chars.advance(count);

        bool wasNewLine;
        string _1;
        const start = chars.cursor;

        while(true)
        {
            if(chars.eof)
                return MarkdownInlinePassResult.didNothing;

            const found = chars.eatUntilOrEndOfLine('`', _1, wasNewLine);
            if(wasNewLine || !found)
                return MarkdownInlinePassResult.didNothing;

            const endCount = chars.peekSameChar('`');
            if(endCount != count)
            {
                chars.advance(endCount);
                continue;
            }

            leaf.push(MarkdownCodeSpanInline(
                chars.slice(start, chars.cursor)
            ));
            chars.advance(endCount);
            return MarkdownInlinePassResult.foundInline;
        }
    }
}

@MarkdownInlineParser('[')
@MarkdownInlineParser('!')
struct MarkdownLinkInlineParser
{
    alias Targets = MarkdownLinkInline;

    static MarkdownInlinePassResult tryParse(AstT)(ref CharReader chars, ref AstT.Leaf leaf)
    {
        bool isImage = chars.peek() == '!';
        if(isImage)
        {
            chars.advance(1);
            if(chars.eof || chars.peek() != '[')
                return MarkdownInlinePassResult.didNothing;
        }

        chars.advance(1);
        const labelStart = chars.cursor;
        
        string _1;
        bool wasNewLine;
        const found = chars.eatUntilOrEndOfLine(']', _1, wasNewLine);
        if(!found || wasNewLine)
            return MarkdownInlinePassResult.didNothing;

        const labelEnd = chars.cursor;
        chars.advance(1);

        if(chars.eof || chars.peek() != '(')
            return MarkdownInlinePassResult.didNothing;
        chars.advance(1);

        size_t urlStart;
        size_t urlEnd;
        bool foundEnd;
        if(chars.peek() == '<')
        {
            chars.advance(1);
            urlStart = chars.cursor;
            const urlEndFound = chars.eatUntilOrEndOfLine('>', _1, wasNewLine);

            if(!urlEndFound || wasNewLine)
                return MarkdownInlinePassResult.didNothing;

            urlEnd = chars.cursor;
            chars.advance(1);
        }
        else
        {
            urlStart = chars.cursor;
            while(true)
            {
                if(chars.eof)
                    return MarkdownInlinePassResult.didNothing;
                
                if(chars.peek() == ' ')
                {
                    urlEnd = chars.cursor;
                    chars.advance(1);
                    break;
                }
                else if(chars.peek() == ')')
                {
                    urlEnd = chars.cursor;
                    foundEnd = true;
                    break;
                }
                else if(chars.peek() == '\n')
                    return MarkdownInlinePassResult.didNothing;
                chars.advance(1);
            }
        }
        chars.eatInlineWhite();
        if(chars.eof && !foundEnd)
            return MarkdownInlinePassResult.didNothing;

        size_t titleStart;
        size_t titleEnd;
        if(!foundEnd && chars.peek() != ')')
        { 
            if(chars.peek() != '"')
                return MarkdownInlinePassResult.didNothing;
            chars.advance(1);
            titleStart = chars.cursor;

            const titleEndFound = chars.eatUntilOrEndOfLine('"', _1, wasNewLine);
            if(!titleEndFound || wasNewLine)
                return MarkdownInlinePassResult.didNothing;

            titleEnd = chars.cursor();
            chars.advance(1);
            chars.eatInlineWhite();
        }

        if(!foundEnd && chars.peek() != ')')
            return MarkdownInlinePassResult.didNothing;
        chars.advance(1);

        leaf.push(MarkdownLinkInline(
            chars.slice(labelStart, labelEnd),
            chars.slice(urlStart, urlEnd),
            chars.slice(titleStart, titleEnd),
            isImage
        ));
        return MarkdownInlinePassResult.foundInline;
    }
}

@MarkdownInlineParser('*')
@MarkdownInlineParser('_')
struct MarkdownEmphesisInlineParser
{
    alias Targets = MarkdownEmphesisInline;

    static MarkdownInlinePassResult tryParse(AstT)(ref CharReader chars, ref AstT.Leaf leaf)
    {
        char prePeek = '\n'; // Solves a special case where an emphesis character is the first character.
        if(chars.cursor > 0)
        {
            chars.retreat(1);
            prePeek = chars.peek();
            chars.advance(1);
        }

        const emphChar = chars.peek();
        const count = chars.peekSameChar(emphChar);
        chars.advance(count-1);
        chars.advance(1);

        auto postPeek = '\n';
        if(!chars.eof)
            postPeek = chars.peek();

        const renderAsText = count > 3; // Further checks are done at render time, since the renderer can see the whole inline AST.
        leaf.push(MarkdownEmphesisInline(
            emphChar,
            cast(uint)count,
            prePeek == ' ' || prePeek == '\n',
            postPeek == ' ' || postPeek == '\n',
            renderAsText ? MarkdownEmphesisInline.RenderMode.dont : MarkdownEmphesisInline.RenderMode.start
        ));
        return MarkdownInlinePassResult.foundInline;
    }
}

@MarkdownInlineParser('<')
struct MarkdownAutolinkParser
{
    alias Targets = MarkdownLinkInline;

    static MarkdownInlinePassResult tryParse(AstT)(ref CharReader chars, ref AstT.Leaf leaf)
    {
        chars.advance(1);

        bool wasNewLine;
        string text;
        if(!chars.eatUntilOrEndOfLine('>', text, wasNewLine))
            return MarkdownInlinePassResult.didNothing;
        chars.advance(1);
        if(wasNewLine || !text.length)
            return MarkdownInlinePassResult.didNothing;

        import std.algorithm : canFind, startsWith, map;
        import std.array     : array;
        import std.uni       : toLower;
        if(text.canFind(' ') || text.canFind('\t'))
            return MarkdownInlinePassResult.didNothing;

        leaf.push(MarkdownLinkInline(
            text, 
            (text.canFind('@') && !text.map!toLower.startsWith("mailto:")) ? "mailto:"~text : text, 
            null, 
            false
        ));
        return MarkdownInlinePassResult.foundInline;
    }
}