module markusdownus.blockpass;

import std;
import markusdownus;

enum MarkdownBlockPassResult
{
    FAILSAFE,
    didNothing,
    openContainer,
    continueContainer,
    closeContainer,
    foundLeaf
}

AstT.Context blockPass(AstT)(string input)
{
    auto ctx = AstT.Context(true);
    ctx.chars = CharReader(input);
    blockPass!AstT(ctx);
    return ctx;
}

void blockPass(AstT)(ref AstT.Context ctx)
{
    while(!ctx.chars.eof)
    {
        ctx.lineWhite = ctx.chars.eatInlineWhite();
        if(ctx.chars.eof)
            break;

        bool wasHandled = false;
        auto trigger = ctx.chars.peek();
        auto start = ctx.chars.cursor;

        if(trigger == '\n' && !ctx.chars.atStartOfLine)
        {
            ctx.chars.advance(1);
            continue;
        }

        size_t _1;
        if(ctx.chars.atStartOfLine && ctx.chars.isRestOfLineEmpty(_1))
            ctx.pushParagraphIfNeeded();

        // Step #1: Containers

        if(ctx.containerStack.length > 1) // See if the current container can/should close.
        {
            scope currentContainer = &ctx.containerStack[$-1];
            const currentContainerResult = currentContainer.tryToClose(
                ctx, 
                *currentContainer, 
                false//ctx.lineWhite.spaces < currentContainer.minIndent
            );

            if(currentContainerResult == MarkdownBlockPassResult.didNothing)
                ctx.chars.cursor = start;
            else
            {
                ctx.chars.eatInlineWhite();
                if(ctx.chars.eof)
                    break;
                trigger = ctx.chars.peek();
                start = ctx.chars.cursor;
            }
        }

        static const ContainerTriggers = GatherUniqueTriggerChars!(AstT.ContainerParsers, MarkdownContainerParser);
        ContainerSwitch: switch(trigger)
        {
            static foreach(ch; AliasSeq!ContainerTriggers)
            {
                case ch:
                    static foreach(parser; GetParsersForTrigger!(ch, AstT.ContainerParsers, MarkdownContainerParser))
                    {{
                        const result = parser.tryOpen!AstT(ctx);
                        if(result == MarkdownBlockPassResult.didNothing)
                            ctx.chars.cursor = start;
                        else
                        {
                            wasHandled = true;
                            break ContainerSwitch;
                        }
                    }}
                    break ContainerSwitch;
            }

            default:
                break;
        }

        if(wasHandled)
            continue;

        // Step #2: Whitespace sensisitve leaves
        if(ctx.lineWhite.spaces)
        {
            static foreach(parser; GetParsersForTrigger!(' ', AstT.LeafParsers, MarkdownLeafParser))
            {{
                const result = parser.tryParse!AstT(ctx);
                if(result == MarkdownBlockPassResult.didNothing)
                    ctx.chars.cursor = start;
                else
                {
                    wasHandled = true;
                    goto EndOfSpaces; // yuck, but needed.
                }
            }}
        }
        EndOfSpaces:

        if(wasHandled)
            continue;

        // Step #3: Every other leaf except paragraphs.
        static const OtherLeafTriggers = GatherUniqueTriggerChars!(AstT.LeafParsers, MarkdownLeafParser);
        OtherLeafSwitch: switch(trigger)
        {
            static foreach(ch; OtherLeafTriggers)
            {
                case ch:
                    static foreach(parser; GetParsersForTrigger!(ch, AstT.LeafParsers, MarkdownLeafParser))
                    {{
                        const result = parser.tryParse!AstT(ctx);
                        if(result == MarkdownBlockPassResult.didNothing)
                            ctx.chars.cursor = start;
                        else
                        {
                            wasHandled = true;
                            break OtherLeafSwitch;
                        }
                    }}
                    break OtherLeafSwitch;
            }

            default: break;
        }

        if(wasHandled)
            continue;

        // Step #4: Fuck it, it's a paragraph.
        size_t endOfParagraph;
        ctx.chars.eatLine(endOfParagraph);
        if(!ctx.chars.slice(start, endOfParagraph).all!(ch => ch == ' ' || ch == '\n'))
            ctx.appendToParagraph(ctx.chars.slice(start, endOfParagraph));
    }

    ctx.finaliseBlockPass();
}

