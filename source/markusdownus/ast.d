module markusdownus.ast;

import std;
import markusdownus;

alias MARKDOWN_DEFAULT_CONTAINER_PARSERS = AliasSeq!(
    MarkdownQuoteContainerParser,
    MarkdownUnorderedListContainerParser
);

alias MARKDOWN_DEFAULT_LEAF_PARSERS = AliasSeq!(
    MarkdownThematicBreakLeafParser,
    MarkdownIndentedCodeLeafParser,
    MarkdownHeaderLeafParser,
    MarkdownSetextHeaderLeafParser,
    MarkdownFencedCodeLeafParser,
    MarkdownLinkReferenceDefinitionLeafParser
);

alias MARKDOWN_DEFAULT_INLINE_PARSERS = AliasSeq!(
    MarkdownCodeSpanInlineParser,
    MarkdownLinkInlineParser,
    MarkdownEmphesisInlineParser
);

alias MarkdownAstDefault = MarkdownAst!(
    MarkdownAstGroup!MARKDOWN_DEFAULT_CONTAINER_PARSERS,
    MarkdownAstGroup!MARKDOWN_DEFAULT_LEAF_PARSERS,
    MarkdownAstGroup!MARKDOWN_DEFAULT_INLINE_PARSERS,
);

struct MarkdownContainerParser
{
    char triggerChar;
    uint priority;
    bool canStopParagraphs;
}

struct MarkdownLeafParser
{
    char triggerChar;
    uint priority;
    bool canStopParagraphs;
}

struct MarkdownInlineParser
{
    char triggerChar;
}

struct MarkdownHasInlines
{
    string whichSymbol;
}

struct MarkdownAstGroup(Things_...)
{
    alias Things = Things_;
}

package enum NodeType
{
    container,
    leaf,
    inline,
    leafOrContainer,
    other
}

package mixin template MarkdownAstNode(NodeType type, Targets_...)
{
    static if(type == NodeType.leaf)
        alias Targets = AliasSeq!(Targets_, MarkdownParagraphLeaf);
    else static if(type == NodeType.inline)
        alias Targets = AliasSeq!(Targets_, MarkdownPlainTextInline);
    else static if(type == NodeType.container)
        alias Targets = AliasSeq!(Targets_, MarkdownRootContainer);
    else
        alias Targets = Targets_;
    static const Names = TargetNames!Targets;

    static struct Kind
    {
        int value;

        @safe @nogc nothrow pure static:

        Kind UNIT() { return Kind(AliasSeq!Targets.length); }
        static foreach(i, target; AliasSeq!(Targets))
            mixin("Kind "~Names[i]~"() { return Kind("~i.to!string~"); }");
    }

    union Values
    {
        static foreach(i, target; AliasSeq!(Targets))
            mixin(__traits(identifier, target)~" "~Names[i]~";");
    }

    private Kind kind;
    private Values value;

    this(T)(T value)
    {
        this = value;
    }

    string toString()
    {
        Appender!(char[]) data;

        Switch: final switch(this.kind.value)
        {
            static foreach(i, target; AliasSeq!Targets)
            {
                case kindForTarget!target.value:
                    data.put(__traits(identifier, target));
                    break Switch;
            }

            case Kind.UNIT.value:
                data.put("unit");
                break;
        }

        return data.data.assumeUnique;
    }

    static foreach(i, target; AliasSeq!Targets)
    {
        void opAssign(target value)
        {
            this.valueForTarget!(target, false) = value;
            this.kind = kindForTarget!target;
        }

        mixin(q{
            ref target get%s()
            {
                return this.valueForTarget!target;
            }
        }.format(__traits(identifier, target)));

        mixin(q{
            bool is%s()
            {
                return this.kind == this.kindForTarget!target;
            }
        }.format(__traits(identifier, target)));
    }

    static Kind kindForTarget(T)()
    {
        static foreach(i, target; AliasSeq!Targets)
        {
            static if(is(target == T))
                return mixin("Kind."~Names[i]);
        }
    }

    ref auto valueForTarget(T, bool doAssert = true)()
    {
        static if(doAssert)
        assert(
            this.kind == kindForTarget!T, 
            "I'm a `"~Names[this.kind.value]~"` not a `"~Names[kindForTarget!T.value]~"`"
        );
        static foreach(i, target; AliasSeq!Targets)
        {
            static if(is(target == T))
                return mixin("this.value."~Names[i]);
        }
    }
}

