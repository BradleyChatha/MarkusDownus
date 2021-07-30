module markusdownus.renderer;

import std;
import markusdownus;

struct MarkdownNoState{}

alias MARKDOWN_DEFAULT_CONTAINER_HTML_RENDERERS = AliasSeq!(
    MarkdownRootContainerHtmlRenderer,
    MarkdownUnorderedListContainerHtmlRenderer,
    MarkdownQuoteContainerHtmlRenderer,
);

alias MARKDOWN_DEFAULT_LEAF_HTML_RENDERERS = AliasSeq!(
    MarkdownParagraphLeafHtmlRenderer,
    MarkdownHeaderLeafHtmlRenderer,
    MarkdownFencedCodeLeafHtmlRenderer,
    MarkdownIndentedCodeLeafHtmlRenderer,
    MarkdownSetextHeaderLeafHtmlRenderer,
    MarkdownThematicBreakLeafHtmlRenderer
);

alias MARKDOWN_DEFAULT_INLINE_HTML_RENDERERS = AliasSeq!(
    MarkdownPlainTextInlineHtmlRenderer,
    MarkdownCodeSpanInlineHtmlRenderer,
    MarkdownLinkInlineHtmlRenderer,
    MarkdownEmphesisInlineHtmlRenderer
);

alias MarkdownRendererHtmlDefault = MarkdownRenderer!(
    MarkdownAstDefault,
    MarkdownAstGroup!MARKDOWN_DEFAULT_CONTAINER_HTML_RENDERERS,
    MarkdownAstGroup!MARKDOWN_DEFAULT_LEAF_HTML_RENDERERS,
    MarkdownAstGroup!MARKDOWN_DEFAULT_INLINE_HTML_RENDERERS,
);

struct MarkdownContainerBlockRenderer
{
}

struct MarkdownLeafBlockRenderer
{
}

struct MarkdownInlineRenderer
{
}

struct MarkdownRenderer(
    AstT,
    containerBlockRenderers,
    leafBlockRenderers,
    inlineRenderers
)
if(
    isInstanceOf!(MarkdownAstGroup, containerBlockRenderers)
 && isInstanceOf!(MarkdownAstGroup, leafBlockRenderers)
 && isInstanceOf!(MarkdownAstGroup, inlineRenderers)
)
{
    alias ContainerRenderers  = containerBlockRenderers;
    alias LeafRenderers       = leafBlockRenderers;
    alias InlineRenderers     = inlineRenderers;
    alias States              = GatherTargets!(MarkdownAstGroup!(AliasSeq!(ContainerRenderers.Things, LeafRenderers.Things, InlineRenderers.Things)), "States");

    static struct State
    {
        mixin MarkdownAstNode!(NodeType.other, States);
    }

    private State[States.length] _states;

    this(bool _)
    {
        static foreach(i, state; States)
            this._states[i] = state.init;
    }

    ref T getState(T)()
    {
        static foreach(i, state; States)
        {
            static if(is(state == T))
            {
                return this._states[i].valueForTarget!T;
            }
        }
    }
}

string render(alias AstT = MarkdownAstDefault, alias RendererT = MarkdownRendererHtmlDefault)(string markdown)
{
    AstT.Context ctx;
    RendererT rnd;
    return render!(AstT, RendererT)(markdown, ctx, rnd);
}

string render(alias AstT = MarkdownAstDefault, alias RendererT = MarkdownRendererHtmlDefault)(string markdown, out AstT.Context ctx, out RendererT rnd)
{
    ctx = blockPass!AstT(markdown);
    inlinePass!AstT(ctx);
    rnd = RendererT(true);
    auto result = render(ctx.root, rnd);
    return result;
}

string render(AstT, RendererT)(AstT.Container root, ref RendererT rnd)
{
    Appender!(char[]) output;
    renderContainer(root, output, rnd);
    return output.data.assumeUnique;
}

private void renderContainer(AstT, RendererT)(ref AstT.Container container, ref Appender!(char[]) output, ref RendererT rnd)
{
    visitAll!((block)
    {
        static foreach(renderer; RendererT.ContainerRenderers.Things)
        {
            static if(is(renderer.Target == typeof(block)))
            {
                renderer.begin(block, output, rnd);
                foreach(ref child; container.children)
                {
                    renderer.beginChild(block, child, output, rnd);
                    if(child.isLeaf)
                        renderLeaf!(AstT, RendererT)(child.getLeaf(), output, rnd);
                    else
                        renderContainer!(AstT, RendererT)(child.getContainer(), output, rnd);
                    renderer.endChild(block, child, output, rnd);
                }
                renderer.end(block, output, rnd);
                return;
            }
        }
    })(container);
}

private void renderLeaf(AstT, RendererT)(ref AstT.Leaf leaf, ref Appender!(char[]) output, ref RendererT rnd)
{
    visitAll!((block)
    {
        static foreach(renderer; RendererT.LeafRenderers.Things)
        {
            static if(is(renderer.Target == typeof(block)))
            {
                renderer.begin(block, output, rnd);
                foreach(i, ref inline; leaf.inlines)
                    renderInline!(typeof(block), AstT, RendererT)(leaf, block, inline, output, rnd, i);
                renderer.end(block, output, rnd);
                return;
            }
        }
    })(leaf);
}

private void renderInline(ParentT, AstT, RendererT)(
    ref AstT.Leaf parentAsBlock,
    ref ParentT parentAsValue, 
    ref AstT.Inline inline, 
    ref Appender!(char[]) output, 
    ref RendererT rnd,
    size_t index,
)
{
    visitAll!((inlineValue)
    {
        static foreach(renderer; RendererT.InlineRenderers.Things)
        {
            static if(is(renderer.Target == typeof(inlineValue)))
            {
                renderer.render(parentAsBlock, parentAsValue, inlineValue, output, rnd, index);
                return;
            }
        }
    })(inline);
}

unittest
{
    const b = import("bigboytest.md");
    std.file.write("test.html", render(b));
}