@("<bp0> blockpass - block quote coalesce [single]")
unittest
{
    foreach(str; [
        /*228*/ "> # Foo\n> bar\n> baz",
        /*229*/ "># Foo\n>bar\n> baz",
        /*230*/ "   > # Foo\n   > bar\n > baz",
        /*232*/ "> # Foo\n> bar\nbaz",
        /*233*/ "> bar\nbaz\n> foo",
        /*239*/ ">",
        /*240*/ ">\n>  \n> ",
        /*241*/ ">\n> foo\n>  ",
        /*243*/ "> foo\n> bar",
        /*244*/ "> foo\n>\n> bar",
        /*247*/ "> bar\nbaz",
    ])
    {
        auto ctx = blockPass!MarkdownAstDefault(str);
        assert(ctx.root.children.length == 1, formatAst(ctx.root));
        assert(ctx.root.children[0].getContainer.isMarkdownQuoteContainer, formatAst(ctx.root));
    }
}

@("<bp1> blockpass - unordered list coalecse [single]")
unittest
{
    foreach(str; [
        /*301*/ "- foo\n- bar",
    ])
    {
        auto ctx = blockPass!MarkdownAstDefault(str);
        assert(ctx.root.children.length == 1, formatAst(ctx.root));
        assert(ctx.root.children[0].getContainer.isMarkdownUnorderedListContainer, formatAst(ctx.root));
        assert(ctx.root.children[0].getContainer.children.length == 1, formatAst(ctx.root));
    }
}

@("<bp2> blockpass - thematic breaks")
unittest
{
    // 43
    auto ctx = blockPass!MarkdownAstDefault("***\n---\n___");
    assert(ctx.root.children.length == 3, formatAst(ctx.root));
    assert(ctx.root.children.all!(c => c.getLeaf.isMarkdownThematicBreakLeaf));

    // 44
    ctx = blockPass!MarkdownAstDefault("+++");
    assert(ctx.root.children[0].getLeaf.isMarkdownParagraphLeaf);
    
    // 45
    ctx = blockPass!MarkdownAstDefault("===");
    assert(ctx.root.children[0].getLeaf.isMarkdownParagraphLeaf);

    // 46
    ctx = blockPass!MarkdownAstDefault("--\n**\n__");
    assert(ctx.root.children[0].getLeaf.isMarkdownParagraphLeaf);
    
    // 47
    ctx = blockPass!MarkdownAstDefault(" ***\n  ***\n   ***");
    assert(ctx.root.children.length == 3, formatAst(ctx.root));
    assert(ctx.root.children.all!(c => c.getLeaf.isMarkdownThematicBreakLeaf));
    
    // 48
    ctx = blockPass!MarkdownAstDefault("    ***");
    assert(ctx.root.children[0].getLeaf.isMarkdownIndentedCodeLeaf);
    
    // 49
    ctx = blockPass!MarkdownAstDefault("Foo\n    ***");
    assert(ctx.root.children[0].getLeaf.isMarkdownParagraphLeaf);
    
    // 50
    ctx = blockPass!MarkdownAstDefault("_______________________________");
    assert(ctx.root.children[0].getLeaf.isMarkdownThematicBreakLeaf);
    
    // 54(modified)
    ctx = blockPass!MarkdownAstDefault("---     ");
    assert(ctx.root.children[0].getLeaf.isMarkdownThematicBreakLeaf);
    
    // 55
    ctx = blockPass!MarkdownAstDefault("____a\na-----\n---a---");
    assert(ctx.root.children.all!(c => c.getLeaf.isMarkdownParagraphLeaf));

    // 57
    ctx = blockPass!MarkdownAstDefault("- foo\n***\n- bar");
    assert(ctx.root.children.length == 3, formatAst(ctx.root));
    assert(ctx.root.children[0].getContainer.isMarkdownUnorderedListContainer);
    assert(ctx.root.children[1].getLeaf.isMarkdownThematicBreakLeaf);
    assert(ctx.root.children[2].getContainer.isMarkdownUnorderedListContainer);

    // 58
    ctx = blockPass!MarkdownAstDefault("foo\n***\nbar");
    assert(ctx.root.children.length == 3, formatAst(ctx.root));
    assert(ctx.root.children[0].getLeaf.isMarkdownParagraphLeaf);
    assert(ctx.root.children[1].getLeaf.isMarkdownThematicBreakLeaf);
    assert(ctx.root.children[2].getLeaf.isMarkdownParagraphLeaf);
}

