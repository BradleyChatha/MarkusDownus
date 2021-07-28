module markusdownus.htmlrenderer;

import std.array : Appender;
import std.exception : assumeUnique;
import std.traits : hasUDA;
import std.stdio : writeln;
import std.meta : Filter, AliasSeq;
import taggedalgebraic : visit;
import markusdownus;

alias MARKDOWN_DEFAULT_HTML_RENDERERS = AliasSeq!(
    ListItemHtmlRenderer,

    ParagraphHtmlRenderer,
    BlankLineHtmlRenderer,
    HeaderHtmlRenderer,
    FencedCodeHtmlRenderer,
    
    PlainTextHtmlRenderer,
    CodeHtmlRenderer,
    WeakEmphesisHtmlRenderer,
    StrongEmphesisHtmlRenderer,
    LinkHtmlRenderer,
);

struct MarkdownHtmlLeafBlockRenderer
{
}

struct MarkdownHtmlContainerBlockRenderer
{
}

struct MarkdownHtmlInlineRenderer
{
}

struct MarkdownHtmlRenderer(Renderers...)
{
    enum IsLeafBlockRenderer(T)      = hasUDA!(T, MarkdownHtmlLeafBlockRenderer);
    enum IsContainerBlockRenderer(T) = hasUDA!(T, MarkdownHtmlContainerBlockRenderer);
    enum IsInlineBlockRenderer(T)    = hasUDA!(T, MarkdownHtmlInlineRenderer);

    alias LeafRenderers      = Filter!(IsLeafBlockRenderer, Renderers);
    alias ContainerRenderers = Filter!(IsContainerBlockRenderer, Renderers);
    alias InlineRenderers    = Filter!(IsInlineBlockRenderer, Renderers);

    static:

    string render(ContextT)(ContextT context)
    {
        Appender!(char[]) output;
        foreach(block; context.root.children)
            renderBlock(output, block);
        return output.data.assumeUnique;
    }

    private void renderBlock(Block)(ref Appender!(char[]) output, Block block)
    {
        if(block.isContainer)
        {
            block.containerValue.value.visit!(
                (_)
                {
                    bool handled = false;
                    alias Type = typeof(_);
                    static foreach(renderer; ContainerRenderers)
                    {
                        static if(is(renderer.Target == Type))
                        {
                            renderer.init.begin(output, _);
                            foreach(child; block.containerValue.children)
                                renderBlock(output, child);
                            renderer.init.end(output, _);
                            handled = true;
                        }
                    }

                    if(!handled)
                        writeln("[WARN] Value has no renderer: ", _);
                }
            );
        }
        else
        {
            block.leafValue.value.visit!(
                (_)
                {
                    bool handled = false;
                    alias Type = typeof(_);
                    static foreach(renderer; LeafRenderers)
                    {
                        static if(is(renderer.Target == Type))
                        {
                            renderer.init.begin(output, _);
                            foreach(child; block.leafValue.inlines)
                                renderInline(output, child);
                            renderer.init.end(output, _);
                            handled = true;
                        }
                    }

                    if(!handled)
                        writeln("[WARN] Value has no renderer: ", _);
                }
            );
        }
    }

    private void renderInline(Inline)(ref Appender!(char[]) output, Inline inline)
    {
        inline.value.visit!(
            (_)
            {
                bool handled = false;
                alias Type = typeof(_);
                static foreach(renderer; InlineRenderers)
                {
                    static if(is(renderer.Target == Type))
                    {
                        renderer.init.render(output, _);
                        handled = true;
                    }
                }

                if(!handled)
                    writeln("[WARN] Value has no renderer: ", _);
            }
        );
    }
}

alias MarkdownDefaultHtmlRenderer = MarkdownHtmlRenderer!MARKDOWN_DEFAULT_HTML_RENDERERS;

@MarkdownHtmlContainerBlockRenderer
struct ListItemHtmlRenderer
{
    alias Target = ListItemContainerBlock;
    static int g_listDepth;

    void begin(ref Appender!(char[]) output, Target target)
    {
        if(g_listDepth == 0)
            output.put("<ul>");
        output.put("<li>");
        g_listDepth++;
    }

