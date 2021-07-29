module markusdownus.htmlrender;

import std;
import markusdownus;

struct MarkdownRootContainerHtmlRenderer
{
    alias Target = MarkdownRootContainer;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
    }

    static void beginChild(Renderer, Child)(Target target, Child child, ref Appender!(char[]) output, ref Renderer rnd)
    {
    }

    static void endChild(Renderer, Child)(Target target, Child child, ref Appender!(char[]) output, ref Renderer rnd)
    {
    }
}

struct MarkdownUnorderedListContainerHtmlRenderer
{
    alias Target = MarkdownUnorderedListContainer;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<ul>");
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</ul>");
    }

    static void beginChild(Renderer, Child)(Target target, Child child, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<li>");
    }

    static void endChild(Renderer, Child)(Target target, Child child, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</li>");
    }
}

struct MarkdownQuoteContainerHtmlRenderer
{
    alias Target = MarkdownQuoteContainer;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<blockquote>");
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</blockquote>");
    }

    static void beginChild(Renderer, Child)(Target target, Child child, ref Appender!(char[]) output, ref Renderer rnd)
    {
    }

    static void endChild(Renderer, Child)(Target target, Child child, ref Appender!(char[]) output, ref Renderer rnd)
    {
    }
}

struct MarkdownParagraphLeafHtmlRenderer
{
    alias Target = MarkdownParagraphLeaf;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<p>");
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</p>");
    }
}

struct MarkdownHeaderLeafHtmlRenderer
{
    alias Target = MarkdownHeaderLeaf;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<h");
        output.put(target.level.to!string);
        output.put(">");
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</h");
        output.put(target.level.to!string);
        output.put(">");
    }
}

struct MarkdownSetextHeaderLeafHtmlRenderer
{
    alias Target = MarkdownSetextHeaderLeaf;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<h");
        output.put(target.level.to!string);
        output.put(">");
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</h");
        output.put(target.level.to!string);
        output.put(">");
    }
}

struct MarkdownFencedCodeLeafHtmlRenderer
{
    alias Target = MarkdownFencedCodeLeaf;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<pre><code");
        if(target.language.length)
        {
            output.put(" class=\"language-");
            output.put(target.language);
            output.put("\"");
        }
        output.put('>');
        output.put(target.code); // Fenced code is special
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</code></pre>");
    }
}

struct MarkdownIndentedCodeLeafHtmlRenderer
{
    alias Target = MarkdownIndentedCodeLeaf;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<pre><code>");
        output.put(target.code); // Indented code is special
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("</code></pre>");
    }
}

struct MarkdownThematicBreakLeafHtmlRenderer
{
    alias Target = MarkdownThematicBreakLeaf;
    alias States = MarkdownNoState;

    static void begin(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<hr />");
    }

    static void end(Renderer)(Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
    }
}

struct MarkdownPlainTextInlineHtmlRenderer
{
    alias Target = MarkdownPlainTextInline;
    alias States = MarkdownNoState;

    static void render(Leaf, Parent, Renderer)(Leaf parentAsBlock, Parent parentAsValue, Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put(target.text);
    }
}

struct MarkdownCodeSpanInlineHtmlRenderer
{
    alias Target = MarkdownCodeSpanInline;
    alias States = MarkdownNoState;

    static void render(Leaf, Parent, Renderer)(Leaf parentAsBlock, Parent parentAsValue, Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<code>");
        output.put(target.code);
        output.put("</code>");
    }
}

struct MarkdownLinkInlineHtmlRenderer
{
    alias Target = MarkdownLinkInline;
    alias States = MarkdownNoState;

    static void render(Leaf, Parent, Renderer)(Leaf parentAsBlock, Parent parentAsValue, Target target, ref Appender!(char[]) output, ref Renderer rnd)
    {
        output.put("<a");
        if(target.url.length)
        {
            output.put(" href=\"");
            output.put(target.url);
            output.put('"');
        }
        
        if(target.title.length)
        {
            output.put(" title=\"");
            output.put(target.title);
            output.put('"');
        }
        output.put(">");
        output.put(target.label);
        output.put("</a>");
    }
}