@("<bp3> blockpass - indented code block")
unittest
{
    // 107
    auto ctx = blockPass!MarkdownAstDefault("    a simple\n      indented code block");
    assert(ctx.root.children.length == 1);
    assert(ctx.root.children[0].getLeaf.isMarkdownIndentedCodeLeaf);

    // 110
    ctx = blockPass!MarkdownAstDefault("    <a/>\n    *hi*\n\n    - one");
    assert(ctx.root.children.length == 1);
    assert(ctx.root.children[0].getLeaf.isMarkdownIndentedCodeLeaf);

    // 111
    ctx = blockPass!MarkdownAstDefault("    chunk1\n\n    chunk2\n  \n \n \n    chunk3");
    assert(ctx.root.children.length == 1);
    assert(ctx.root.children[0].getLeaf.isMarkdownIndentedCodeLeaf);
}

@("<bp4> blockpass - ATX Headers")
unittest
{
    // 62
    auto ctx = blockPass!MarkdownAstDefault("# foo\n## foo\n### foo\n#### foo\n##### foo\n###### foo");
    assert(ctx.root.children.length == 6);
    assert(ctx.root.children.all!(c => c.getLeaf.isMarkdownHeaderLeaf));

    // 63
    ctx = blockPass!MarkdownAstDefault("####### foo");
    assert(ctx.root.children[0].getLeaf.isMarkdownParagraphLeaf);

    // 64
    ctx = blockPass!MarkdownAstDefault("#5 bolt\n\n#hashtag");
    assert(ctx.root.children.length == 2);
    assert(ctx.root.children[0].getLeaf.isMarkdownParagraphLeaf);
    assert(ctx.root.children[1].getLeaf.isMarkdownParagraphLeaf);

    // 68
    ctx = blockPass!MarkdownAstDefault(" ### foo\n  ## foo\n   # foo");
    assert(ctx.root.children.length == 3);
    assert(ctx.root.children[0].getLeaf.isMarkdownHeaderLeaf);
    assert(ctx.root.children[1].getLeaf.isMarkdownHeaderLeaf);
    assert(ctx.root.children[2].getLeaf.isMarkdownHeaderLeaf);

    // 69999999999
    ctx = blockPass!MarkdownAstDefault("    # foo");
    assert(ctx.root.children[0].getLeaf.isMarkdownIndentedCodeLeaf);
}

@("<bp5> blockpass - Setext Headers")
unittest
{
    // 80
    auto ctx = blockPass!MarkdownAstDefault("Foo *bar*\n=======");
    assert(ctx.root.children.length == 1);
    assert(ctx.root.children[0].getLeaf.isMarkdownSetextHeaderLeaf);
    
    // 81
    ctx = blockPass!MarkdownAstDefault("Foo *bar\nbaz*\n=======");
    assert(ctx.root.children.length == 1);
    assert(ctx.root.children[0].getLeaf.isMarkdownSetextHeaderLeaf);

    // 83
    ctx = blockPass!MarkdownAstDefault("Foo\n------------------\n\nFoo\n=");
    assert(ctx.root.children.length == 2);
    assert(ctx.root.children[0].getLeaf.isMarkdownSetextHeaderLeaf);
    assert(ctx.root.children[1].getLeaf.isMarkdownSetextHeaderLeaf);

    // 84
    ctx = blockPass!MarkdownAstDefault("   Foo\n---\n\n  Foo\n------\n\n  Foo\n===");
    assert(ctx.root.children.length == 3, formatAst(ctx.root));
    assert(ctx.root.children[0].getLeaf.isMarkdownSetextHeaderLeaf);
    assert(ctx.root.children[1].getLeaf.isMarkdownSetextHeaderLeaf);
    assert(ctx.root.children[2].getLeaf.isMarkdownSetextHeaderLeaf);
}

@("<bp6> blockpass - link reference definitions")
unittest
{
    // 192 modified
    auto ctx = blockPass!MarkdownAstDefault("[foo]: /url \"title\"");
    assert(ctx.root.children.length == 1);
    assert(ctx.root.children[0].getLeaf.isMarkdownLinkReferenceDefinitionLeaf, formatAst(ctx.root));
}