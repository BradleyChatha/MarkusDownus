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

        if(chars.peek() != '(')
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
                    chars.advance(1);
                    urlEnd = chars.cursor;
                    break;
                }
                else if(chars.peek() == ')')
                {
                    chars.advance(1);
                    urlEnd = chars.cursor;
                    foundEnd = true;
                    break;
                }
                chars.advance(1);
            }
        }
        chars.eatInlineWhite();

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