    void end(ref Appender!(char[]) output, Target target)
    {
        g_listDepth--;
        output.put("</li>");
        if(g_listDepth == 0)
            output.put("</ul>");
    }
}

@MarkdownHtmlLeafBlockRenderer
struct ParagraphHtmlRenderer
{
    alias Target = ParagraphLineLeafBlock;

    void begin(ref Appender!(char[]) output, Target target)
    {
        output.put("<p>");
    }

    void end(ref Appender!(char[]) output, Target target)
    {
        output.put("</p>");
    }
}

@MarkdownHtmlLeafBlockRenderer
struct BlankLineHtmlRenderer
{
    alias Target = BlankLineLeafBlock;

    void begin(ref Appender!(char[]) output, Target target)
    {
    }

    void end(ref Appender!(char[]) output, Target target)
    {
    }
}

@MarkdownHtmlLeafBlockRenderer
struct HeaderHtmlRenderer
{
    import std.conv : to;

    alias Target = HeaderLeafBlock;

    void begin(ref Appender!(char[]) output, Target target)
    {
        output.put("<h"); output.put(target.level.to!string); output.put(">");
    }

    void end(ref Appender!(char[]) output, Target target)
    {
        output.put("</h"); output.put(target.level.to!string); output.put(">");
    }
}

@MarkdownHtmlLeafBlockRenderer
struct FencedCodeHtmlRenderer
{
    alias Target = FencedCodeLeafBlock;

    void begin(ref Appender!(char[]) output, Target target)
    {
        output.put("<pre>");
        output.put("<code");
        if(target.lang.text.length > 0)
        {
            output.put(" class=\"language-");
            output.put(target.lang.text);
            output.put('"');
        }
        output.put('>');
        output.put(target.code.text); // Fenced code completely overrides Markdown styling, so it's a special case with no inlines.
    }

    void end(ref Appender!(char[]) output, Target target)
    {
        output.put("</code></pre>");
    }
} 

@MarkdownHtmlInlineRenderer
struct PlainTextHtmlRenderer
{
    alias Target = PlainTextInline;

    void render(ref Appender!(char[]) output, Target target)
    {
        output.put(target.range.text);
    }
}

@MarkdownHtmlInlineRenderer
struct CodeHtmlRenderer
{
    alias Target = CodeInline;

    void render(ref Appender!(char[]) output, Target target)
    {
        output.put("<code>");
        output.put(target.range.text);
        output.put("</code>");
    }
}

@MarkdownHtmlInlineRenderer
struct WeakEmphesisHtmlRenderer
{
    alias Target = WeakEmphesisInline;

    void render(ref Appender!(char[]) output, Target target)
    {
        output.put("<em>");
        output.put(target.range.text);
        output.put("</em>");
    }
}

@MarkdownHtmlInlineRenderer
struct StrongEmphesisHtmlRenderer
{
    alias Target = StrongEmphesisInline;

    void render(ref Appender!(char[]) output, Target target)
    {
        output.put("<strong>");
        output.put(target.range.text);
        output.put("</strong>");
    }
}

@MarkdownHtmlInlineRenderer
struct LinkHtmlRenderer
{
    alias Target = LinkInline;

    void render(ref Appender!(char[]) output, Target target)
    {
        output.put("<a href=\"");
        output.put(target.url.text);
        output.put("\">");
        output.put(target.text.text);
        output.put("</a>");
    }
}

@("HTML - 219")
unittest
{
    auto syntax = MarkdownDefault.doFullSyntax("aaa\n\nbbb");
    auto html = MarkdownDefaultHtmlRenderer.render(syntax);
    assert(html == "<p>aaa</p><p>bbb</p>", html);
}

@("HTML - 220")
unittest
{
    auto syntax = MarkdownDefault.doFullSyntax("aaa\nbbb\n\nccc\nddd");
    auto html = MarkdownDefaultHtmlRenderer.render(syntax);
    assert(html == "<p>aaa\nbbb</p><p>ccc\nddd</p>", html);
}

@("HTML - Bigboy")
unittest
{
    import std.file : write;
    const daddy = import("bigboytest.md");
    write(
        "test.html",
        MarkdownDefaultHtmlRenderer.render(
            MarkdownDefault.doFullSyntax(daddy)
        )
    );
}