template visitAll(alias Handler)
{
    void visitAll(AstT)(ref AstT ast)
    {
        final switch(ast.kind.value)
        {
            case ast.Kind.UNIT.value: return;

            static foreach(i, target; ast.Targets)
            {
                case mixin("ast.Kind."~ast.Names[i]~".value"):
                    Handler(ast.valueForTarget!target);
                    return;
            }
        }
    }
}

struct MarkdownAst(
    containerBlockParsers,
    leafBlockParsers,
    inlineParsers
)
if(
    isInstanceOf!(MarkdownAstGroup, containerBlockParsers)
 && isInstanceOf!(MarkdownAstGroup, leafBlockParsers)
 && isInstanceOf!(MarkdownAstGroup, inlineParsers)
)
{
    alias ContainerParsers  = containerBlockParsers;
    alias LeafParsers       = leafBlockParsers;
    alias InlineParsers     = inlineParsers;
    alias Context           = MarkdownParseContext!(typeof(this));
    alias TryToCloseFunc    = MarkdownBlockPassResult function(ref Context, ref Container, bool);

    static struct LeafOrContainer
    {
        alias Types = AliasSeq!(Container, Leaf);
        mixin MarkdownAstNode!(NodeType.leafOrContainer, Types);
    }

    static struct Container
    {
        mixin MarkdownAstNode!(NodeType.container, GatherTargets!ContainerParsers);
        TryToCloseFunc tryToClose;
        uint minIndent;
        uint priority;
        LeafOrContainer[] children;
    }

    static struct Leaf
    {
        mixin MarkdownAstNode!(NodeType.leaf, GatherTargets!LeafParsers);
        uint priority;
        Inline[] inlines;

        void push(InlineT)(InlineT inline)
        {
            this.inlines ~= Inline(inline);
        }
    }

    static struct Inline
    {
        mixin MarkdownAstNode!(NodeType.inline, GatherTargets!InlineParsers);
    }
}

template GatherTargets(Group, string TargetsName = "Targets")
{
    mixin("alias ToTargets(T) = T."~TargetsName~";");
    alias Targets       = staticMap!(ToTargets, Group.Things);
    alias GatherTargets = NoDuplicates!Targets;
}

template GatherUniqueTriggerChars(Group, Uda)
{
    enum ToTriggerChar(alias UDA)   = UDA.triggerChar;
    enum ToTriggerChars(T)          = staticMap!(ToTriggerChar, getUDAs!(T, Uda));
    alias TriggerChars              = staticMap!(ToTriggerChars, Group.Things);
    alias GatherUniqueTriggerChars  = NoDuplicates!TriggerChars;
}

template TargetNames(Targets...)
{
    string[] names()
    {
        string[] names;
        static foreach(target; Targets)
            names ~= __traits(identifier, target)[0..1].toLower ~ __traits(identifier, target)[1..$];
        return names;
    }
    const TargetNames = names();
}

template GetParsersForTrigger(char trigger, Parsers, Uda)
{
    enum HasTriggerUda(alias UDA)   = UDA.triggerChar == trigger;
    enum HasTrigger(T)              = Filter!(HasTriggerUda, getUDAs!(T, Uda)).length > 0;
    enum SortByPriority(A,B)        = getUDAs!(A, Uda)[0].priority < getUDAs!(B, Uda)[0].priority;
    alias SuitableParsers           = Filter!(HasTrigger, Parsers.Things);
    alias GetParsersForTrigger      = staticSort!(SortByPriority, SuitableParsers);
}

string formatAst(AstT)(AstT.Container root)
{
    Appender!(char[]) data;
    formatAstImpl(data, root, 0);
    return data.data.assumeUnique;
}

private void formatAstImpl(AstT)(ref Appender!(char[]) data, AstT.Container container, uint indent)
{
    data.put(' '.repeat.take(indent * 4));
    data.put(container.toString());
    if(container.children.length)
        data.put('\n');
    foreach(child; container.children)
    {
        if(child.isContainer)
            formatAstImpl(data, child.getContainer, indent+1);
        else
            formatAstImpl(data, child.getLeaf, indent+1);
    }
}

private void formatAstImpl(AstT)(ref Appender!(char[]) data, AstT.Leaf leaf, uint indent)
{
    data.put(' '.repeat.take(indent * 4));
    data.put(leaf.toString());
    if(leaf.inlines.length)
        data.put('\n');
    foreach(inline; leaf.inlines)
        formatAstImpl(data, inline, indent+1);
    data.put('\n');
}

private void formatAstImpl(AstT)(ref Appender!(char[]) data, AstT.Inline inline, uint indent)
{
    data.put(' '.repeat.take(indent * 4));
    data.put(inline.toString());
    data.put('\n');
}