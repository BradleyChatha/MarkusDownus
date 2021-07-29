module markusdownus.inlinepass;

import std;
import markusdownus;

enum MarkdownInlinePassResult
{
    FAILSAFE,
    didNothing,
    foundInline
}

void inlinePass(AstT)(ref AstT.Context ctx)
{
    handleContainer(ctx.root);
}

private void handleLeaf(AstT)(ref AstT.Leaf leaf)
{
    visitAll!(
        (ref block)
        {
            enum udas = getUDAs!(typeof(block), MarkdownHasInlines);
            static foreach(uda; udas)
            {{
                const text = mixin("block."~uda.whichSymbol);
                static if(is(typeof(text) : const(string[])))
                {
                    foreach(i, line; text)
                    {
                        handleInlines!AstT(leaf, line);
                        if(i + 1 != text.length)
                            leaf.push(MarkdownPlainTextInline("\n"));
                    }
                }
                else
                    handleInlines!AstT(leaf, text);
            }}
        }
    )(leaf);
}

private void handleContainer(AstT)(ref AstT.Container container)
{
    foreach(ref child; container.children)
    {
        if(child.isLeaf)
            handleLeaf(child.getLeaf);
        else
            handleContainer(child.getContainer);
    }
}

private void handleInlines(AstT)(ref AstT.Leaf leaf, string text)
{
    auto chars = CharReader(text);

    size_t plainStart = 0;
    while(!chars.eof)
    {
        bool wasEscaped;
        const trigger = chars.peekEscaped(wasEscaped);

        if(wasEscaped)
        {
            chars.advance(1);
            continue;
        }

        enum UniqueTriggers = GatherUniqueTriggerChars!(AstT.InlineParsers, MarkdownInlineParser);
        Switch: switch(trigger)
        {
            static foreach(trig; UniqueTriggers)
            {{
                alias Parsers = GetParsersForTrigger!(trig, AstT.InlineParsers, MarkdownInlineParser);
                case trig:
                    const start = chars.cursor;
                    if(chars.slice(plainStart, chars.cursor).length)
                        leaf.push(MarkdownPlainTextInline(chars.slice(plainStart, chars.cursor)));
                    plainStart = chars.cursor;
                    static foreach(parser; Parsers)
                    {{
                        const result = parser.tryParse(chars, leaf);
                        if(result == MarkdownInlinePassResult.didNothing)
                            chars.cursor = start;
                        else
                        {
                            plainStart = chars.cursor;
                            break Switch;
                        }
                    }}
                    chars.advance(1);
                    break Switch;
            }}

            default:
                chars.advance(1);
                break;
        }
    }

    if(plainStart < text.length && chars.slice(plainStart, text.length).length)
        leaf.push(MarkdownPlainTextInline(chars.slice(plainStart, text.length)));
}

@("<in0> inline - code spans")
unittest
{
    // 328
    auto ctx = blockPass!MarkdownAstDefault("`abc`");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownCodeSpanInline);

    // 329
    ctx = blockPass!MarkdownAstDefault("`` foo ` bar ``");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownCodeSpanInline);

    // 330
    ctx = blockPass!MarkdownAstDefault("`` `` `");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownCodeSpanInline);
}

@("<in1> inline - links")
unittest
{
    // 481
    auto ctx = blockPass!MarkdownAstDefault("[link](/uri \"title\")");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline);

    // 482
    ctx = blockPass!MarkdownAstDefault("[link](/uri)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline);

    // 483
    ctx = blockPass!MarkdownAstDefault("[](./target.md)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline);

    // 484
    ctx = blockPass!MarkdownAstDefault("[link]()");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline);

    // 485
    ctx = blockPass!MarkdownAstDefault("[link](<my>)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline, ctx.root.formatAst());

    // 486
    ctx = blockPass!MarkdownAstDefault("[]()");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline, ctx.root.formatAst());

    // 487
    ctx = blockPass!MarkdownAstDefault("[link](/my uri)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownPlainTextInline, ctx.root.formatAst());

    // 488
    ctx = blockPass!MarkdownAstDefault("[link](</my uri>)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline, ctx.root.formatAst());

    // 489
    ctx = blockPass!MarkdownAstDefault("[link](foo\nbar)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownPlainTextInline, ctx.root.formatAst());

    // 490
    ctx = blockPass!MarkdownAstDefault("[link](<foo\nbar>)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownPlainTextInline, ctx.root.formatAst());

    // 491
    ctx = blockPass!MarkdownAstDefault("[a](<b)c>)");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline, ctx.root.formatAst());

    // 571
    ctx = blockPass!MarkdownAstDefault("![foo](/url \"title\")");
    inlinePass!MarkdownAstDefault(ctx);
    assert(ctx.root.children[0].getLeaf.inlines[0].isMarkdownLinkInline, ctx.root.formatAst());
}